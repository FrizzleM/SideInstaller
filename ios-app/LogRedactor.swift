import Foundation

/// Takes out of each console line what nobody debugging needs and a shared log
/// shouldn't carry: keys and credentials, and what identifies the person or the
/// device (Apple ID, device name, serials, IMEI/ICCID/IMSI, MAC addresses, the
/// chip ID). What a bug report needs stays: model, iOS version and build,
/// states, tunnel addresses, services, errors, the team ID, and the shape of
/// what was taken — a key's length, a UDID's chip prefix and last four.
///
/// Every line passes through `redact` before it's shown, copied or mirrored
/// to stdout. The rules match how the plists, XPC messages and pairing
/// structures are printed (idevice's pretty printer and Rust's `{:#?}`), plus
/// Swift's `  Key = value` lines.
enum LogRedactor {

    // MARK: Public

    static func redact(_ line: String) -> String {
        var text = line
        for rule in rules { text = rule(text) }
        return text
    }

    /// An Apple ID as the log shows it: `a***z@example.com`, or a phone
    /// number's last two digits.
    static func maskAppleID(_ id: String) -> String {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = id.lastIndex(of: "@") else {
            let digits = id.filter(\.isNumber)
            return digits.count > 2 ? "•••\(digits.suffix(2))" : "•••"
        }
        let local = id[..<at], domain = id[at...]
        guard let first = local.first, let last = local.last else { return "***\(domain)" }
        return local.count <= 2 ? "\(first)***\(domain)" : "\(first)***\(last)\(domain)"
    }

    /// A UDID as the log shows it. The chip prefix of a current one
    /// (`00008120-`) is kept, since it names the SoC; the last four let two
    /// logs be matched to the same device.
    static func maskUDID(_ udid: String) -> String {
        let parts = udid.split(separator: "-", maxSplits: 1)
        if parts.count == 2, parts[0].count == 8 {
            return "\(parts[0])-…\(parts[1].suffix(4))"
        }
        return udid.count > 4 ? "…\(udid.suffix(4))" : "…"
    }

    // MARK: What's taken

    /// Values of these keys are taken out whole. Matched without regard to case,
    /// and only as whole keys (`SerialNumber` doesn't match `MLBSerialNumber`,
    /// which is listed on its own).
    private static let secretKeys = [
        // Serials and hardware identifiers.
        "SerialNumber", "MLBSerialNumber", "BasebandSerialNumber", "WirelessBoardSerialNumber",
        "ChipSerialNo", "remotepairing_serial_number", "UniqueChipID", "DieID", "ECID",
        "BasebandMasterKeyHash", "PkHash", "SKeyHash",
        // Cellular: equipment, subscriber and SIM identities, and the number.
        "InternationalMobileEquipmentIdentity", "InternationalMobileEquipmentIdentity2",
        "MobileEquipmentIdentifier", "InternationalMobileSubscriberIdentity",
        "InternationalMobileSubscriberIdentity2", "IntegratedCircuitCardIdentity",
        "IntegratedCircuitCardIdentity2", "PhoneNumber",
        // Network hardware addresses.
        "BluetoothAddress", "WiFiAddress", "WiFiMACAddress", "EthernetAddress", "EthernetMacAddress",
        // Find My: the masked account and its keys.
        "fm-account-masked", "fm-spkeys",
        // Pairing secrets: RPPairing's Ed25519 key and IRKs, lockdown's pair record.
        "private_key", "alt_irk", "altIRK", "HostPrivateKey", "RootPrivateKey", "EscrowBag",
        // Apple account session and anisette machine state.
        "adsid", "dsid", "GsIdmsToken", "token", "password", "certificatePassword",
        "anisetteAdiBlob", "anisetteIdentifier", "adi_pb", "cpim", "spim", "ptm", "tk",
        "X-Apple-I-MD", "X-Apple-I-MD-M", "X-Apple-I-MD-RINFO", "X-Mme-Device-Id",
    ]

    /// Names the user gave the device.
    private static let nameKeys = ["DeviceName"]

    /// Keys holding a UDID, which is shortened rather than taken out.
    private static let udidKeys = ["UniqueDeviceID", "UDID", "remotepairing_udid"]

