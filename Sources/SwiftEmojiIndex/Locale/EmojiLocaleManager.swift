import Foundation

/// Manages emoji locale preferences and available locales.
///
/// ## Usage
///
/// ```swift
/// let manager = EmojiLocaleManager.shared
///
/// // Get available locales (on macOS, from CoreEmoji)
/// let available = manager.availableLocales
///
/// // Set preferred locale
/// manager.preferredLocale = Locale(identifier: "ja")
///
/// // Get current effective locale
/// let current = manager.effectiveLocale
/// ```
@Observable
public final class EmojiLocaleManager: @unchecked Sendable {
    /// Shared instance.
    public static let shared = EmojiLocaleManager()

    private let storageKey = "SwiftEmojiIndex.preferredLocale"
    private let lock = NSLock()

    /// The user's preferred locale for emoji names.
    /// Set to `nil` to use system locale.
    public var preferredLocale: Locale? {
        didSet {
            if let locale = preferredLocale {
                UserDefaults.standard.set(locale.identifier, forKey: storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: storageKey)
            }
        }
    }

    /// The effective locale (preferred or system).
    public var effectiveLocale: Locale {
        preferredLocale ?? .current
    }

    /// Available locales for emoji data.
    ///
    /// Returns the union of:
    /// - CLDR locales (all platforms)
    /// - Apple CoreEmoji locales (macOS only)
    public var availableLocales: [Locale] {
        var locales = Set(CLDREmojiDataSource.availableLocales)
        #if os(macOS)
        locales.formUnion(appleAvailableLocales())
        #endif
        return locales.sorted { $0.identifier < $1.identifier }
    }

    /// CLDR locales (cross-platform).
    public var cldrLocales: [Locale] {
        CLDREmojiDataSource.availableLocales
    }

    /// Apple CoreEmoji locales (macOS only).
    public var appleLocales: [Locale] {
        #if os(macOS)
        return appleAvailableLocales()
        #else
        return []
        #endif
    }

    /// Whether localized emoji names are available on this platform.
    /// Always true since CLDR works everywhere.
    public var isLocalizationAvailable: Bool {
        true
    }

    /// Whether Apple's CoreEmoji is available (macOS only, better quality).
    public var isAppleLocalizationAvailable: Bool {
        #if os(macOS)
        return AppleEmojiDataSource.isAvailable
        #else
        return false
        #endif
    }

    private init() {
        // Load saved preference
        if let saved = UserDefaults.standard.string(forKey: storageKey) {
            preferredLocale = Locale(identifier: saved)
        }
    }

    #if os(macOS)
    private func appleAvailableLocales() -> [Locale] {
        AppleEmojiDataSource.availableLocales()
    }
    #endif
}

// MARK: - Locale Helpers

extension Locale {
    /// Display name for this locale in the user's current language.
    public var localizedDisplayName: String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    /// Display name in this locale's own language.
    public var nativeDisplayName: String {
        localizedString(forIdentifier: identifier) ?? identifier
    }
}
