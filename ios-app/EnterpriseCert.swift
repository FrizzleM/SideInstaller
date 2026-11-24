import Foundation
import Security
import SideInstallerFFI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 企业证书签名的材料存储：.p12 与 .mobileprovision 复制进
/// App 自己的支持目录，密码存钥匙串（Keychain，不再是明文
/// UserDefaults）。注意：这里是导入证书时填的密码，和证书页
/// 导出个人证书 p12 的密码“1”完全是两回事，那处在
/// rust-core/src/certs.rs 里，本文件不碰它。
/// 多证书库：EnterpriseCert/profiles/<id>/ 下每 profile 一套
/// cert.p12 + profile.mobileprovision，密码每 profile 一个钥匙串
/// account；老单证书首次打开列表时自动迁成第一个 profile。
/// 全部取用口（p12URL/provisionURL/password/hasP12/hasProvision/
/// ready/certInfo/provisionInfo/certMatchesProvision/importP12/
/// importProvision）都解析到当前激活 profile，调用方不用改。
struct EnterpriseCertProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
}

enum EnterpriseCertStore {
    static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EnterpriseCert", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    /// 当前激活 profile 的 p12 / 描述文件：有 profile 时走
    /// profiles/<id>/ 下的文件，没有 profile 时回落到老单证书
    /// 路径（EnterpriseCert/cert.p12），老用户没建过 profile
    /// 时行为与以前一模一样；profile 列表一打开就迁移（见
    /// migrateIfNeeded），之后一律走 profile 路径。
    static var p12URL: URL {
        if let active = activeProfile() {
            return profileDir(for: active).appendingPathComponent("cert.p12")
        }
        return dir.appendingPathComponent("cert.p12")
    }
    static var provisionURL: URL {
        if let active = activeProfile() {
            return profileDir(for: active).appendingPathComponent("profile.mobileprovision")
        }
        return dir.appendingPathComponent("profile.mobileprovision")
    }
    static var hasP12: Bool { FileManager.default.fileExists(atPath: p12URL.path) }
    static var hasProvision: Bool { FileManager.default.fileExists(atPath: provisionURL.path) }
    static var password: String {
        get {
            // S10：钥匙串写失败进 fallback 后，即使钥匙串里有
            // 旧条目，getter 也要先认新密码——以前先读钥匙串、
            // 有值直接返回，改密场景下界面显示新密码、签名实际
            // 用旧密码，报错“密码错误”且重输难定位。
            // 多证书库：内存 fallback 只认写进它的那个 profile，
            // 切 profile 后旧 fallback 不得串到新 profile 上。
            if memoryFallbackValid, memoryFallbackProfileID == activeProfileIDValue,
               let fallback = memoryFallback { return fallback }
            if let stored = keychainRead(account: keychainAccount) { return stored }
            // 迁移 profile 的旧钥匙串条目兜底：新 account 还没写
            // 进去之前（迁移写失败那次），旧 account 里仍是有效密码。
            if keychainAccount != legacyKeychainAccount,
               let legacy = keychainRead(account: legacyKeychainAccount) { return legacy }
            if memoryFallbackProfileID == activeProfileIDValue,
               let fallback = memoryFallback { return fallback }
            // 一次性迁移：旧版存在 UserDefaults 的明文密码搬进
            // 钥匙串后清掉旧键，之后再读就只走钥匙串。
            let legacy = UserDefaults.standard.string(forKey: "CZFEnterpriseCertPassword") ?? ""
            if !legacy.isEmpty {
                if keychainWrite(legacy, account: keychainAccount) == nil {
                    UserDefaults.standard.removeObject(forKey: "CZFEnterpriseCertPassword")
                    memoryFallbackValid = false
                } else {
                    // 钥匙串写不进：先留内存给本次用，旧键也留着，
                    // 下次启动再试迁移，免得密码丢了要重填；同时
                    // 标记有效，免得钥匙串旧条目把刚迁的盖回去。
                    memoryFallback = legacy
                    memoryFallbackValid = true
                    memoryFallbackProfileID = activeProfileIDValue
                }
                return legacy
            }
            return ""
        }
        set {
            UserDefaults.standard.removeObject(forKey: "CZFEnterpriseCertPassword")
            memoryFallbackProfileID = activeProfileIDValue
            if newValue.isEmpty {
                keychainDelete(account: keychainAccount)
                memoryFallback = nil
                memoryFallbackValid = false
            } else {
                // 钥匙串万一写不进（极少见），只留在内存里撑到
                // App 退出，不回写 UserDefaults 明文；同时标记
                // 有效（见 S10），下次读先认它，不认旧条目。
                if keychainWrite(newValue, account: keychainAccount) == nil {
                    memoryFallback = nil
                    memoryFallbackValid = false
                } else {
                    memoryFallback = newValue
                    memoryFallbackValid = true
                }
            }
        }
    }
    /// 钥匙串写失败时的当会话 fallback（AccountStore 的
    /// volatilePasswords 同款做法），App 退出即丢。
    private static var memoryFallback: String?
    /// memoryFallback 是否是本次会话里最新写入的密码（见 S10）：
    /// 只在钥匙串写失败、密码被迫留内存时为 true；钥匙串写成
    /// 功或密码清空时为 false。首次导入无旧条目时钥匙串读本
    /// 来就是空，fallback 正常工作，本标志不改变那条路径。
    private static var memoryFallbackValid = false
    /// memoryFallback 是哪个 profile 的密码：切 profile 时清掉，
    /// 免得旧 profile 的内存密码串到新 profile 上。
    private static var memoryFallbackProfileID: UUID?
    static var ready: Bool { hasP12 && hasProvision && !password.isEmpty }

    // MARK: - 钥匙串（AccountStore 的 Keychain 模板同款）

    private static var keychainService: String { "czf.enterprise.cert" }
    /// 当前激活 profile 的钥匙串 account：没 profile 时就是老
    /// 单证书的 "password"，老用户密码不用重填。
    private static var keychainAccount: String {
        if let id = activeProfileIDValue { return "password-\(id.uuidString)" }
        return legacyKeychainAccount
    }
    private static var legacyKeychainAccount: String { "password" }

