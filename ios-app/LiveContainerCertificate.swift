import Foundation
import Security

/// SideStore's certificate as LiveContainer holds it, for “Use SideStore's
/// certificate” while SideInstaller runs inside LiveContainer (issue #95).
///
/// Asking SideStore can't work there. iOS opens only the URL schemes in
/// LiveContainer's Info.plist, which has no `sideinstaller`, so the link
/// SideStore sends back goes nowhere. LiveContainer's own links don't help
/// either: while a guest app runs it drops every `livecontainer://` link it
/// doesn't handle itself, and its `open-url` forwarding wants the whole link
/// base64-encoded, which SideStore's callback template can't produce.
///
/// SideInstaller runs in LiveContainer's own process, though, so it reads the
/// certificate where LiveContainer's Settings read it:
/// - the built-in SideStore's Keychain entry (LiveContainer + SideStore): the
///   certificate SideStore signs with now;
/// - the copy LiveContainer keeps after “Import Certificate From SideStore”,
///   in its app-group defaults.
enum LiveContainerCertificate {
    /// A certificate found, and where, for the log.
    struct Found {
        let certificate: LinkedCertificate
        let source: String
    }

    /// The certificates LiveContainer holds, the built-in SideStore's first,
    /// without repeats. Empty outside LiveContainer or when it holds none.
    /// `log` gets a line for each place that has nothing usable.
    static func find(log: (String) -> Void) -> [Found] {
        guard Engine.runsInLiveContainer else { return [] }
        var found: [Found] = []
        func add(_ data: Data, password: String?, source: String) {
            guard LinkedCertificate.isPlausibleArchive(data) else {
                log("Certificates: \(source) isn't a certificate archive (\(data.count) bytes).")
                return
            }
            guard !found.contains(where: { $0.certificate.data == data }) else { return }
            found.append(Found(certificate: LinkedCertificate(data: data, password: password ?? "",
                                                              fromSideStore: true),
                               source: source))
        }

        let builtIn = "the built-in SideStore's certificate"
        if hasBuiltInSideStore == false {
            log("Certificates: this LiveContainer has no built-in SideStore.")
        } else {
            let certificate = builtInSideStoreItem("signingCertificate")
            if let data = certificate.data {
                let password = builtInSideStoreItem("signingCertificatePassword").data
                add(data, password: password.flatMap { String(data: $0, encoding: .utf8) }, source: builtIn)
            } else {
                log("Certificates: the built-in SideStore has no certificate in the Keychain (status \(certificate.status)).")
            }
        }

        let copy = "LiveContainer's copy of SideStore's certificate"
        if let defaults = liveContainerDefaults {
            if let data = defaults.data(forKey: "LCCertificateData"), !data.isEmpty {
                add(data, password: defaults.string(forKey: "LCCertificatePassword"), source: copy)
            } else {
                log("Certificates: LiveContainer has no copy of SideStore's certificate.")
            }
        } else {
            log("Certificates: LiveContainer's settings can't be read.")
        }
        return found
    }

    // MARK: - The built-in SideStore's Keychain entry

    /// SideStore files its Keychain items under its bundle ID, which
    /// LiveContainer reports to its built-in SideStore as this.
    private static let builtInSideStoreService = "com.kdt.livecontainer"

    /// `+[NSUserDefaults sideStoreExist]`, which LiveContainer adds for its
    /// guest apps: whether it carries a built-in SideStore. Nil when it can't
    /// be asked (an older LiveContainer).
    private static var hasBuiltInSideStore: Bool? {
        let selector = NSSelectorFromString("sideStoreExist")
        guard let method = class_getClassMethod(UserDefaults.self, selector) else { return nil }
        typealias Getter = @convention(c) (AnyClass, Selector) -> Bool
        let get = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        return get(UserDefaults.self, selector)
    }

    /// One of the built-in SideStore's Keychain items, and the status it was
    /// looked up with.
    private static func builtInSideStoreItem(_ account: String) -> (data: Data?, status: OSStatus) {
        guard let copyMatching = unhookedCopyMatching else { return (nil, errSecUnimplemented) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: builtInSideStoreService,
            kSecAttrAccount as String: account,
            // SideStore's items sync with iCloud Keychain.
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = copyMatching(query as CFDictionary, &item)
        return (status == errSecSuccess ? item as? Data : nil, status)
    }

    private typealias CopyMatching =
        @convention(c) (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus

    /// `SecItemCopyMatching` as Security exports it. LiveContainer redirects a
    /// guest app's Keychain calls to the guest's own Keychain group by
    /// rewriting the app's symbol pointers, which `dlsym` doesn't go through.
    /// Its built-in SideStore isn't redirected, so its items lie outside that
    /// group; LiveContainer's Settings read them with the same lookup.
    private static let unhookedCopyMatching: CopyMatching? = {
        guard let security = dlopen("/System/Library/Frameworks/Security.framework/Security",
                                    RTLD_NOW | RTLD_NOLOAD),
              let symbol = dlsym(security, "SecItemCopyMatching")
        else { return nil }
        return unsafeBitCast(symbol, to: CopyMatching.self)
    }()

    // MARK: - LiveContainer's copy

    /// LiveContainer's app-group defaults, from the `+[NSUserDefaults
    /// lcSharedDefaults]` it adds for its guest apps (opened before it
    /// redirected the guest's own defaults).
    private static var liveContainerDefaults: UserDefaults? {
        let selector = NSSelectorFromString("lcSharedDefaults")
        let defaults = UserDefaults.self as AnyObject
        guard defaults.responds(to: selector) else { return nil }
        return defaults.perform(selector)?.takeUnretainedValue() as? UserDefaults
    }
}
