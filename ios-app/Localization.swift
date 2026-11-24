import Foundation

/// The language the interface is drawn in; `auto` follows the iPhone's.
enum AppLanguage: String, CaseIterable, Identifiable {
    case auto
    case english
    case spanish
    case italian
    case vietnamese
    case french
    case chinese
    case japanese
    case korean
    case portuguese
    case turkish

    var id: String { rawValue }

    /// Picker label, each language named in itself so it can be recognised.
    var displayName: String {
        switch self {
        case .auto:       return L("Auto")
        case .english:    return "English"
        case .spanish:    return "Español"
        case .italian:    return "Italiano"
        case .vietnamese: return "Tiếng Việt"
        case .french:     return "Français"
        case .chinese:    return "简体中文"
        case .japanese:   return "日本語"
        case .korean:     return "한국어"
        case .portuguese: return "Português"
        case .turkish:    return "Türkçe"
        }
    }

    /// `auto` resolved against the phone, falling back to English, the source
    /// language; a pinned case returns itself.
    var resolved: AppLanguage {
        guard self == .auto else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        switch preferred.prefix(2) {
        case "es": return .spanish
        case "it": return .italian
        case "vi": return .vietnamese
        case "fr": return .french
        // All Chinese variants use the Simplified Chinese translation.
        case "zh": return .chinese
        case "ja": return .japanese
        case "ko": return .korean
        // All Portuguese variants use the Brazilian Portuguese translation.
        case "pt": return .portuguese
        case "tr": return .turkish
        default:   return .english
        }
    }

    /// The copy for this language, or nil for the source language.
    fileprivate var table: [String: String]? {
        switch self {
        case .spanish:        return spanishStrings
        case .italian:        return italianStrings
        case .vietnamese:     return vietnameseStrings
        case .french:         return frenchStrings
        case .chinese:        return chineseStrings
        case .japanese:       return japaneseStrings
        case .korean:         return koreanStrings
        case .portuguese:     return portugueseStrings
        case .turkish:        return turkishStrings
        case .auto, .english: return nil
        }
    }
}

/// Owns and persists the language choice, republishing it so views holding a
/// `@EnvironmentObject var loc: Localizer` redraw. A singleton because `L(_:)`
/// is a free function called from background queues too.
final class Localizer: ObservableObject {

    static let shared = Localizer()

    private static let defaultsKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.defaultsKey)
            Localizer.effective = language.resolved
        }
    }

    /// `language` with `.auto` resolved, as a static `L(_:)` can read from any
    /// thread. Nil until the singleton has been built.
    fileprivate static var effective: AppLanguage?

    /// Language used by `L(_:)`. Falls back to `shared` (creating it) when `L`
    /// is called before the singleton exists.
    fileprivate static var effectiveLanguage: AppLanguage {
        effective ?? shared.language.resolved
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .auto
        language = stored                       // didSet doesn't run in init, so set `effective` below
        Localizer.effective = stored.resolved
    }
}

extension Localizer {
    /// Locale for dates and numbers, so they match the copy around them.
    static var locale: Locale {
        switch shared.language {
        case .auto:       return phoneLocale
        case .english:    return Locale(identifier: "en_US")
        case .spanish:    return Locale(identifier: "es_ES")
        case .italian:    return Locale(identifier: "it_IT")
        case .vietnamese: return Locale(identifier: "vi_VN")
        case .french:     return Locale(identifier: "fr_FR")
        case .chinese:    return Locale(identifier: "zh_Hans_CN")
        case .japanese:   return Locale(identifier: "ja_JP")
        case .korean:     return Locale(identifier: "ko_KR")
        case .portuguese: return Locale(identifier: "pt_BR")
        case .turkish:    return Locale(identifier: "tr_TR")
        }
    }

    /// The phone's region in the language the copy resolved to. The app's own
    /// current locale takes its language from the bundle, which is English
    /// only, so an Italian phone got "en_IT": Italian copy next to English
    /// unit and month names ("1 min, 30 secs").
    private static var phoneLocale: Locale {
        let language: String
        switch AppLanguage.auto.resolved {
        case .spanish:        language = "es"
        case .italian:        language = "it"
        case .vietnamese:     language = "vi"
        case .french:         language = "fr"
        case .chinese:        language = "zh_Hans"
        case .japanese:       language = "ja"
        case .korean:         language = "ko"
        case .portuguese:     language = "pt"
        case .turkish:        language = "tr"
        case .auto, .english: return .autoupdatingCurrent
        }
        guard let region = Locale.autoupdatingCurrent.region?.identifier else {
            return Locale(identifier: language)
        }
        return Locale(identifier: "\(language)_\(region)")
    }
}

/// Translate one source string, falling back to the English key itself.
func L(_ key: String) -> String {
    Localizer.effectiveLanguage.table?[key] ?? key
}

/// `L` for copy with values in it, as a `String(format:)` pattern.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}

/// User-facing text for an error. A raw FFIError is a debug string
/// ("idevice FFI error code=…"), never a sentence — map it to one generic line.
func userFacingErrorMessage(_ error: Error) -> String {
    if error is DeviceConnection.FFIError {
        return L("Couldn't reach this iPhone. Check the connection and try again.")
    }
    return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
}