    private static func keychainQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: account]
    }

    private static func keychainRead(account: String) -> String? {
        var query = keychainQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 成功返回 nil，失败返回 OSStatus（调用方据此决定要不要
    /// 用内存 fallback）。
    private static func keychainWrite(_ value: String, account: String) -> OSStatus? {
        let data = Data(value.utf8)
        let update = SecItemUpdate(keychainQuery(account: account) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return nil }
        guard update == errSecItemNotFound else { return update }
        var add = keychainQuery(account: account)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess ? nil : status
    }

    private static func keychainDelete(account: String) {
        SecItemDelete(keychainQuery(account: account) as CFDictionary)
    }

    static func importP12(from url: URL) throws {
        try Data(contentsOf: url).write(to: p12URL, options: .atomic)
    }
    static func importProvision(from url: URL) throws {
        try Data(contentsOf: url).write(to: provisionURL, options: .atomic)
    }

    // MARK: - 多证书库（profile）

    private static var profilesDir: URL {
        let d = dir.appendingPathComponent("profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private static var indexURL: URL { dir.appendingPathComponent("profiles.json") }

    private static var activeProfileIDKey: String { "CZFEnterpriseCertActiveProfileID" }

    /// UserDefaults 里记的激活 profile id（只读原始值，不触发
    /// 迁移、不读列表；密码 getter 走这条，免得跟迁移递归）。
    private static var activeProfileIDValue: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: activeProfileIDKey),
              let id = UUID(uuidString: raw) else { return nil }
        return id
    }

    private static func profileDir(for profile: EnterpriseCertProfile) -> URL {
        profilesDir.appendingPathComponent(profile.id.uuidString, isDirectory: true)
    }

    private static func saveProfiles(_ profiles: [EnterpriseCertProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    /// 老单证书一次性迁移：index 还没有、且顶层还有老文件时，
    /// 把顶层 cert.p12 / profile.mobileprovision 拷进第一个
    /// profile（不丢数据、不要求重导），密码从老钥匙串 account
    /// 迁到新 profile 的 account；index 一建好之后不再跑，
    /// 顶层残留文件（迁移中途崩溃留下的）之后一律忽略。
    /// 只读显式旧路径，不走 p12URL/certInfo（那两条会解析到
    /// 激活 profile，迁移里调它们就递归了）。
    private static func migrateIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: indexURL.path) else { return }
        let oldP12 = dir.appendingPathComponent("cert.p12")
        let oldProvision = dir.appendingPathComponent("profile.mobileprovision")
        let hasOldP12 = fm.fileExists(atPath: oldP12.path)
        let hasOldProvision = fm.fileExists(atPath: oldProvision.path)
        guard hasOldP12 || hasOldProvision else { return }
        let id = UUID()
        let pdir = profilesDir.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try fm.createDirectory(at: pdir, withIntermediateDirectories: true)
            if hasOldP12 {
                try Data(contentsOf: oldP12).write(to: pdir.appendingPathComponent("cert.p12"), options: .atomic)
            }
            if hasOldProvision {
                try Data(contentsOf: oldProvision).write(to: pdir.appendingPathComponent("profile.mobileprovision"), options: .atomic)
            }
        } catch {
            try? fm.removeItem(at: pdir)
            return
        }
        // 名：证书名优先（老密码直接读老 account，不触发迁移
        // 副作用），解不开退到描述文件名，再退到“证书”。
        var name = ""
        let oldPassword = keychainRead(account: legacyKeychainAccount)
            ?? UserDefaults.standard.string(forKey: "CZFEnterpriseCertPassword") ?? ""
        if hasOldP12,
           let data = try? Data(contentsOf: oldP12),
           let certName = certName(p12Data: data, password: oldPassword), !certName.isEmpty {
            name = certName
        } else if hasOldProvision,
                  let pname = provisionInfo(at: oldProvision)?.name, !pname.isEmpty {
            name = pname
        } else {
            name = L("Certificates")
        }
        saveProfiles([EnterpriseCertProfile(id: id, name: name)])
        UserDefaults.standard.set(id.uuidString, forKey: activeProfileIDKey)
        // 密码：新 account 写成了才删老 account；写失败就留着，
        // password 读时新 account 为空会回落到老 account。
        if !oldPassword.isEmpty,
           keychainWrite(oldPassword, account: "password-\(id.uuidString)") == nil {
            keychainDelete(account: legacyKeychainAccount)
            UserDefaults.standard.removeObject(forKey: "CZFEnterpriseCertPassword")
        }
        // 顶层旧文件：拷过去的已验证存在才删；删不掉也无妨
        //（index 在，迁移不再跑，旧文件从此被忽略）。
        if hasOldP12, fm.fileExists(atPath: pdir.appendingPathComponent("cert.p12").path) {
            try? fm.removeItem(at: oldP12)
        }
        if hasOldProvision, fm.fileExists(atPath: pdir.appendingPathComponent("profile.mobileprovision").path) {
            try? fm.removeItem(at: oldProvision)
        }
    }

    /// profile 列表（导入顺序）：先跑一次迁移；目录被外删的
    /// profile 自动掉出列表，下次写 index 时顺带清掉残条。
    static func profiles() -> [EnterpriseCertProfile] {
        migrateIfNeeded()
        guard let data = try? Data(contentsOf: indexURL),
              let all = try? JSONDecoder().decode([EnterpriseCertProfile].self, from: data) else { return [] }
        return all.filter { FileManager.default.fileExists(atPath: profileDir(for: $0).path) }
    }

    /// 当前激活 profile：记的 id 找不着（删激活后已回落过、
    /// 或 index 被外改）就回落到第一个；一个没有就 nil。
    static func activeProfile() -> EnterpriseCertProfile? {
        activeProfile(profiles: profiles())
    }

    /// 同上，但用调用方已读好的列表，不再重读一次（见
    /// EnterpriseCertView.refreshCertState 的一次读三遍修法）。
    static func activeProfile(profiles: [EnterpriseCertProfile]) -> EnterpriseCertProfile? {
        let all = profiles
        if let id = activeProfileIDValue, let found = all.first(where: { $0.id == id }) { return found }
        return all.first
    }

    static func setActiveProfile(_ profile: EnterpriseCertProfile) {
        UserDefaults.standard.set(profile.id.uuidString, forKey: activeProfileIDKey)
        memoryFallback = nil
        memoryFallbackValid = false
        memoryFallbackProfileID = nil
    }

    /// 新建一个 profile（证书库“导入新证书”用）：文件先拷进
    /// 新目录，名默认取证书名（p12 + 刚填的密码现解），解不开
    /// 退到描述文件名，再退到“证书 N”；建好就切成激活，密码
    /// 写进新 profile 的钥匙串 account（空密码就不写，证书组
    /// 里再填）。配对检查这里不做——没密码时查不出来，签名
    /// 时 validateForSigning 自会拦对不上的。
    static func importProfile(p12: URL, provision: URL, p12Password: String) throws -> EnterpriseCertProfile {
        migrateIfNeeded()
        let id = UUID()
        let pdir = profilesDir.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: pdir, withIntermediateDirectories: true)
            try Data(contentsOf: p12).write(to: pdir.appendingPathComponent("cert.p12"), options: .atomic)
            try Data(contentsOf: provision).write(to: pdir.appendingPathComponent("profile.mobileprovision"), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: pdir)
            throw error
        }
        var name = ""
        if let data = try? Data(contentsOf: pdir.appendingPathComponent("cert.p12")),
           let certName = certName(p12Data: data, password: p12Password), !certName.isEmpty {
            name = certName
        } else if let pname = provisionInfo(at: pdir.appendingPathComponent("profile.mobileprovision"))?.name, !pname.isEmpty {
            name = pname
        } else {
            name = L("证书 %d", profiles().count + 1)
        }
        let profile = EnterpriseCertProfile(id: id, name: name)
        var all = profiles()
        all.append(profile)
        saveProfiles(all)
        UserDefaults.standard.set(id.uuidString, forKey: activeProfileIDKey)
        memoryFallback = nil
        memoryFallbackValid = false
        memoryFallbackProfileID = nil
        if !p12Password.isEmpty {
            password = p12Password
        }
        return profile
    }

    /// 删一个 profile：文件目录 + 钥匙串 account + index 条目
    /// 一起清；删的是激活的那张时，激活回落到剩下第一个，
    /// 一个不剩就清空激活（证书组回空状态）。
    static func removeProfile(_ profile: EnterpriseCertProfile) {
        try? FileManager.default.removeItem(at: profileDir(for: profile))
        keychainDelete(account: "password-\(profile.id.uuidString)")
        if memoryFallbackProfileID == profile.id {
            memoryFallback = nil
            memoryFallbackValid = false
            memoryFallbackProfileID = nil
        }
        let remaining = profiles().filter { $0.id != profile.id }
        saveProfiles(remaining)
        if activeProfileIDValue == profile.id {
            if let first = remaining.first {
                UserDefaults.standard.set(first.id.uuidString, forKey: activeProfileIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeProfileIDKey)
            }
        }
    }

    static func renameProfile(_ profile: EnterpriseCertProfile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var all = profiles()
        if let index = all.firstIndex(where: { $0.id == profile.id }) {
            all[index].name = trimmed
            saveProfiles(all)
        }
    }

    /// 只按给定的 p12 数据 + 密码解证书名，不碰 store 状态：
    /// 新 profile 导入时定默认名用（那时它还不是激活 profile）。
    /// identity() 那套的轻量版：只要名头，不要私钥 DER。
    static func certName(p12Data: Data, password: String) -> String? {
        var items: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        guard SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items) == errSecSuccess,
              let array = items as? [[String: Any]],
              let rawIdentity = array.first?[kSecImportItemIdentity as String] else { return nil }
        let identity = rawIdentity as! SecIdentity
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess, let cert = certRef else { return nil }
        let name = SecCertificateCopySubjectSummary(cert) as String?
        return (name?.isEmpty == false) ? name : nil
    }

    /// 指定路径的描述文件信息：激活 profile 的 provisionInfo
    /// 走这条（传 provisionURL），列表行里各 profile 的到期日
    /// 也走这条（传各 profile 自己的路径），不用切激活。
    static func provisionInfo(at url: URL) -> ProvisionInfo? {
        guard let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let endMark = data.range(of: Data("</plist>".utf8)) else { return nil }
        let xml = data[start.lowerBound..<endMark.upperBound]
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return ProvisionInfo(name: dict["Name"] as? String ?? "",
                             teamName: dict["TeamName"] as? String ?? "",
                             teamID: (dict["TeamIdentifier"] as? [String])?.first ?? "",
                             expiration: dict["ExpirationDate"] as? Date,
                             uuid: dict["UUID"] as? String ?? "",
                             provisionedDeviceCount: (dict["ProvisionedDevices"] as? [String])?.count ?? 0,
                             provisionedDevices: dict["ProvisionedDevices"] as? [String] ?? [])
    }

    /// 某 profile 的描述文件信息（列表行到期日用）。
    static func provisionInfo(for profile: EnterpriseCertProfile) -> ProvisionInfo? {
        provisionInfo(at: profileDir(for: profile).appendingPathComponent("profile.mobileprovision"))
    }

    /// 已导入描述文件的信息（名称/团队/到期），证书页展示用。
    struct ProvisionInfo {
        let name: String
        let teamName: String
        /// TeamIdentifier 数组的第一个（团队 ID，如 HP24Y7433B），没有就 ""。
        let teamID: String
        let expiration: Date?
        let uuid: String
        /// ProvisionedDevices 数组长度：企业描述文件通常没有这一项
        ///（0 = 不限设备）；开发/AdHoc 描述文件有，长度就是限定台数。
        /// ProvisionedDevices 数组本身：证书页拿它跟本机 UDID 比对，
        /// 断言本机在不在列表里（轻松签同款）；本机 UDID 用
        /// MobileGestalt 的 MGCopyAnswer 读（轻松签二进制实证同款
        /// 办法），读不到就回落到只提示台数，不假断言。
        let provisionedDeviceCount: Int
        let provisionedDevices: [String]
    }

    /// A-7：store 层解析缓存——certInfo / provisionInfo 是计算属性，
    /// 每次访问都重读重解析（certInfo 走 SecPKCS12Import，provisionInfo
    /// 全读描述文件 + 扫 XML + plist 全解析）。设置页一次 body 求值
    /// 里连调多次，证书页、签前校验等直读方也一样。缓存键：provisionInfo
    /// 用证书材料指纹，certInfo 用指纹 + 密码（密码变了只失效 certInfo）。
    /// 结果可为 nil——nil 也缓存，免得每次都重算失败路径。
    /// 调用方遍布主线程与 detached 任务，缓存读写同一把锁串行化
    /// （解析本身不回调这两个 getter，不会死锁）。
    private static let infoCacheLock = NSLock()
    private static var certInfoCache: (key: String, value: CertInfo?)?
    private static var provisionInfoCache: (key: String, value: ProvisionInfo?)?

    static var provisionInfo: ProvisionInfo? {
        let key = certStateFingerprint()
        infoCacheLock.lock()
        defer { infoCacheLock.unlock() }
        if let cached = provisionInfoCache, cached.key == key { return cached.value }
        let value = provisionInfo(at: provisionURL)
        provisionInfoCache = (key: key, value: value)
        return value
    }

    /// 证书材料指纹（A1+A2）：激活 p12 + 激活描述文件 + 各 profile 描述文件
    /// 的大小与修改时间；变了才重解析（见 EnterpriseCertView.refreshCertState）。
    static func certStateFingerprint() -> String {
        certStateFingerprint(profiles: profiles())
    }

    /// 同上，但用调用方已读好的列表，不再重读一次（见
    /// EnterpriseCertView.refreshCertState 的一次读三遍修法）。
    /// 指纹格式与无参版完全一致。
    static func certStateFingerprint(profiles: [EnterpriseCertProfile]) -> String {
        var urls = [p12URL, provisionURL]
        urls += profiles.map { profileDir(for: $0).appendingPathComponent("profile.mobileprovision") }
        return urls.map { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int,
                  let modified = attrs[.modificationDate] as? Date
            else { return "missing" }
            return "\(size)-\(modified.timeIntervalSince1970)"
        }.joined(separator: "|")
    }

    /// 删除已导入的证书材料（证书页的「移除证书」）：多证书
    /// 库下只清当前激活 profile（文件 + 密码 + index 条目），
    /// 激活自动回落到另一张；其余 profile 在证书库列表里各删
    /// 各的。没有 profile 时走老单证书路径（删顶层文件）。
    static func removeAll() {
        if let active = activeProfile() {
            removeProfile(active)
        } else {
            try? FileManager.default.removeItem(at: p12URL)
            try? FileManager.default.removeItem(at: provisionURL)
            password = ""
        }
    }

    /// 用 Security 框架解开 .p12，取出证书与私钥的 DER（私钥是
    /// RSA 的 PKCS#1 形式，Rust 侧会包成 PKCS#8 再解析）。
    static func identityDERs() throws -> (cert: Data, key: Data) {
        let data = try Data(contentsOf: p12URL)
        var items: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let first = array.first,
              let rawIdentity = first[kSecImportItemIdentity as String] else {
            throw EngineError.message(L("证书解不开——密码不对，或者 .p12 文件有问题。"))
        }
        let identity = rawIdentity as! SecIdentity
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess, let cert = certRef else {
            throw EngineError.message(L("证书读取失败。"))
        }
        var keyRef: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &keyRef) == errSecSuccess, let key = keyRef else {
            throw EngineError.message(L("证书里没有私钥——要带私钥的 .p12。"))
        }
        var cfError: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &cfError) as Data? else {
            throw EngineError.message(L("私钥读取失败。"))
        }
        return (SecCertificateCopyData(cert) as Data, keyData)
    }

    /// 本机直装的 TLS 服务用：直接拿 .p12 里现成的身份，
    /// 不经过 DER 来回倒（私钥是 RSA 还是 EC 都不用猜）。
    static func identity() throws -> SecIdentity {
        let data = try Data(contentsOf: p12URL)
        var items: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let array = items as? [[String: Any]],
              let first = array.first,
              let rawIdentity = first[kSecImportItemIdentity as String] else {
            throw EngineError.message(L("证书解不开——密码不对，或者 .p12 文件有问题。"))
        }
        return rawIdentity as! SecIdentity
    }

    /// 证书本身的信息（名头 + 到期日）：证书卡上要显示。解不开（比如
    /// 密码不对）就返回 nil，不拦着原来的显示；密码错到签名
    /// 那步还是会明说。
    /// 注意：证书到期日不要用 SecCertificateCopyValues 拿——
    /// 它和 kSecOIDX509V1ValidityNotAfter 是 macOS 才有的，
    /// iOS 上编不过（构建 #50 红字实证）。证书到期日改走 DER
    /// 解析：SecCertificateCopyData 取 DER 后由 X509Validity 读
    /// validity 的 NotAfter；解析失败只让 expiration 为 nil，不拦显示。
    struct CertInfo {
        let name: String
        let expiration: Date?
    }

    static var certInfo: CertInfo? {
        let key = certStateFingerprint() + "|" + password
        infoCacheLock.lock()
        defer { infoCacheLock.unlock() }
        if let cached = certInfoCache, cached.key == key { return cached.value }
        let value: CertInfo? = {
            guard let identity = try? identity() else { return nil }
            var certRef: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
                  let cert = certRef else { return nil }
            let name = SecCertificateCopySubjectSummary(cert) as String? ?? ""
            let expiration = X509Validity.notAfter(der: SecCertificateCopyData(cert) as Data)
            return CertInfo(name: name, expiration: expiration)
        }()
        certInfoCache = (key: key, value: value)
        return value
    }

    /// 描述文件里内嵌的开发证书 DER 列表（DeveloperCertificates）。
    /// 和 provisionInfo 同一套 plist 提取：描述文件是 CMS 套着
    /// plist，这里只取 plist 那段。读不出来返回 nil（不拦）。
    static var provisionDeveloperCertificates: [Data]? {
        guard let data = try? Data(contentsOf: provisionURL),
              let start = data.range(of: Data("<?xml".utf8)),
              let endMark = data.range(of: Data("</plist>".utf8)) else { return nil }
        let xml = data[start.lowerBound..<endMark.upperBound]
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict["DeveloperCertificates"] as? [Data]
    }

    /// p12 证书是否在描述文件内嵌证书列表里：true = 对得上，
    /// false = 对不上，nil = 查不出来（p12 解不开、描述文件里
    /// 没有内嵌证书列表时，不拦）。签名校验和导入时配对检查共用。
    static var certMatchesProvision: Bool? {
        guard let certDER = try? identityDERs().cert,
              let devCerts = provisionDeveloperCertificates,
              !devCerts.isEmpty else { return nil }
        return devCerts.contains(certDER)
    }

    /// 签名前校验（两条签名路共用：CertSigner 和 Engine 流水线）。
    /// 只拦板上钉钉的档——过期，和证书与描述文件对不上（
    /// 描述文件里根本没有这张证书，签出来的包装上去也装不上，
    /// 不如签之前就明说）。解析不出来的项不拦，免得误杀能签的。
    /// 证书对不上的判断走描述文件内嵌的证书列表：证书在列表里
    /// 就说明团队也是同一家，不用再单独比团队名。
    static func validateForSigning() throws {
        let now = Date()
        if let expiration = provisionInfo?.expiration, expiration < now {
            throw EngineError.message(L("描述文件已过期（%@），签出来的包装上去也是闪退，先换一张没过期的描述文件。",
                                        expiration.formatted(date: .abbreviated, time: .omitted)))
        }
        // p12 证书本身过期也要拦：以前只看描述文件，证书过期
        // 时一路签完、到安装/启动才暴露。解不开（密码不对）时
        // certInfo 为 nil，这里不拦，签名那步自会明说。
        if let expiration = certInfo?.expiration, expiration < now {
            throw EngineError.message(L("证书已过期（%@），签出来的包装上去也是闪退，先换一张没过期的证书。",
                                        expiration.formatted(date: .abbreviated, time: .omitted)))
        }
        // p12 解不开（比如密码不对）时这里不重复报错：后面签
        // 名那步的 identityDERs 会明说，校验直接跳过这一档。
        if certMatchesProvision == false {
            throw EngineError.message(L("描述文件里的证书和已导入的 .p12 对不上，签出来的包装上去也装不上，先换一张和这张证书配对的描述文件。"))
        }
    }
}

