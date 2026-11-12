import Testing
@testable import SideInstaller

// Every value below is made up. The shapes are the ones the log prints: Rust's
// `{:?}` and `{:#?}`, idevice's plist printer, and the app's own lines.

/// Rust's `{:?}` of a byte list: `[60, 63, 120]`.
private func flat(_ numbers: [Int]) -> String {
    "[" + numbers.map(String.init).joined(separator: ", ") + "]"
}

/// Rust's `{:#?}` of a byte list: one number a line, each with a comma.
private func pretty(_ numbers: [Int], indent: String = "") -> String {
    "[\n" + numbers.map { "\(indent)    \($0),\n" }.joined() + "\(indent)]"
}

private func bytes(_ text: String) -> [Int] { text.utf8.map(Int.init) }

// MARK: - Files read back over AFC (the activity-log leak of 2026-11-05)

/// What `DeviceConnection.writeVerified` read back and idevice logged at DEBUG,
/// payload and all: the files that carry keys and passwords.
private let filesReadBack: [String] = [
    // A pairing file, private key included.
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0"><dict><key>alt_irk</key><data>AAECAwQFBgcICQoLDA0ODw==</data>\
    <key>private_key</key><data>3q2+7wABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhs=</data></dict></plist>
    """,
    // SideStore's Account.sideconf: the .p12, its password and the adi.pb.
    #"{"certificateP12":"MIIKOAIBAzCCCf4GCSqGSIb3DQEHAaCCCe8EggnrMIIJ5zCCBX8GCSqGSIb3","certificatePassword":"not-a-real-password","adiPb":"c2VjcmV0LW1hY2hpbmUtc3RhdGU="}"#,
    // Madeira's sign-in hand-off.
    #"{"appleID":"jane.appleseed@example.com","password":"not-a-real-password","anisetteAdiBlob":"bWFjaGluZQ=="}"#,
]

@Suite("Long byte lists")
struct LongByteListTests {

    @Test("A file read back over AFC becomes its length", arguments: filesReadBack)
    func afcReadBack(file: String) {
        let payload = bytes(file)
        let header = "Recv afc: AfcPacket { header: AfcPacketHeader { magic: 4851876449621427011, "
            + "entire_len: \(40 + payload.count), header_payload_len: 40, packet_num: 7, operation: ReadFile }, "
            + "header_payload: [3, 0, 0, 0, 0, 0, 0, 0], payload: "

        #expect(LogRedactor.redact(header + flat(payload) + " }")
                == header + "‹\(payload.count) bytes redacted› }")
    }

    @Test("Printed a byte a line, it's taken out the same way", arguments: filesReadBack)
    func afcReadBackPretty(file: String) {
        let payload = bytes(file)
        let line = "Recv afc: AfcPacket {\n    payload: \(pretty(payload, indent: "    ")),\n}"

        #expect(LogRedactor.redact(line)
                == "Recv afc: AfcPacket {\n    payload: ‹\(payload.count) bytes redacted›,\n}")
    }

    /// ICU stops matching a repeated group or a possessive run past about
    /// 100,000 entries without an error, so a big file got through whole.
    @Test("A list past ICU's 100,000-entry limit is still taken out")
    func veryLongList() {
        let payload = Array(repeating: 65, count: 150_000)

        #expect(LogRedactor.redact("payload: " + flat(payload)) == "payload: ‹150000 bytes redacted›")
        #expect(LogRedactor.redact("payload: " + pretty(payload)) == "payload: ‹150000 bytes redacted›")
    }

    @Test("33 numbers are taken out, 32 stay")
    func boundary() {
        let key = Array(0..<32)

        #expect(LogRedactor.redact("public_key: " + flat(key)) == "public_key: " + flat(key))
        #expect(LogRedactor.redact("salt: " + flat(key + [32])) == "salt: ‹33 bytes redacted›")
    }

    @Test("Numbers that aren't bytes are counted as numbers")
    func notBytes() {
        #expect(LogRedactor.redact(flat(Array(250..<290))) == "‹40 numbers redacted›")
        #expect(LogRedactor.redact(flat(Array(-20..<20))) == "‹40 numbers redacted›")
    }

    @Test("A short list printed a number a line goes on one line")
    func compactsShortLists() {
        #expect(LogRedactor.redact("public_key: " + pretty([103, 229, 1, 0])) == "public_key: [103, 229, 1, 0]")
        // plist's Value::Data under `{:#?}`.
        #expect(LogRedactor.redact("Data(\n    \(pretty([103, 229], indent: "    ")),\n)") == "Data([103, 229])")
    }

    @Test("A long list inside Data( ) becomes Data(‹… bytes redacted›)")
    func longDataValue() {
        let data = "Data(\n    \(pretty(Array(0..<64), indent: "    ")),\n)"

        #expect(LogRedactor.redact(data) == "Data(‹64 bytes redacted›)")
    }
}

// MARK: - Keys whose values are taken out whatever their length

@Suite("Secret keys")
struct SecretKeyTests {

    @Test("A key's Data keeps only its length")
    func keyedData() {
        let key = Array(200..<232)

        // `{:#?}` of a plist dictionary.
        #expect(LogRedactor.redact("private_key: Data(\n    \(pretty(key, indent: "    ")),\n)")
                == "private_key: ‹32 bytes redacted›")
        // idevice's plist printer.
        #expect(LogRedactor.redact(#""private_key": Data(E9 14 07 … Len: 32)"#)
                == #""private_key": ‹32 bytes redacted›"#)
    }

    /// 32 bytes are under the long-list limit, so only the key name can catch
    /// them, and a list isn't one of plist's printed forms.
    @Test("A key's plain byte list is taken out whole")
    func keyedByteList() {
        let key = Array(200..<232)

        #expect(LogRedactor.redact("private_key: " + flat(key)) == "private_key: ‹32 bytes redacted›")
        #expect(LogRedactor.redact("private_key: " + pretty(key)) == "private_key: ‹32 bytes redacted›")
        #expect(LogRedactor.redact("alt_irk: Some(\(flat(Array(0..<16))))") == "alt_irk: ‹16 bytes redacted›")
        #expect(LogRedactor.redact("EscrowBag: [], next: 1") == "EscrowBag: ‹0 bytes redacted›, next: 1")
    }

    @Test("Scalars, strings and bare values")
    func scalars() {
        #expect(LogRedactor.redact(#""SerialNumber": String("F2LXK0AAHG7F")"#) == #""SerialNumber": ‹redacted›"#)
        #expect(LogRedactor.redact("UniqueChipID: UInt64(1234567890123)") == "UniqueChipID: ‹redacted›")
        #expect(LogRedactor.redact(#"password="hunter2", next"#) == "password=‹redacted›, next")
        #expect(LogRedactor.redact("WiFiAddress: 3c:22:fb:01:02:03 ok") == "WiFiAddress: ‹redacted› ok")
        #expect(LogRedactor.redact(#""DeviceName": String("Jane's iPhone")"#) == #""DeviceName": ‹device name›"#)
    }

    @Test("Keys match whole and in any case")
    func keyMatching() {
        #expect(LogRedactor.redact("serialnumber: F2LXK0AAHG7F") == "serialnumber: ‹redacted›")
        #expect(LogRedactor.redact("MLBSerialNumber: C0212345") == "MLBSerialNumber: ‹redacted›")
        // Another word that starts or ends like a key is left alone.
        #expect(LogRedactor.redact("tokenType: bearer") == "tokenType: bearer")
        #expect(LogRedactor.redact("access_tk: 1") == "access_tk: 1")
    }

    @Test("The app's own Key = value lines")
    func swiftLines() {
        #expect(LogRedactor.redact("  DeviceName = Jane's iPhone") == "  DeviceName = ‹device name›")
        #expect(LogRedactor.redact("  SerialNumber = F2LXK0AAHG7F") == "  SerialNumber = ‹redacted›")
        #expect(LogRedactor.redact("  UniqueDeviceID = 00008120-001A2B3C4D5E6F70")
                == "  UniqueDeviceID = 00008120-…6F70")
        #expect(LogRedactor.redact("  ProductVersion = 27.1") == "  ProductVersion = 27.1")
    }

    @Test("A pairing peer's identity and serial TLVs")
    func tlv() {
        #expect(LogRedactor.redact("TlvEntry { tlv_type: Info, data: [10, 20, 30] }")
                == "TlvEntry { tlv_type: Info, data: ‹3 bytes redacted› }")
        #expect(LogRedactor.redact("TlvEntry { tlv_type: State, data: [1] }")
                == "TlvEntry { tlv_type: State, data: [1] }")
    }
}

// MARK: - The person and the device

@Suite("Identities")
struct IdentityTests {

    @Test("UDIDs keep the chip and the last four")
    func udids() {
        #expect(LogRedactor.redact("Connected to 00008120-001A2B3C4D5E6F70 over the tunnel")
                == "Connected to 00008120-…6F70 over the tunnel")
        #expect(LogRedactor.redact("UDID: 0123456789abcdef0123456789abcdef01234567")
                == "UDID: …4567")
        // A bare 40-hex string is as likely a commit.
        #expect(LogRedactor.redact("built from 0123456789abcdef0123456789abcdef01234567")
                == "built from 0123456789abcdef0123456789abcdef01234567")
    }

    @Test("Email addresses are masked, masked ones stay")
    func emails() {
        #expect(LogRedactor.redact("Signing in as jane.appleseed@example.com")
                == "Signing in as j***d@example.com")
        #expect(LogRedactor.redact("Signed in as j***d@example.com") == "Signed in as j***d@example.com")
    }

    @Test("A team keeps its ID, not its owner's name")
    func team() {
        #expect(LogRedactor.redact("Signed in, team: Jane Appleseed (A1B2C3D4E5)")
                == "Signed in, team: ‹name› (A1B2C3D4E5)")
    }

    @Test(arguments: [
        ("jane.appleseed@example.com", "j***d@example.com"),
        ("ab@example.com", "a***@example.com"),
        ("@example.com", "***@example.com"),
        ("+1 (555) 123-4567", "•••67"),
        ("12", "•••"),
    ])
    func maskAppleID(id: String, shown: String) {
        #expect(LogRedactor.maskAppleID(id) == shown)
    }

    @Test(arguments: [
        ("00008120-001A2B3C4D5E6F70", "00008120-…6F70"),
        ("0123456789abcdef0123456789abcdef01234567", "…4567"),
        ("abcd", "…"),
    ])
    func maskUDID(udid: String, shown: String) {
        #expect(LogRedactor.maskUDID(udid) == shown)
    }
}

// MARK: - What a bug report needs

@Suite("What stays")
struct WhatStaysTests {

    @Test(arguments: [
        "iPhone17,1 on iOS 27.1 (24B5070a)",
        "RSD tunnel up: fd35:2a1b:7c00::1 port 49152, services: 42",
        "error: Connection refused (os error 61)",
        "Team ID A1B2C3D4E5, bundle com.example.app",
        "Installed 3 of 3 [100%]",
        "Data([1, 2, 3])",
    ])
    func unchanged(line: String) {
        #expect(LogRedactor.redact(line) == line)
    }

    /// `lastError` is redacted again for Report a problem, after the log
    /// already redacted it.
    @Test("Redacting twice changes nothing more")
    func idempotent() {
        let line = "jane.appleseed@example.com on 00008120-001A2B3C4D5E6F70, team: Jane (A1B2C3D4E5), "
            + "private_key: Data(E9 14 … Len: 32), payload: \(flat(Array(0..<64))), DeviceName: Jane"
        let once = LogRedactor.redact(line)

        #expect(once == "j***d@example.com on 00008120-…6F70, team: ‹name› (A1B2C3D4E5), "
                + "private_key: ‹32 bytes redacted›, payload: ‹64 bytes redacted›, DeviceName: ‹device name›")
        #expect(LogRedactor.redact(once) == once)
    }
}
