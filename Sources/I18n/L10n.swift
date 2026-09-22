import Foundation

enum AppLanguage: String, CaseIterable {
    case en
    case tr

    var displayName: String {
        switch self {
        case .en: return "English"
        case .tr: return "Türkçe"
        }
    }
}

extension Notification.Name {
    static let blmLanguageChanged = Notification.Name("blmLanguageChanged")
    static let blmSessionsChanged = Notification.Name("blmSessionsChanged")
}

final class L10n {
    static let shared = L10n()

    private(set) var language: AppLanguage

    private init() {
        if let stored = UserDefaults.standard.string(forKey: "app.language"),
           let lang = AppLanguage(rawValue: stored) {
            language = lang
        } else if Locale.current.language.languageCode?.identifier == "tr" {
            language = .tr
        } else {
            language = .en
        }
    }

    func setLanguage(_ lang: AppLanguage) {
        guard lang != language else { return }
        language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "app.language")
        NotificationCenter.default.post(name: .blmLanguageChanged, object: lang)
    }

    func t(_ key: String) -> String {
        let table = language == .tr ? tr : en
        if let value = table[key] { return value }
        if let fallback = en[key] { return fallback }
        return key
    }

    subscript(_ key: String) -> String { t(key) }
}

let L = L10n.shared