/// X.509 证书 DER 里 validity 的 NotAfter（证书本身到期日）。
/// 只做最小解析：Certificate → TBSCertificate → 跳过可选 version、
/// serial、signature、issuer → validity SEQUENCE 的第二个时间项。
/// 时间只认 UTCTime（0x17）与 GeneralizedTime（0x18）；任何一步
/// 对不上都返回 nil，不抛错、不拦显示。
private enum X509Validity {
    static func notAfter(der: Data) -> Date? {
        var outer = DERReader(data: der)
        guard let cert = outer.readTLV(), cert.tag == 0x30 else { return nil }
        var certBody = DERReader(data: cert.value)
        guard let tbs = certBody.readTLV(), tbs.tag == 0x30 else { return nil }
        var fields = DERReader(data: tbs.value)
        // version 是 [0] 显式构造标签（0xA0），有则跳过，没有直接就是 serial。
        if fields.peekTag() == 0xA0 { _ = fields.readTLV() }
        guard fields.readTLV() != nil,  // serialNumber
              fields.readTLV() != nil,  // signature
              fields.readTLV() != nil,  // issuer
              let validity = fields.readTLV(), validity.tag == 0x30 else { return nil }
        var times = DERReader(data: validity.value)
        guard times.readTLV() != nil,  // notBefore
              let notAfter = times.readTLV(),
              notAfter.tag == 0x17 || notAfter.tag == 0x18 else { return nil }
        return parseTime(tag: notAfter.tag, bytes: notAfter.value)
    }

    /// 最小 DER TLV 读取器：单字节 tag + 定长 length（DER 无不定长）。
    /// 注意：Data 切片保留原下标（startIndex 不归零），count 只是长度，
    /// 所以 `offset < count` 放行不等于 `data[offset]` 合法——0.9.75 真机
    /// 闪退就是这句在切片上炸的。所有下标一律以 base 为起点算。
    private struct DERReader {
        let data: Data
        let base: Data.Index
        var offset = 0

        init(data: Data) {
            self.data = data
            self.base = data.startIndex
        }

