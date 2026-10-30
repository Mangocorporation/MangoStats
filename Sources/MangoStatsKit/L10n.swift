import Foundation

/// Translation for the words and sentences the Kit builds (S-051). The app sets
/// `lookup` to its Localizable.strings at launch; tests keep the identity, so
/// they read English. Sentences are formats ("%@ is holding %@"), translated
/// whole, so each language can order the words its own way.
public enum L10n {
    nonisolated(unsafe) public static var lookup: @Sendable (String) -> String = { $0 }

    /// A word or a sentence without values.
    public static func t(_ key: String) -> String { lookup(key) }

    /// A sentence with values: `L10n.f("%@ is holding %@", name, size)`.
    public static func f(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: lookup(key), locale: Locale.current, arguments: arguments)
    }
}
