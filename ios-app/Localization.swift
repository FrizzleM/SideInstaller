import Foundation

/// The language the interface is drawn in. `auto` follows the iPhone's own
/// language; the other cases pin the app to one language regardless of it.
enum AppLanguage: String, CaseIterable, Identifiable {
    case auto
    case english
    case spanish
    case italian
    case vietnamese
    case french
    case chinese

    var id: String { rawValue }

    /// Picker label. The real languages are named in themselves (an endonym) —
    /// that's how someone looking for their own language spots it in a list.
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

    /// `auto` resolved against the phone's language; a pinned case returns
    /// itself. A language the app has no table for falls back to English, which
    /// is what the source strings in this project are already written in.
    var resolved: AppLanguage {
        guard self == .auto else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        switch preferred.prefix(2) {
        case "es": return .spanish
        case "it": return .italian
        case "vi": return .vietnamese
        case "fr": return .french
        // Only Simplified is translated, but a Traditional phone still reads
        // closer to it than to English, so every zh- variant lands here.
        case "zh": return .chinese
        default:   return .english
        }
    }

    /// The copy for this language, or nil for the source language — one entry
    /// per translation the app ships. Adding a language means adding a case
    /// here and a table file next to `spanishStrings`.
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

/// Owns the language choice, persists it, and republishes it so the UI redraws
/// the moment it changes. A singleton because `L(_:)` — the lookup every call
/// site uses — is a free function reachable from anywhere, including the
/// background queues the engine builds its messages on.
///
/// Views opt into redrawing by declaring `@EnvironmentObject var loc: Localizer`;
/// that subscription is what repaints them when the picker moves.
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

    /// `language` with `.auto` already resolved, mirrored into a plain static so
    /// `L(_:)` can read it from any thread without hopping to the main actor.
    /// Nil only until the singleton has been built — see `effectiveLanguage`.
    fileprivate static var effective: AppLanguage?

    /// What `L(_:)` translates into. Reading `shared` here rather than trusting
    /// an initial value matters: the engine is constructed before this object is
    /// and localizes a status line on the way up, so the very first lookup can
    /// arrive before anything has touched the singleton.
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
    /// Locale to format dates and numbers with, so they read in the same
    /// language as the copy around them. Auto keeps the phone's own locale
    /// (region formatting included); a pinned language gets that language's.
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

/// Translate one source string. English *is* the source language, so its lookup
/// is the identity; a key missing from a translation falls back to the English
/// text rather than showing a raw key, so a missed string degrades quietly.
func L(_ key: String) -> String {
    Localizer.effectiveLanguage.table?[key] ?? key
}

/// `L` for copy with values in it: the source string is a `String(format:)`
/// pattern (`%@`, `%d`), so a translation is free to reorder its placeholders.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), arguments: arguments)
}