        func peekTag() -> UInt8? {
            offset < data.count ? data[base + offset] : nil
        }

        mutating func readTLV() -> (tag: UInt8, value: Data)? {
            guard offset < data.count else { return nil }
            let tag = data[base + offset]
            offset += 1
            guard offset < data.count else { return nil }
            let lengthByte = data[base + offset]
            offset += 1
            let length: Int
            if lengthByte & 0x80 == 0 {
                length = Int(lengthByte)
            } else {
                let count = Int(lengthByte & 0x7F)
                guard count > 0, count <= 4, offset + count <= data.count else { return nil }
                var len = 0
                for i in 0..<count { len = (len << 8) | Int(data[base + offset + i]) }
                offset += count
                length = len
            }
            guard offset + length <= data.count else { return nil }
            let value = data[(base + offset)..<(base + offset + length)]
            offset += length
            return (tag, value)
        }
    }

    /// UTCTime：YYMMDDHHMM[SS]Z；GeneralizedTime：YYYYMMDDHHMM[SS]Z；
    /// 时区也认 ±HHMM（换算回 UTC）。秒可省，缺省按 0 算。
    private static func parseTime(tag: UInt8, bytes: Data) -> Date? {
        guard var str = String(data: bytes, encoding: .ascii) else { return nil }
        var offsetSeconds = 0
        if str.hasSuffix("Z") {
            str.removeLast()
        } else if let range = str.range(of: "[+-]\\d{4}$", options: .regularExpression) {
            let sign = str[range].hasPrefix("+") ? 1 : -1
            let digits = str[range].dropFirst()
            let hh = Int(digits.prefix(2)) ?? 0
            let mm = Int(digits.suffix(2)) ?? 0
            offsetSeconds = sign * (hh * 3600 + mm * 60)
            str = String(str[..<range.lowerBound])
        } else {
            return nil
        }
        if let dot = str.firstIndex(of: ".") { str = String(str[..<dot]) }
        let digits = Array(str)
        guard digits.allSatisfy({ $0.isNumber }) else { return nil }
        let year: Int
        let rest: [Character]
        if tag == 0x17 {
            guard digits.count == 12 || digits.count == 10 else { return nil }
            let yy = Int(String(digits[0..<2])) ?? 0
            year = yy < 50 ? 2000 + yy : 1900 + yy
            rest = Array(digits[2...])
        } else {
            guard digits.count == 14 || digits.count == 12 else { return nil }
            year = Int(String(digits[0..<4])) ?? 0
            rest = Array(digits[4...])
        }
        guard rest.count == 10 || rest.count == 8 else { return nil }
        let month = Int(String(rest[0..<2])) ?? 0
        let day = Int(String(rest[2..<4])) ?? 0
        let hour = Int(String(rest[4..<6])) ?? 0
        let minute = Int(String(rest[6..<8])) ?? 0
        let second = rest.count == 10 ? (Int(String(rest[8..<10])) ?? 0) : 0
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = Calendar(identifier: .gregorian).date(from: components) else { return nil }
        return date.addingTimeInterval(TimeInterval(-offsetSeconds))
    }
}

// MARK: - 吊销状态与脱壳检查（轻松签对齐，警告不拦截）

/// 吊销检查结果：unknown = 查不出来（离线、链不全、评估失败），
/// 一律不报警告；ok = 评估通过；revoked = 系统评估明确拒绝。
enum CertRevocationStatus {
    case unknown
    case ok
    case revoked

    /// A-6：缓存往返名（UserDefaults 只存普通字符串）。
    var cacheName: String {
        switch self {
        case .unknown: return "unknown"
        case .ok: return "ok"
        case .revoked: return "revoked"
        }
    }

    init?(name: String) {
        switch name {
        case "unknown": self = .unknown
        case "ok": self = .ok
        case "revoked": self = .revoked
        default: return nil
        }
    }
}

/// 吊销检查：用系统信任评估给已导入的企业证书验一遍，评估
/// 时允许联网（OCSP 在线查）。只有评估失败且结果是 Deny 才
/// 算掉签——其他失败（离线、链不全、策略原因）都算查不出来，
/// 绝不报假警告。调用方必须在后台线程调（评估可能联网）。
/// 注意：这组 SecTrust API 是本文件新写的，仓库里没有现成
/// 用例，CI 是最终 verdict。
enum CertRevocationChecker {
    /// A-6：吊销检查结果缓存（UserDefaults，不存证书本身）。
    /// key = 证书状态指纹；24 小时内同一指纹直接返回缓存状态，
    /// 不读 p12、不做信任评估（不联网 OCSP）。证书换了指纹就变，
    /// 缓存自动失效；`.unknown` 也缓存，免得查不出来的证书每进页
    /// 都重试；手动按钮走 force 路，每次都真查。
    private static let cacheKey = "CZFCertRevocationCache"
    private static let cacheLifetime: TimeInterval = 24 * 3600

    static func check(force: Bool = false) -> CertRevocationStatus {
        let fingerprint = EnterpriseCertStore.certStateFingerprint()
        if !force, let cached = cachedStatus(), cached.fingerprint == fingerprint,
           Date().timeIntervalSince(cached.checkedAt) < cacheLifetime {
            return cached.status
        }
        let status = evaluate()
        saveCache(fingerprint: fingerprint, status: status, checkedAt: Date())
        return status
    }

    /// The cached check: fingerprint, status, and check time.
    private struct CachedStatus {
        let fingerprint: String
        let status: CertRevocationStatus
        let checkedAt: Date
    }

    private static func cachedStatus() -> CachedStatus? {
        guard let dict = UserDefaults.standard.dictionary(forKey: cacheKey),
              let fingerprint = dict["fingerprint"] as? String,
              let statusName = dict["status"] as? String,
              let status = CertRevocationStatus(name: statusName),
              let checkedAt = dict["checkedAt"] as? TimeInterval
        else { return nil }
        return CachedStatus(fingerprint: fingerprint, status: status,
                            checkedAt: Date(timeIntervalSince1970: checkedAt))
    }

    private static func saveCache(fingerprint: String, status: CertRevocationStatus, checkedAt: Date) {
        UserDefaults.standard.set([
            "fingerprint": fingerprint,
            "status": status.cacheName,
            "checkedAt": checkedAt.timeIntervalSince1970,
        ], forKey: cacheKey)
    }

    /// The real check, without the cache (old `check()` body, renamed).
    private static func evaluate() -> CertRevocationStatus {
        guard let trust = currentTrust() else { return .unknown }
        SecTrustSetNetworkFetchAllowed(trust, true)
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) { return .ok }
        var result = SecTrustResultType.invalid
        guard SecTrustGetTrustResult(trust, &result) == errSecSuccess else { return .unknown }
        return result == .deny ? .revoked : .unknown
    }

    /// p12 导入时系统顺手建好的信任对象优先（链最全）；没有
    /// 就用证书本身加基础 X.509 策略现建一个。
    private static func currentTrust() -> SecTrust? {
        let data = try? Data(contentsOf: EnterpriseCertStore.p12URL)
        var items: CFArray?
        let options: [String: Any] = [kSecImportExportPassphrase as String: EnterpriseCertStore.password]
        if let data,
           SecPKCS12Import(data as CFData, options as CFDictionary, &items) == errSecSuccess,
           let array = items as? [[String: Any]],
           let rawTrust = array.first?[kSecImportItemTrust as String] as? AnyObject,
           CFGetTypeID(rawTrust) == SecTrustGetTypeID() {
            // 这里不能写 as? SecTrust：编译器认定对 CoreFoundation
            // 类型的条件转换恒成功而直接报错；先验 typeID 再硬转。
            return unsafeBitCast(rawTrust, to: SecTrust.self)
        }
        guard let identity = try? EnterpriseCertStore.identity() else { return nil }
        var certRef: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certRef) == errSecSuccess,
              let cert = certRef else { return nil }
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        guard SecTrustCreateWithCertificates(cert, policy, &trust) == errSecSuccess else { return nil }
        return trust
    }
}

/// 脱壳检查：解包读各 .app 的 Mach-O 加密命令，cryptid 非 0
/// 说明还是加密的（没脱壳），签完可能装不上。undumpedApps
/// 遍历全部 .app（见 SS2），不再只取第一个。nil = 查不出来
/// （不警告）；调用方在后台线程调：大包解压到临时目录要几
/// 秒，查完即删。
enum IPADecryptionCheck {
    /// 未脱壳的 .app 目录名（见 SS2）：遍历 Payload 里全部
    /// .app 逐个查，不再只取第一个——contentsOfDirectory 顺
    /// 序未定义，单 .app 时取第一个碰巧对，多 .app 时可能查
    /// 错对象。nil = 整包解不开/读不到（不警告，与旧语义一致）；
    /// 空数组 = 全部已脱壳；非空 = 逐个报未脱壳的 app 名。
    /// 单个 .app 读不出来时跳过它、不警告（旧语义里单个读不
    /// 出也是 nil，即不警告）。
    static func undumpedApps(of ipaURL: URL) -> [String]? {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
            .appendingPathComponent("EnterpriseCryptCheck-\(UUID().uuidString)", isDirectory: true)
        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        } catch { return nil }
        defer { try? fm.removeItem(at: tmp) }
        guard FileZipTool.unzip(archive: ipaURL, to: tmp) == nil else { return nil }
        guard let payload = try? fm.contentsOfDirectory(at: tmp.appendingPathComponent("Payload"), includingPropertiesForKeys: nil) else { return nil }
        let appDirs = payload.filter { $0.pathExtension == "app" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !appDirs.isEmpty else { return nil }
        var undumped: [String] = []
        for appDir in appDirs {
            if let cryptid = cryptid(ofAppDir: appDir), cryptid != 0 {
                undumped.append(appDir.lastPathComponent)
            }
        }
        return undumped
    }