    /// One printed value, in the forms the log uses:
    /// Rust `{:#?}` bytes `Data(\n [\n 225,\n … ],\n )`; idevice's
    /// `Data(E9 14 … Len: 32)`; wrapped scalars `String("…")`, `UInt64(…)`;
    /// quoted strings; bare tokens.
    private static let value = #"""
    (?:Data\(\s*\[[^\]]*\]\s*,?\s*\)|Data\([^)]*\)|[A-Za-z0-9]+\(\s*"(?:[^"\\]|\\.)*"\s*\)|[A-Za-z0-9]+\([^()\s,]*\)|"(?:[^"\\]|\\.)*"|[^\s,;)}\]]+)
    """#

    // MARK: Rules

    private static let rules: [(String) -> String] = [
        // Swift's `  DeviceName = My iPhone` lines: the value runs to the end.
        replacing(#"(?m)^(\s*)(\#(alternation(secretKeys + nameKeys))) = .+$"#) { m, s in
            "\(s.group(m, 1))\(s.group(m, 2)) = \(marker(forKey: s.group(m, 2), value: ""))"
        },
        replacing(#"(?m)^(\s*)(\#(alternation(udidKeys))) = (\S+)$"#) { m, s in
            "\(s.group(m, 1))\(s.group(m, 2)) = \(maskUDID(s.group(m, 3)))"
        },
        // `Key: value`, `"Key": value`, `key=value`, in any of the printed forms.
        replacing(#"(?<![\w-])("?)(\#(alternation(secretKeys + nameKeys)))\1(\s*[:=]\s*)(?!‹)(\#(value))"#) { m, s in
            let key = s.group(m, 2)
            return "\(s.group(m, 1))\(key)\(s.group(m, 1))\(s.group(m, 3))\(marker(forKey: key, value: s.group(m, 4)))"
        },
        // A pairing peer's identity blob (OPACK: its name, altIRK, account and
        // addresses) and serial, as TLV bytes.
        replacing(#"(tlv_type: (?:Info|SerialNumber),\s*data: )\[([^\]]*)\]"#) { m, s in
            "\(s.group(m, 1))\(bytesMarker(count: byteCount(s.group(m, 2))))"
        },
        // Old-style 40-hex UDIDs, where a key says it's one (a bare 40-hex
        // string is as likely a hash or a commit).
        replacing(#"(?<![\w-])("?)(\#(alternation(udidKeys)))\1(\s*[:=]\s*(?:String\()?"?)([0-9A-Fa-f]{40})\b"#) { m, s in
            "\(s.group(m, 1))\(s.group(m, 2))\(s.group(m, 1))\(s.group(m, 3))\(maskUDID(s.group(m, 4)))"
        },
        // Current UDIDs anywhere: 8 hex, a dash, 16 hex.
        replacing(#"\b([0-9A-Fa-f]{8})-([0-9A-Fa-f]{16})\b"#) { m, s in
            maskUDID("\(s.group(m, 1))-\(s.group(m, 2))")
        },
        // Email addresses anywhere, the Apple ID above all. `*` is allowed in
        // the local part so an address isideload already masked stays as it is.
        replacing(#"[A-Za-z0-9._%+*-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#) { m, s in
            maskAppleID(s.group(m, 0))
        },
        // A sign-in's "team: Name (TEAMID1234)": a personal team is named after
        // its owner. The team ID stays, since bundle IDs and certificates carry it.
        replacing(#"\b(team:? )[^\n]+ (\([A-Z0-9]{10}\))"#) { m, s in
            "\(s.group(m, 1))‹name› \(s.group(m, 2))"
        },
    ]

    /// What a taken value is replaced with. Bytes keep their count, since a
    /// key of the wrong length is a bug worth seeing.
    private static func marker(forKey key: String, value: String) -> String {
        if nameKeys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
            return "‹device name›"
        }
        if value.hasPrefix("Data(") {
            if let range = value.range(of: #"Len: (\d+)"#, options: .regularExpression) {
                return bytesMarker(count: Int(value[range].dropFirst(5)) ?? 0)
            }
            return bytesMarker(count: byteCount(value))
        }
        return "‹redacted›"
    }

    private static func bytesMarker(count: Int) -> String { "‹\(count) bytes redacted›" }

    /// Entries in a printed byte list: `[\n 225,\n 120,\n ]` or `[225, 120]`.
    private static func byteCount(_ list: String) -> Int {
        list.split(whereSeparator: { !$0.isNumber }).count
    }

    // MARK: Regex plumbing

    private static func alternation(_ keys: [String]) -> String {
        keys.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    }

    /// A rule replacing each match of `pattern` with what `transform` returns.
    private static func replacing(
        _ pattern: String,
        _ transform: @escaping (NSTextCheckingResult, NSString) -> String
    ) -> (String) -> String {
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        return { text in
            let source = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
            guard !matches.isEmpty else { return text }
            let out = NSMutableString(string: text)
            for match in matches.reversed() {
                out.replaceCharacters(in: match.range, with: transform(match, source))
            }
            return out as String
        }
    }
}

private extension NSString {
    /// The text of `match`'s capture group `index`, or "" when it took no part.
    func group(_ match: NSTextCheckingResult, _ index: Int) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : substring(with: range)
    }
}