/// Maps a raw Rust/FFI error string to a short user-facing sentence.
/// Only call on raw FFI/decoder strings, right before they are wrapped in
/// `EngineError.message` / `L(...)` — never on already-localized text, and
/// never inside `userFacingErrorMessage` or `short()`, which also see
/// friendly Swift text that the patterns would misread.
func friendlyRustError(_ raw: String) -> String {
    // Tier 0 — Chinese prefixes (enterprise signing / zip): return the prefix
    // itself, i.e. the text before the first "：". Checked before every English
    // pattern: the io tail after the prefix is English and would otherwise
    // steal the match.
    let chinesePrefixes = [
        "描述文件解析失败", "读图标失败", "写图标失败", "读签名包失败",
        "建已签 IPA 失败", "打包失败", "读证书失败", "读私钥失败",
        "证书解析失败", "私钥解析失败", "读主程序失败", "写主程序失败",
        "deb 解压失败", "写插件失败", "读插件失败", "插件 zip 打不开",
        "插件 zip 读取失败", "建 Frameworks 失败", "参数不对", "压缩失败",
        "读压缩包失败", "压缩包打不开", "建解压目录失败", "解压失败",
        "读文件失败", "写文件失败", "读文件夹失败",
    ]
    for prefix in chinesePrefixes where raw.hasPrefix(prefix) {
        if let colon = raw.firstIndex(of: "：") { return String(raw[..<colon]) }
        return raw
    }

    let text = raw.lowercased()
    // Tier 1 — specific fixed strings + the Engine login classifiers.
    // Order matters: Apple's own rate-limit wording wins over a bare 429,
    // and the pairing timeouts must land here, ahead of Tier 2's "timed out".
    if text.contains("no development teams on this apple id") {
        return L("This Apple ID has no development team. Sign in at developer.apple.com once to create one, then try again.")
    }
    if text.contains("no certificate on team") {
        return L("That certificate belongs to another Apple ID, or it was revoked.")
    }
    if text.contains("certificate on this apple id yet") {
        return L("There's no signing certificate on this Apple ID yet. Install an app first — that's what creates it.")
    }
    if text.contains("is no longer on this team") {
        return L("That App ID is no longer on this team.")
    }
    if text.contains("couldn't open the pkcs#12 archive") {
        return L("密码错误，请重新输入")
    }
    if text.contains("not a pkcs#12 archive") || text.contains("unreadable pkcs#12 archive") {
        return L("That file isn't a certificate archive (.p12). Check the file and try again.")
    }
    if Engine.isAccountLocked(raw) {
        return EngineError.accountLocked.errorDescription
            ?? L("Something went wrong. Check the activity log and try again.")
    }
    if Engine.isUnderageError(raw) {
        return EngineError.underage.errorDescription
            ?? L("Something went wrong. Check the activity log and try again.")
    }
    if Engine.isEmailUnverifiedError(raw) {
        return EngineError.emailUnverified.errorDescription
            ?? L("Something went wrong. Check the activity log and try again.")
    }
    if Engine.isCredentialError(raw) { return Engine.credentialErrorMessage }
    if Engine.isAppleRateLimit(raw) { return Engine.appleRateLimitMessage }
    if Engine.isAppleServiceRefusal(raw) { return Engine.appleServiceRefusalMessage }
    if text.contains("no space left on device") {
        return L("This iPhone is out of storage space. Free some space and try again.")
    }
    if text.contains("no such file or directory") || text.contains("application path does not exist") {
        return L("A file this step needed is missing. Check the file library and try again.")
    }
    if text.contains("(429 ") || text.contains("http 429") {
        return L("Sign-ins are being limited right now. Wait a few minutes and try again.")
    }
    if text.contains("server error (5") || text.contains("http 500")
        || text.contains("http 502") || text.contains("http 503") {
        return L("Apple's service didn't answer. Try again in a bit.")
    }
    if text.contains("pairing timed out: the iphone connected but stopped responding") {
        return L("Their iPhone connected but stopped responding before asking for a code. Try pairing again.")
    }
    if text.contains("pairing timed out: the code wasn't entered") {
        return L("The pairing code wasn't entered in time. Pair again and enter the code when it appears.")
    }
    if text.contains("failed to bind") {
        return L("Check the network connection and try again.")
    }
    // Tier 2 — network. Ahead of the login catch-all, so "login failed:
    // error sending request" reads as a network failure, not a bad password.
    if text.contains("dns") || text.contains("connection refused")
        || text.contains("timed out") || text.contains("timeout")
        || text.contains("network is unreachable") || text.contains("connection reset")
        || text.contains("error sending request") || text.contains("failed to lookup address")
        || text.contains("tls") || text.contains("certificate verify failed") {
        return L("Check the network connection and try again.")
    }
    // Tier 3 — login, generic.
    if text.contains("login failed") || text.contains("unauthorized")
        || text.contains("http 401") || text.contains("http 403") {
        return L("Apple didn't accept the sign-in. Check the Apple ID and password, then try again.")
    }
    // Tier 4 — catch-all.
    return L("Something went wrong. Check the activity log and try again.")
}