    /// Fast path for `undumpedApps(of:)`: reads only each executable's file
    /// head out of the zip (prefix inflate, no full extraction). Returns nil
    /// when the zip can't be read this way — the caller falls back to the
    /// slow path. A non-nil result means the same as the slow path's
    /// (nil = unreadable, empty = all dumped, names = still encrypted).
    static func undumpedAppsFast(of ipaURL: URL) -> [String]? {
        guard let entries = IPALibrary.appExecutableEntries(inIPA: ipaURL) else { return nil }
        var undumped: [String] = []
        for (appName, exePath) in entries {
            guard let cryptid = cryptidFast(of: exePath, inIPA: ipaURL) else { return nil }
            if cryptid != 0 { undumped.append(appName) }
        }
        return undumped
    }

    /// cryptid for one executable, from a memory prefix: 4KB first to find
    /// the arm64 slice, then up to sliceOffset + 1MB (thin binaries: 1MB).
    /// nil = couldn't read or parse (same as the file-based path's nil).
    /// The prefix target is capped: a fat binary whose arm64 slice sits
    /// past 128MB falls back to the slow path instead of inflating that
    /// much into memory.
    private static func cryptidFast(of exePath: String, inIPA ipaURL: URL) -> Int? {
        guard let head = IPALibrary.executablePrefixData(inIPA: ipaURL, entryName: exePath, byteCount: 4096),
              head.count >= 4 else { return nil }
        let magic = head[0..<4]
        var target = 1 << 20
        if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBE]) {
            // 胖二进制：大端序，找 arm64 切片的偏移。
            guard head.count >= 8 else { return nil }
            let narch = Int(u32be(head, 4))
            var offset = 8
            var sliceOffset: Int?
            for _ in 0..<narch {
                guard head.count >= offset + 20 else { return nil }
                if u32be(head, offset) == 0x0100_000C {
                    sliceOffset = Int(u32be(head, offset + 8))
                    break
                }
                offset += 20
            }
            guard let sliceOffset else { return nil }
            target = sliceOffset + (1 << 20)
        } else if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBF]) {
            // 64 位胖二进制：每项 32 字节，offset 是 8 字节大端值，
            // 低 32 位在 +12 处（IPA 不到 4GB，低 32 位够用）。
            guard head.count >= 8 else { return nil }
            let narch = Int(u32be(head, 4))
            var offset = 8
            var sliceOffset: Int?
            for _ in 0..<narch {
                guard head.count >= offset + 32 else { return nil }
                if u32be(head, offset) == 0x0100_000C {
                    sliceOffset = Int(u32be(head, offset + 12))
                    break
                }
                offset += 32
            }
            guard let sliceOffset else { return nil }
            target = sliceOffset + (1 << 20)
        }
        guard target <= 128 << 20 else { return nil }
        guard let prefix = IPALibrary.executablePrefixData(inIPA: ipaURL, entryName: exePath, byteCount: target) else { return nil }
        return parseCryptidFromPrefix(prefix)
    }

    /// cryptid from an in-memory executable prefix: the fat header's arm64
    /// slice is cut out of the same prefix (no file re-open). Mirrors
    /// `parseCryptid`, but the slice comes from `prefix`, not a seek.
    private static func parseCryptidFromPrefix(_ prefix: Data) -> Int? {
        guard prefix.count >= 4 else { return nil }
        let magic = prefix[0..<4]
        if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBE]) {
            guard prefix.count >= 8 else { return nil }
            let narch = Int(u32be(prefix, 4))
            var offset = 8
            for _ in 0..<narch {
                guard prefix.count >= offset + 20 else { return nil }
                let cputype = u32be(prefix, offset)
                let sliceOffset = Int(u32be(prefix, offset + 8))
                if cputype == 0x0100_000C {
                    guard prefix.count >= sliceOffset + 32 else { return nil }
                    return thinCryptid(Data(prefix[sliceOffset...]))
                }
                offset += 20
            }
            return nil
        }
        if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBF]) {
            guard prefix.count >= 8 else { return nil }
            let narch = Int(u32be(prefix, 4))
            var offset = 8
            for _ in 0..<narch {
                guard prefix.count >= offset + 32 else { return nil }
                let cputype = u32be(prefix, offset)
                let sliceOffset = Int(u32be(prefix, offset + 12))
                if cputype == 0x0100_000C {
                    guard prefix.count >= sliceOffset + 32 else { return nil }
                    return thinCryptid(Data(prefix[sliceOffset...]))
                }
                offset += 32
            }
            return nil
        }
        return thinCryptid(prefix)
    }

    private static func cryptid(ofAppDir appDir: URL) -> Int? {
        let executableName: String
        if let plistData = try? Data(contentsOf: appDir.appendingPathComponent("Info.plist")),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
           let dict = plist as? [String: Any],
           let exe = dict["CFBundleExecutable"] as? String, !exe.isEmpty {
            executableName = exe
        } else {
            executableName = appDir.deletingPathExtension().lastPathComponent
        }
        let exeURL = appDir.appendingPathComponent(executableName)
        guard let header = readHeader(of: exeURL) else { return nil }
        return parseCryptid(header, exeURL: exeURL)
    }

    /// 先读文件头（胖二进制的头 + 架构表，4KB 够放几百项），
    /// 再按需到切片偏移处读 1MB（load commands 都在文件头附近）。
    /// 读法用 OTA 已在用的 readData(ofLength:)（不抛错、无版本疑问）。
    private static func readHeader(of url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return handle.readData(ofLength: 4096)
    }

    private static func parseCryptid(_ head: Data, exeURL: URL) -> Int? {
        guard head.count >= 4 else { return nil }
        let magic = head[0..<4]
        if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBE]) {
            // 胖二进制：大端序，找 arm64 切片再读它的头。
            guard head.count >= 8 else { return nil }
            let narch = Int(u32be(head, 4))
            var offset = 8
            for _ in 0..<narch {
                guard head.count >= offset + 20 else { return nil }
                let cputype = u32be(head, offset)
                let sliceOffset = Int(u32be(head, offset + 8))
                // cputype arm64 = 0x0100000C
                if cputype == 0x0100_000C {
                    guard let handle = try? FileHandle(forReadingFrom: exeURL) else { return nil }
                    defer { try? handle.close() }
                    guard (try? handle.seek(toOffset: UInt64(sliceOffset))) != nil else { return nil }
                    return thinCryptid(handle.readData(ofLength: 1 << 20))
                }
                offset += 20
            }
            return nil
        }
        if magic.elementsEqual([0xCA, 0xFE, 0xBA, 0xBF]) {
            // 64 位胖二进制：每项 32 字节，offset 是 8 字节大端值，
            // 低 32 位在 +12 处（IPA 不到 4GB，低 32 位够用）。
            guard head.count >= 8 else { return nil }
            let narch = Int(u32be(head, 4))
            var offset = 8
            for _ in 0..<narch {
                guard head.count >= offset + 32 else { return nil }
                let cputype = u32be(head, offset)
                let sliceOffset = Int(u32be(head, offset + 12))
                if cputype == 0x0100_000C {
                    guard let handle = try? FileHandle(forReadingFrom: exeURL) else { return nil }
                    defer { try? handle.close() }
                    guard (try? handle.seek(toOffset: UInt64(sliceOffset))) != nil else { return nil }
                    return thinCryptid(handle.readData(ofLength: 1 << 20))
                }
                offset += 32
            }
            return nil
        }
        // 瘦二进制：整个文件头就是 Mach-O 头，1MB 够走 load commands。
        guard let handle = try? FileHandle(forReadingFrom: exeURL) else { return nil }
        defer { try? handle.close() }
        return thinCryptid(handle.readData(ofLength: 1 << 20))
    }

    /// 瘦 Mach-O 里走 load commands 找 LC_ENCRYPTION_INFO(_64)。
    /// 没有加密命令 = 已脱壳（或本来就没加密），返回 0。
    private static func thinCryptid(_ data: Data) -> Int? {
        guard data.count >= 32 else { return nil }
        let magic = data[0..<4]
        let is64 = magic.elementsEqual([0xCF, 0xFA, 0xED, 0xFE])
        let is32 = magic.elementsEqual([0xCE, 0xFA, 0xED, 0xFE])
        guard is64 || is32 else { return nil }
        let ncmds = Int(u32le(data, 16))
        var cursor = is64 ? 32 : 28
        for _ in 0..<ncmds {
            guard data.count >= cursor + 8 else { return nil }
            let cmd = u32le(data, cursor)
            let cmdsize = Int(u32le(data, cursor + 4))
            guard cmdsize >= 8, data.count >= cursor + cmdsize else { return nil }
            if cmd == 0x2C, data.count >= cursor + 24 {
                // LC_ENCRYPTION_INFO_64：cryptid 在命令 +20 处。
                return Int(u32le(data, cursor + 20))
            }
            if cmd == 0x21, data.count >= cursor + 20 {
                // LC_ENCRYPTION_INFO：cryptid 在命令 +16 处。
                return Int(u32le(data, cursor + 16))
            }
            cursor += cmdsize
        }
        return 0
    }

    /// 手动拼字节，不用 load(as:)——切片偏移不一定 4 字节对齐。
    private static func u32le(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func u32be(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }
}

// MARK: - 签名前修改项

