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
        // Only Simplified is translated, but it beats English for every variant.
        case "zh": return .chinese
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

    /// What `L(_:)` translates into, reading `shared` because the engine
    /// localizes a status line before this object exists.
    fileprivate static var effectiveLanguage: AppLanguage {
        effective ?? shared.language.resolved
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .auto
        language = stored                       // no didSet during init — by design
        Localizer.effective = stored.resolved
    }
}

extension Localizer {
    /// Locale for dates and numbers, so they match the copy around them.
    static var locale: Locale {
        switch shared.language {
        case .auto:       return .autoupdatingCurrent
        case .english:    return Locale(identifier: "en_US")
        case .spanish:    return Locale(identifier: "es_ES")
        case .italian:    return Locale(identifier: "it_IT")
        case .vietnamese: return Locale(identifier: "vi_VN")
        case .french:     return Locale(identifier: "fr_FR")
        case .chinese:    return Locale(identifier: "zh_Hans_CN")
        }
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
