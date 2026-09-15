import Foundation
import Security
import SideInstallerFFI

/// One saved Apple ID. Only the email is kept in the struct: the password lives
/// in the keychain filed under `id`, so it never reaches a plist or an
/// unencrypted backup.
struct SavedAccount: Identifiable, Codable, Equatable {
    let id: UUID
    var appleID: String

    init(id: UUID = UUID(), appleID: String) {
        self.id = id
        self.appleID = appleID
    }

    /// The email as sent to Apple; a stray space breaks the SRP proof.
    var normalized: String {
        appleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Saved Apple IDs and which one is active for sign-ins. Added during setup and
/// managed in Settings › Account.
///
/// A singleton so `Engine` can read the active credentials directly.
final class AccountStore: ObservableObject {

    static let shared = AccountStore()

    /// Every saved Apple ID, oldest first.
    @Published private(set) var accounts: [SavedAccount] = []

    /// The account every sign-in uses. Nil only while `accounts` is empty.
    @Published private(set) var activeID: UUID?

    /// Incremented when the active credentials change (different account or new
    /// password). Cached Apple sessions are dropped when it changes.
    @Published private(set) var revision: Int = 0

    /// Set when the keychain refused a write (the password won't survive a
    /// relaunch). Nil normally.
    @Published private(set) var keychainWarning: String?

    private static let accountsKey = "savedAppleAccounts"
    private static let activeKey = "activeAppleAccountID"
    /// Keychain service every saved password is filed under.
    private static let service = "com.frizzle.SideInstaller.appleID"

    /// Passwords the keychain rejected, kept in memory for this launch only.
    private var volatilePasswords: [UUID: String] = [:]

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.accountsKey),
           let decoded = try? JSONDecoder().decode([SavedAccount].self, from: data) {
            accounts = decoded
        }
        if let raw = defaults.string(forKey: Self.activeKey), let id = UUID(uuidString: raw),
           accounts.contains(where: { $0.id == id }) {
            activeID = id
        } else {
            activeID = accounts.first?.id
        }
    }

    // MARK: - The active account

    var active: SavedAccount? {
        guard let activeID else { return nil }
        return accounts.first { $0.id == activeID }
    }

    /// The active account's email, or "" when none is saved.
    var activeAppleID: String { active?.normalized ?? "" }

    /// The active account's password, or "" when none is saved.
    var activePassword: String {
        guard let active else { return "" }
        return password(for: active)
    }

    /// True when there is no account to sign in with.
    var isEmpty: Bool { accounts.isEmpty }

    /// True when `account` is the one in use.
    func isActive(_ account: SavedAccount) -> Bool { account.id == activeID }

    func password(for account: SavedAccount) -> String {
        volatilePasswords[account.id] ?? Self.keychainRead(account.id) ?? ""
    }

    // MARK: - Mutations

    /// Adds or updates an Apple ID and makes it active. Updates `existing` if
    /// given, otherwise any account with the same email (so a new password
    /// doesn't create a duplicate).
    @discardableResult
    func save(appleID: String, password: String, replacing existing: SavedAccount? = nil) -> SavedAccount {
        let email = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = existing
            ?? accounts.first { $0.normalized.caseInsensitiveCompare(email) == .orderedSame }

        let account: SavedAccount
        if let target, let idx = accounts.firstIndex(where: { $0.id == target.id }) {
            // A changed password or email invalidates the saved Apple session.
            if password != self.password(for: target) || email != target.normalized {
                Self.forgetAppleSession(for: target.normalized)
            }
            accounts[idx].appleID = email
            account = accounts[idx]
        } else {
            account = SavedAccount(appleID: email)
            accounts.append(account)
        }
        store(password: password, for: account.id)
        activeID = account.id
        persist()
        revision += 1
        return account
    }

    /// Removes an Apple ID and its password. If it was active, the first
    /// remaining account becomes active.
    func remove(_ account: SavedAccount) {
        accounts.removeAll { $0.id == account.id }
        volatilePasswords[account.id] = nil
        Self.keychainDelete(account.id)
        Self.forgetAppleSession(for: account.normalized)
        if activeID == account.id {
            activeID = accounts.first?.id
            revision += 1
        }
        persist()
    }

    /// Make `account` the one every sign-in uses.
    func activate(_ account: SavedAccount) {
        guard activeID != account.id, accounts.contains(where: { $0.id == account.id }) else { return }
        activeID = account.id
        persist()
        revision += 1
    }

    /// Delete the developer session the Rust core saved for `appleID`, so its
    /// next sign-in logs in to Apple again instead of reusing the token.
    private static func forgetAppleSession(for appleID: String) {
        _ = si_forget_apple_session(PrivateStore.isideload.path, appleID)
    }

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Self.accountsKey)
        }
        defaults.set(activeID?.uuidString, forKey: Self.activeKey)
    }

    /// Saves the password to the keychain, or to memory with a warning if the
    /// keychain refuses.
    private func store(password: String, for id: UUID) {
        if let status = Self.keychainWrite(password, for: id) {
            volatilePasswords[id] = password
            keychainWarning = L("This iPhone's keychain refused to store the password (error %d), so it's kept only until SideInstaller quits.", Int(status))
        } else {
            volatilePasswords[id] = nil
            keychainWarning = nil
        }
    }

    // MARK: - Keychain

    private static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString]
    }

    private static func keychainRead(_ id: UUID) -> String? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns nil on success, or the `OSStatus` that stopped the write.
    private static func keychainWrite(_ password: String, for id: UUID) -> OSStatus? {
        let data = Data(password.utf8)
        let update = SecItemUpdate(query(id) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return nil }
        guard update == errSecItemNotFound else { return update }

        var add = query(id)
        add[kSecValueData as String] = data
        // Readable while locked (after first unlock), since signing can run
        // unattended.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess ? nil : status
    }

    private static func keychainDelete(_ id: UUID) {
        SecItemDelete(query(id) as CFDictionary)
    }
}