/// 证书页的签名前修改项：留空的项不改。对应 Rust 侧 SignMods 的
/// JSON 字段（name/bundleId/version/minOS/iconPng/outIpa）。
struct CertSignMods {
    var name = ""
    var bundleID = ""
    var version = ""
    var minOS = ""
    /// 自定义输出主名（表单“打包文件名”可编辑项，空着回落源文件名；
    /// 不进预设，换 IPA 时随 mods 一起清空）。
    var outputName = ""
    /// 新图标的数据（选了才有）。挑图处存的是相册原图字节，不保证
    /// 是 PNG；签名写盘前由 `pngIconData()` 转真 PNG（C24）。
    var icon: Data? = nil

    /// 签名用的图标字节：真 PNG。Rust `apply_icon` 把给定字节原样
    /// 覆盖到各 `*.png` 图标文件上，不解码不校验，所以 JPEG/HEIC
    /// 原字节会装出坏图标；这里先解码再 `pngData()` 转码，解码失败
    /// 回落原字节——行为不比现况差（C24）。
    func pngIconData() -> Data? {
        guard let icon else { return nil }
        return UIImage(data: icon)?.pngData() ?? icon
    }
    /// 要注入的插件文件（已复制到暂存目录的 .dylib/.deb/.zip）。
    var plugins: [URL] = []
    /// 瘦身与兼容（签名段“更多设置”里的三个开关，默认全关）：
    /// stripWatch 删 Payload/*.app/Watch，stripExtensions 删
    /// PlugIns，stripDeviceLimits 删主 Info.plist 里的设备限制键。
    /// 只在签名时先生效（见 CertSigner.preSignRepack），不进预设。
    var stripWatch = false
    var stripExtensions = false
    var stripDeviceLimits = false

    /// 有任一瘦身/兼容开关开着才需要先改包再签。
    var needsPreSignRepack: Bool { stripWatch || stripExtensions || stripDeviceLimits }

    var isEmpty: Bool {
        name.isEmpty && bundleID.isEmpty && version.isEmpty && minOS.isEmpty && outputName.isEmpty && icon == nil && plugins.isEmpty
            && !stripWatch && !stripExtensions && !stripDeviceLimits
    }

    func json(iconPath: String?, outIpaPath: String?) -> String {
        var dict: [String: Any] = [:]
        if !name.isEmpty { dict["name"] = name }
        if !bundleID.isEmpty { dict["bundleId"] = bundleID }
        if !version.isEmpty { dict["version"] = version }
        if !minOS.isEmpty { dict["minOS"] = minOS }
        if let iconPath { dict["iconPng"] = iconPath }
        if let outIpaPath { dict["outIpa"] = outIpaPath }
        if !plugins.isEmpty { dict["plugins"] = plugins.map { $0.path } }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}

/// 插件暂存：从文件 App 选来的插件先复制到 Documents/CertPlugins，
/// 签名时 Rust 侧按路径读（原文件可能在沙盒外、随时会被收回）。
enum CertPluginStore {
    static var dir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CertPlugins", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
    }

    /// Copy a picked plugin into the staging folder; returns the
    /// staged URL, or nil when the file type is not supported.
    static func stage(_ source: URL) -> URL? {
        let ext = source.pathExtension.lowercased()
        guard ["dylib", "deb", "zip"].contains(ext) else { return nil }
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        var dest = dir.appendingPathComponent(source.lastPathComponent)
        var counter = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            let stem = source.deletingPathExtension().lastPathComponent
            dest = dir.appendingPathComponent("\(stem) \(counter).\(ext)")
            counter += 1
        }
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 已签名 IPA

/// 一条「已签名」记录，清单存 Application Support，IPA 文件存
/// Documents/Signed（文件页和文件 App 都能看到）。
struct SignedIPARecord: Codable, Identifiable {
    var fileName: String
    var appName: String
    var bundleID: String
    var version: String?
    var date: Date
    var size: Int
    /// 签名时用的证书名（如 iPhone Distribution: hu jing）。
    /// 可选：老记录没有这两个字段，解码得 nil，已签名行就不显示第三行。
    var certName: String?
    /// 描述文件里的 TeamIdentifier（如 HP24Y7433B），没有就 nil。
    var teamID: String?
    var id: String { fileName }
}

enum SignedIPAStore {
    static var dir: URL {
        let url = IPALibrary.documentsDir.appendingPathComponent("Signed", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private static var manifestURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("SignedIPA-manifest.json")
    }

    static func url(for record: SignedIPARecord) -> URL {
        dir.appendingPathComponent(record.fileName)
    }

    /// A-8（SIDE-36）：清单缓存——load() 原来每次都读盘 + 解码 +
    /// 逐条 fileExists，文件页 / 证书页 / 续签循环各路都调；
    /// 现在只在首次（或写失败后）读盘，其余走内存。缓存只钉
    /// 私有 save()（本 Store 的唯一写入口：add / remove /
    /// fillMissingCertInfo / renameFile 全经它），写回成功才更新
    /// 缓存，写失败清缓存、下次重读盘，不拿内存冒充磁盘。
    private static let cacheLock = NSLock()
    private static var cachedRecords: [SignedIPARecord]?

    static func load() -> [SignedIPARecord] {
        let records: [SignedIPARecord] = {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let cached = cachedRecords { return cached }
            let loaded = loadRaw()
            cachedRecords = loaded
            return loaded
        }()
        return records
            .filter { FileManager.default.fileExists(atPath: url(for: $0).path) }
            .sorted { $0.date > $1.date }
    }

    /// 未过滤的原单：保存的底本 + load() 首次读盘的来源（A-8 缓存）。
    /// load() 按文件存在过滤，拿它当保存底本会把“移出 Signed 目录”
    /// 的记录永久抹掉（文件移回来也找不回）；显示层继续用 load()，
    /// 移走的文件本来就不该显示，但记录要留着等人移回来。
    static func loadRaw() -> [SignedIPARecord] {
        guard let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([SignedIPARecord].self, from: data)
        else { return [] }
        return records.sorted { $0.date > $1.date }
    }

    private static func save(_ records: [SignedIPARecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: manifestURL, options: .atomic)
            cacheLock.lock()
            defer { cacheLock.unlock() }
            cachedRecords = records
        } catch {
            // 写失败：清缓存，下次 load() 重读盘，不拿内存冒充磁盘。
            cacheLock.lock()
            defer { cacheLock.unlock() }
            cachedRecords = nil
        }
    }

    static func add(_ record: SignedIPARecord) {
        // 同文件名只留一条（id 就是 fileName）：并发签出同名时
        // 不再出现两个同 id 记录，删的时候也不会误删一对。
        save([record] + loadRaw().filter { $0.fileName != record.fileName })
    }

    static func remove(_ record: SignedIPARecord) {
        try? FileManager.default.removeItem(at: url(for: record))
        save(loadRaw().filter { $0.fileName != record.fileName })
    }

    /// B-38-B3：只删记录、不碰磁盘文件——WebDAV PUT 覆盖 Signed/ 下的
    /// 已签 IPA 后，旧记录描述的是被覆盖掉的旧包；remove(record) 会
    /// 连刚传上来的新文件一起删掉，绝不能用在这里。
    /// 经私有 save() 走，A-8 缓存同步更新。
    static func forget(_ record: SignedIPARecord) {
        save(loadRaw().filter { $0.fileName != record.fileName })
    }

    /// 批量删除：一次读清单、一次写回，不按条循环调 remove。
    static func remove(_ records: [SignedIPARecord]) {
        let names = Set(records.map { $0.fileName })
        for record in records {
            try? FileManager.default.removeItem(at: url(for: record))
        }
        save(loadRaw().filter { !names.contains($0.fileName) })
    }

    /// 老记录证书段补齐：v61 之前签的记录没存 certName/teamID，
    /// A-5：补团队号失败过的文件键集（内存，不落盘）。解失败的记录
    /// （团队与当前证书不符最常见）永远补不上，记下来免得每次进
    /// 文件页都重解；键 = 文件指纹 + 当前团队——换证书后键变了自动
    /// 重算，不会把旧证书下的“不符”带到新证书上；文件换了指纹变，
    /// 旧键自然失效。fillMissingCertInfo 跑在 Task.detached 里，
    /// .task 重入可能并发，读写同一把锁。
    private static let provisionTeamTriedLock = NSLock()
    private static var provisionTeamTried: Set<String> = []

    /// 行里不显示证书段。逐条读已签 IPA 里的 embedded.mobileprovision
    ///（CMS 包着 plist，照 BuiltinTunnel 的 latin1 截 XML 办法），
    ///取 TeamIdentifier；团队与当前描述文件一致时才用当前证书名
    ///补 certName（同团队才敢认是同一张证，团队不同就不猜）。
    ///已补过的记录不再重读；读不到/解不出就跳过，不报错。
    ///返回 true 表示改过清单（调用方重读一次）。
    ///注意：读描述文件只解 central directory 里一条目（A-5），
    ///不再全量解压；补不上的记 tried 集，进页不再重读。
    ///调用方须在后台跑。
    static func fillMissingCertInfo() -> Bool {
        guard let currentTeam = EnterpriseCertStore.provisionInfo?.teamID,
              !currentTeam.isEmpty,
              let currentName = EnterpriseCertStore.certInfo?.name,
              !currentName.isEmpty else { return false }
        var records = loadRaw()
        var changed = false
        for index in records.indices {
            let old = records[index]
            guard old.certName == nil || old.teamID == nil else { continue }
            // 已有团队号且与当前团队不同：这条记录对应的文件后来
            // 换证重签过（或记录本身就是旧证的），不拿当前证书名
            // 去盖它。
            if let storedTeam = old.teamID, storedTeam != currentTeam { continue }
            let ipaURL = url(for: old)
            // A-5：上次补不上（解不出、或团队与当前证书不符）的文件
            // 不再重解。
            let triedKey = IPALibrary.fileFingerprint(of: ipaURL).map { "\($0)|\(currentTeam)" }
            if let triedKey {
                provisionTeamTriedLock.lock()
                let tried = provisionTeamTried.contains(triedKey)
                provisionTeamTriedLock.unlock()
                if tried { continue }
            }
            guard let team = provisionTeamID(of: ipaURL), team == currentTeam else {
                if let triedKey {
                    provisionTeamTriedLock.lock()
                    provisionTeamTried.insert(triedKey)
                    provisionTeamTriedLock.unlock()
                }
                continue
            }
            if records[index].certName == nil { records[index].certName = currentName }
            if records[index].teamID == nil { records[index].teamID = team }
            changed = true
        }
        if changed { save(records) }
        return changed
    }

