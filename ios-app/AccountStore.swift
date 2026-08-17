import Foundation
import Security

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

/// The Apple IDs saved on this iPhone, and which one every credential-taking
/// action signs in as. Entered once during setup, managed afterwards from
/// Settings › Account.
///
/// A singleton because `Engine` — itself one, reachable from C callbacks —
/// reads the active credentials straight off it.
final class AccountStore: ObservableObject {

    static let shared = AccountStore()

    /// Every saved Apple ID, oldest first.
    @Published private(set) var accounts: [SavedAccount] = []

    /// The account every sign-in uses. Nil only while `accounts` is empty.
    @Published private(set) var activeID: UUID?

    /// Bumped whenever the active credentials change — a different account, or
    /// a new password on the one in use. Cached Apple sessions key off this.
    @Published private(set) var revision: Int = 0

    /// Set when the keychain refused a write, so the UI can say why a password
    /// won't survive a relaunch. Nil in the normal case.
    @Published private(set) var keychainWarning: String?

    private static let accountsKey = "savedAppleAccounts"
    private static let activeKey = "activeAppleAccountID"
    /// Keychain service every saved password is filed under.
    private static let service = "com.frizzle.SideInstaller.appleID"

    /// Passwords the keychain wouldn't take, kept for this launch only so a
    /// keychain-less build still signs in rather than failing silently.
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

    /// Add an Apple ID, or update one — `replacing` when the user edited a row,
    /// and otherwise any existing entry with the same email, so re-entering an
    /// address after a password change updates it instead of duplicating it.
    /// The saved account becomes the active one.
    @discardableResult
    func save(appleID: String, password: String, replacing existing: SavedAccount? = nil) -> SavedAccount {
        let email = appleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = existing
            ?? accounts.first { $0.normalized.caseInsensitiveCompare(email) == .orderedSame }

        let account: SavedAccount
        if let target, let idx = accounts.firstIndex(where: { $0.id == target.id }) {
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

    /// Forget an Apple ID and delete its password. Removing the active one
    /// promotes whichever account is left.
    func remove(_ account: SavedAccount) {
        accounts.removeAll { $0.id == account.id }
        volatilePasswords[account.id] = nil
        Self.keychainDelete(account.id)
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

    // MARK: - Persistence

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: Self.accountsKey)
        }
        defaults.set(activeID?.uuidString, forKey: Self.activeKey)
    }

    /// Write to the keychain, falling back to memory if it refuses — a build
    /// signed without a keychain-access group would otherwise lose the password
    /// on every launch with nothing on screen to explain it.
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
        // Signing runs unattended after an install starts, so the item has to be
        // readable without the phone being unlocked right then.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess ? nil : status
    }

    private static func keychainDelete(_ id: UUID) {
        SecItemDelete(query(id) as CFDictionary)
    }
}