    /// 已签 IPA 里的描述文件团队号：只读 `Payload/*.app/embedded.mobileprovision`
    /// 这一条目，不解压整个 IPA。解不出就 nil（调用方跳过，不报错）。
    private static func provisionTeamID(of ipaURL: URL) -> String? {
        guard let data = IPALibrary.embeddedProvisionData(inIPA: ipaURL),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", options: .backwards) else {
            return nil
        }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                  from: xmlData, options: [], format: nil) as? [String: Any],
              let teams = plist["TeamIdentifier"] as? [String],
              let team = teams.first, !team.isEmpty else {
            return nil
        }
        return team
    }

    /// 文件页改名后同步清单里的文件名。
    static func renameFile(from oldName: String, to newName: String) {
        var records = loadRaw()
        for index in records.indices where records[index].fileName == oldName {
            records[index].fileName = newName
        }
        save(records)
    }

    /// 去掉主名末尾已带的“-已签”后缀（可重复，如二次签已签好的包）：
    /// uniqueOutputURL 还会再加一次“-已签”，不去重就会出
    /// “X-已签-已签.ipa”。去完变空就返回原名，不造空文件名。
    static func stripSignedSuffix(_ stem: String) -> String {
        var result = stem
        while result.hasSuffix("-已签") {
            result = String(result.dropLast("-已签".count))
        }
        return result.isEmpty ? stem : result
    }

    /// 给源 IPA 起一个不重名的输出文件（Documents/Signed 内）。
    static func uniqueOutputURL(baseName: String) -> URL {
        let stem = baseName.isEmpty ? "App" : baseName
        var candidate = dir.appendingPathComponent("\(stem)-已签.ipa")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(stem)-已签\(counter).ipa")
            counter += 1
        }
        return candidate
    }
}

// MARK: - 签名日志

/// 签名操作种类（存码，显示时再翻成文案）。
enum CertSignLogKind: String, Codable {
    case signOnly
    case signAndInstall
    case batch
    case installOnly
}

/// 一条签名记录：只记结果，不记证书密码等敏感信息。
struct CertSignLogEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var appName: String
    var kind: CertSignLogKind
    var success: Bool
    /// 成功是结果说明，失败是报错原文。
    var detail: String
}

/// 签名日志清单：存 Application Support，最新在前，最多留 100 条。
enum CertSignLogStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("CertSignLog.json")
    }

    static func load() -> [CertSignLogEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([CertSignLogEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.date > $1.date }
    }

    private static func save(_ entries: [CertSignLogEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    static func append(_ entry: CertSignLogEntry) {
        var entries = load()
        entries.insert(entry, at: 0)
        if entries.count > 100 { entries = Array(entries.prefix(100)) }
        save(entries)
    }

    static func clear() { save([]) }
}

// MARK: - 续签源

/// 一次续签用过的 IPA：删文件时要提示“这是某 App 续签用的文件”，
/// 凭包名 + 文件路径认。只记“哪次续签用了哪个文件”，不记证书密码等
/// 敏感信息；重签同一 App 会覆盖旧一条，最多留 100 条。
struct RenewalSourceEntry: Codable, Identifiable {
    var id: UUID
    var date: Date
    var bundleID: String
    var appName: String
    /// 续签当时用的 IPA 在 Documents 里的路径。
    var ipaPath: String
    var ipaName: String
}

/// 续签源清单：存 Application Support，最新在前，最多留 100 条。
enum RenewalSourceStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("RenewalSources.json")
    }

    static func load() -> [RenewalSourceEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([RenewalSourceEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.date > $1.date }
    }

    private static func save(_ entries: [RenewalSourceEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// 记一次成功的续签：同一包名只留最新一条。
    static func record(bundleID: String, appName: String, ipaURL: URL) {
        var entries = load().filter { $0.bundleID != bundleID }
        entries.insert(RenewalSourceEntry(id: UUID(), date: Date(), bundleID: bundleID,
                                          appName: appName, ipaPath: ipaURL.path,
                                          ipaName: ipaURL.lastPathComponent), at: 0)
        if entries.count > 100 { entries = Array(entries.prefix(100)) }
        save(entries)
    }

    /// 这个文件是不是某 App 续签用的源：路径对上，或包名对上（改名/移
    /// 过文件夹后路径变了，包名还能认出来），都算。
    static func source(forFileURL url: URL, bundleID: String?) -> RenewalSourceEntry? {
        let entries = load()
        if let hit = entries.first(where: { $0.ipaPath == url.path }) { return hit }
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return entries.first { $0.bundleID == bundleID }
    }
}

// MARK: - 签名预设

/// 一条签名预设：只存跨 App 通用的项。名字/Bundle ID/版本是
/// 每 App 自己的，不进预设；插件文件另存预设目录（套用时
/// 重新暂存一份，换 IPA 清暂存时不伤预设原件）。
struct CertSignPreset: Codable, Identifiable {
    var id: UUID
    var name: String
    var minOS: String
    var multiCount: Int
    var multiStart: Int
    var icon: Data?
    var pluginFileNames: [String]
}

/// 签名预设：索引存 Application Support，插件文件存同目录下
/// 每预设一个子目录（同名插件互不干扰）。
enum CertSignPresetStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CertSignPresets", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static var indexURL: URL { dir.appendingPathComponent("presets.json") }

    static func load() -> [CertSignPreset] {
        guard let data = try? Data(contentsOf: indexURL),
              let presets = try? JSONDecoder().decode([CertSignPreset].self, from: data)
        else { return [] }
        return presets.sorted { $0.name < $1.name }
    }

    private static func save(_ presets: [CertSignPreset]) {
        if let data = try? JSONEncoder().encode(presets) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private static func pluginDir(for id: UUID) -> URL {
        let url = dir.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 预设的插件文件（只返回还存在的，删过的不算）。
    static func pluginURLs(for preset: CertSignPreset) -> [URL] {
        let d = pluginDir(for: preset.id)
        return preset.pluginFileNames.map { d.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// 保存当前可复用项为预设；同名预设直接覆盖（旧目录一起删）。
    /// 插件拷失败的跳过，不记入；索引写失败也不抛，调用方照常报保存。
    static func save(name: String, minOS: String, multiCount: Int, multiStart: Int,
                     icon: Data?, pluginURLs: [URL]) -> CertSignPreset {
        var presets = load()
        if let old = presets.first(where: { $0.name == name }) {
            try? FileManager.default.removeItem(at: pluginDir(for: old.id))
            presets.removeAll { $0.id == old.id }
        }
        let preset = CertSignPreset(id: UUID(), name: name, minOS: minOS,
                                    multiCount: multiCount, multiStart: multiStart,
                                    icon: icon, pluginFileNames: [])
        let pdir = pluginDir(for: preset.id)
        var names: [String] = []
        for url in pluginURLs {
            let dest = pdir.appendingPathComponent(url.lastPathComponent)
            if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                names.append(url.lastPathComponent)
            }
        }
        var seen = Set<String>()
        var final = preset
        final.pluginFileNames = names.filter { seen.insert($0).inserted }
        presets.append(final)
        save(presets)
        return final
    }

    static func remove(_ preset: CertSignPreset) {
        try? FileManager.default.removeItem(at: pluginDir(for: preset.id))
        save(load().filter { $0.id != preset.id })
    }
}

// MARK: - 独立签名器（只签名不安装，不走 Engine 流水线）

enum CertSigner {
    /// 输出主名：表单“打包文件名”可编辑项，空着回落源文件名；
    /// 只取主名，去掉顺手带的 .ipa 后缀与路径分隔符；重名仍走
    /// uniqueOutputURL 的序号。单签、批量、多开副本都走这里。
    private static func outputBaseName(mods: CertSignMods, ipa: URL) -> String {
        var raw = mods.outputName.trimmingCharacters(in: .whitespaces)
        if raw.lowercased().hasSuffix(".ipa") { raw = String(raw.dropLast(4)) }
        raw = raw.replacingOccurrences(of: "/", with: "")
        raw = raw.replacingOccurrences(of: "?", with: "")
        if raw.isEmpty { raw = ipa.deletingPathExtension().lastPathComponent }
        // 手填名已带“-已签”也先去掉，uniqueOutputURL 只加一次。
        return SignedIPAStore.stripSignedSuffix(raw)
    }

    /// 签前改包（瘦身/兼容开关开着才跑）：把 IPA 解到 tmp、按开关
    /// 改完、只把 Payload 重新压成一个新 IPA 给签名器；原文件不动。
    /// 改动只删东西、不改签名流程本身：删 Watch 目录、删 PlugIns
    /// 目录、删主 Info.plist 里的设备限制键（UISupportedDevices /
    /// UIRequiredDeviceCapabilities）、顺手清 .DS_Store / __MACOSX。
    /// 删 Watch 时一并删主 plist 里的 WKCompanionAppBundleIdentifier
    ///（指向已不存在的 Watch 应用，留着无意义）。任何一步不对
    /// （包里 App 不是唯一一个、plist 读不出来、主程序找不着、
    /// 压包失败）都直接抛错，不签一个半改的包；开关全关时不跑。
    /// 注意：解压/压包走的都是 App 已有的 Rust zip 实现（FileZipTool），
    /// 压包只压 Payload 目录——签名器本来也只取 Payload 里的 .app，
    /// 顶层杂项（iTunesMetadata 等）签完本来就不会留下，丢了无妨。
    private static func preSignRepack(ipa: URL, mods: CertSignMods, tmp: URL) throws -> URL {
        let fm = FileManager.default
        let work = tmp.appendingPathComponent("slim", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        if let error = FileZipTool.unzip(archive: ipa, to: work) {
            throw EngineError.message(L("瘦身改包解压失败：%@", error))
        }
        let payload = work.appendingPathComponent("Payload", isDirectory: true)
        let apps = (try? fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))
            .map { $0.filter { $0.pathExtension == "app" } } ?? []
        guard apps.count == 1, let appDir = apps.first else {
            throw EngineError.message(L("瘦身改包失败：包里 App 不是唯一一个"))
        }
        if mods.stripWatch {
            let watch = appDir.appendingPathComponent("Watch", isDirectory: true)
            if fm.fileExists(atPath: watch.path) {
                do { try fm.removeItem(at: watch) } catch {
                    throw EngineError.message(L("瘦身改包失败：Watch 目录删不掉"))
                }
            }
        }
        if mods.stripExtensions {
            let plugins = appDir.appendingPathComponent("PlugIns", isDirectory: true)
            if fm.fileExists(atPath: plugins.path) {
                do { try fm.removeItem(at: plugins) } catch {
                    throw EngineError.message(L("瘦身改包失败：PlugIns 目录删不掉"))
                }
            }
        }
        if mods.stripDeviceLimits || mods.stripWatch {
            let plistURL = appDir.appendingPathComponent("Info.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  var dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                throw EngineError.message(L("瘦身改包失败：主 Info.plist 读不出来"))
            }
            if mods.stripDeviceLimits {
                dict.removeValue(forKey: "UISupportedDevices")
                dict.removeValue(forKey: "UIRequiredDeviceCapabilities")
            }
            if mods.stripWatch {
                dict.removeValue(forKey: "WKCompanionAppBundleIdentifier")
            }
            guard let out = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) else {
                throw EngineError.message(L("瘦身改包失败：主 Info.plist 写不出来"))
            }
            try out.write(to: plistURL)
            // 主程序还在才算包没改坏（plist 里 CFBundleExecutable 指谁就查谁）。
            if let exe = dict["CFBundleExecutable"] as? String, !exe.isEmpty,
               !fm.fileExists(atPath: appDir.appendingPathComponent(exe).path) {
                throw EngineError.message(L("瘦身改包失败：主程序找不到了"))
            }
        }
        // 垃圾清理：先收齐再删，枚举途中不改目录。
        var junk: [URL] = []
        if let enumerator = fm.enumerator(at: work, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == ".DS_Store" || url.lastPathComponent == "__MACOSX" {
                    junk.append(url)
                }
            }
        }
        for url in junk { try? fm.removeItem(at: url) }
        let out = tmp.appendingPathComponent("slimmed.ipa")
        if let error = FileZipTool.zip(paths: [payload], to: out) {
            throw EngineError.message(L("瘦身改包压包失败：%@", error))
        }
        return out
    }

    /// 用企业证书把 IPA 签好并存进「已签名」，返回记录。
    static func signToFile(ipa: URL, mods: CertSignMods) async throws -> SignedIPARecord {
        guard EnterpriseCertStore.ready else {
            throw EngineError.message(L("企业证书材料不齐：需要 .p12、描述文件和证书密码。"))
        }
        try EnterpriseCertStore.validateForSigning()
        return try await Task.detached(priority: .userInitiated) {
            let (certDER, keyDER) = try EnterpriseCertStore.identityDERs()
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory
                .appendingPathComponent("EnterpriseSign-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: tmp) }
            let certPath = tmp.appendingPathComponent("cert.der")
            let keyPath = tmp.appendingPathComponent("key.der")
            try certDER.write(to: certPath)
            try keyDER.write(to: keyPath)
            var iconPath: String? = nil
            if let icon = mods.pngIconData() {
                let path = tmp.appendingPathComponent("icon.png")
                try icon.write(to: path)
                iconPath = path.path
            }
            let outURL = SignedIPAStore.uniqueOutputURL(
                baseName: Self.outputBaseName(mods: mods, ipa: ipa))
            // 打包失败清理用（见 S8）：签名开始前 outURL 是否已存在。
            // 正常流程 uniqueOutputURL 恒返回不存在的路径，快照恒为
            // false；S2 互斥修好后这个快照才是竞态安全的。
            let outExistedBefore = fm.fileExists(atPath: outURL.path)
            let json = mods.json(iconPath: iconPath, outIpaPath: outURL.path)
            // 瘦身/兼容开关开着：先改包再签，改坏直接抛错不签；
            // 开关全关走原包，一字不动。
            let signIPA = mods.needsPreSignRepack
                ? try Self.preSignRepack(ipa: ipa, mods: mods, tmp: tmp)
                : ipa
            var signed: UnsafeMutablePointer<CChar>?
            var error: UnsafeMutablePointer<CChar>?
            let rc = si_sign_ipa_with_cert_ex(signIPA.path, certPath.path, keyPath.path,
                                              EnterpriseCertStore.provisionURL.path,
                                              json, &signed, &error)
            if rc != 0 {
                let msg = error.map { String(cString: $0) } ?? "rc=\(rc)"
                error.map { si_string_free($0) }
                // zip_bundle 一上来就 File::create(out_ipa)，打包中
                // 途失败会留半截 zip：本次签名开始前不存在、失败
                // 后已存在，就是这次留下的残缺文件，删掉它；用户
                // 原有文件（开始前已存在）绝不删。
                if !outExistedBefore {
                    try? fm.removeItem(at: outURL)
                }
                // C22-3：签名失败也留 `_extracted`——清掉再往上抛。
                // 用 signIPA.path：瘦身开关开着时解的是 slimmed.ipa。
                Engine.discardExtraction(forIPA: signIPA.path)
                throw EngineError.message(L("企业证书签名失败：%@", msg))
            }
            signed.map { si_string_free($0) }
            let info = IPALibrary.appInfo(at: signIPA)
            let size = (try? fm.attributesOfItem(atPath: outURL.path))?[.size] as? Int ?? 0
            // 已签名行第三行用：证书名取 p12 的名头，团队 ID 取描述文件
            // 的 TeamIdentifier；读不出来就留空，行里不显示第三行。
            let certName = EnterpriseCertStore.certInfo?.name
            let teamID = EnterpriseCertStore.provisionInfo?.teamID
            let record = SignedIPARecord(
                fileName: outURL.lastPathComponent,
                appName: mods.name.isEmpty ? (info?.name ?? ipa.deletingPathExtension().lastPathComponent) : mods.name,
                bundleID: mods.bundleID.isEmpty ? (info?.bundleID ?? "") : mods.bundleID,
                version: mods.version.isEmpty ? info?.version : mods.version,
                date: Date(), size: size,
                certName: (certName?.isEmpty == false) ? certName : nil,
                teamID: (teamID?.isEmpty == false) ? teamID : nil)
            SignedIPAStore.add(record)
            return record
        }.value
    }
}

// MARK: - 证书页/文件页共享的选择

/// 文件页点「去签名」时把 IPA 交给证书页。
final class CertWorkspace: ObservableObject {
    @Published var selectedIPA: URL?
    /// U-UI：文件页/源页把 IPA 交给企业证书页时举手——RootView 认到后
    /// 切到设置 tab 并打开企业证书页；RootView 触发后自己清掉。
    @Published var openEnterpriseSign = false
    /// U-UI：单签进行中（原证书页的 @State signBusy；签名段与
    /// 应用库段拆到两个 View 后，互斥标志放共享工作区）。
    @Published var signBusy = false
    /// U-UI：批量签名进行中（原证书页的 @State batchBusy；同上）。
    @Published var batchBusy = false
}


// MARK: - 文件页用的压缩 / 解压（Rust 的 zip 实现）

enum FileZipTool {
    /// 把文件/文件夹压成 zip。成功返回 nil，失败返回错误文本。
    static func zip(paths: [URL], to out: URL) -> String? {
        let json = (try? JSONSerialization.data(withJSONObject: paths.map { $0.path }))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        var error: UnsafeMutablePointer<CChar>?
        let rc = json.withCString { j in
            out.path.withCString { o in
                si_zip_create(j, o, &error)
            }
        }
        return takeError(rc, &error)
    }

    /// 把 zip 解压到指定目录。成功返回 nil，失败返回错误文本。
    static func unzip(archive: URL, to dir: URL) -> String? {
        var error: UnsafeMutablePointer<CChar>?
        let rc = archive.path.withCString { a in
            dir.path.withCString { d in
                si_unzip_archive(a, d, &error)
            }
        }
        return takeError(rc, &error)
    }

    private static func takeError(
        _ rc: Int32, _ error: inout UnsafeMutablePointer<CChar>?
    ) -> String? {
        defer {
            if let error { si_string_free(error) }
        }
        guard rc != 0 else { return nil }
        if let error { return String(cString: error) }
        return L("操作失败")
    }
}
