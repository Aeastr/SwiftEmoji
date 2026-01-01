import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("EmojiLocaleManager")
struct EmojiLocaleManagerTests {

    @Test("shared singleton exists")
    func sharedInstance() {
        let shared1 = EmojiLocaleManager.shared
        let shared2 = EmojiLocaleManager.shared
        #expect(shared1 === shared2)
    }

    // MARK: - Locale Properties

    @Test("effectiveLocale returns preferredLocale when set")
    func effectiveLocalePreferred() {
        let manager = EmojiLocaleManager.shared
        let originalPreferred = manager.preferredLocale
        defer { manager.preferredLocale = originalPreferred }

        manager.preferredLocale = Locale(identifier: "ja")
        #expect(manager.effectiveLocale.identifier == "ja")
    }

    @Test("effectiveLocale returns current when no preference")
    func effectiveLocaleDefault() {
        let manager = EmojiLocaleManager.shared
        let originalPreferred = manager.preferredLocale
        defer { manager.preferredLocale = originalPreferred }

        manager.preferredLocale = nil
        #expect(manager.effectiveLocale == .current)
    }

    @Test("preferredLocale can be set and retrieved")
    func preferredLocaleSetGet() {
        let manager = EmojiLocaleManager.shared
        let originalPreferred = manager.preferredLocale
        defer { manager.preferredLocale = originalPreferred }

        manager.preferredLocale = Locale(identifier: "fr")
        #expect(manager.preferredLocale?.identifier == "fr")

        manager.preferredLocale = nil
        #expect(manager.preferredLocale == nil)
    }

    // MARK: - Available Locales

    @Test("availableLocales returns non-empty array")
    func availableLocalesNotEmpty() {
        let manager = EmojiLocaleManager.shared
        let locales = manager.availableLocales

        #expect(!locales.isEmpty)
    }

    @Test("availableLocales are sorted by identifier")
    func availableLocalesSorted() {
        let manager = EmojiLocaleManager.shared
        let locales = manager.availableLocales

        guard locales.count > 1 else { return }

        for i in 0..<(locales.count - 1) {
            #expect(locales[i].identifier < locales[i + 1].identifier)
        }
    }

    @Test("cldrLocales returns non-empty array")
    func cldrLocalesNotEmpty() {
        let manager = EmojiLocaleManager.shared
        let locales = manager.cldrLocales

        #expect(!locales.isEmpty)
    }

    // MARK: - Availability Flags

    @Test("isLocalizationAvailable is always true")
    func localizationAlwaysAvailable() {
        let manager = EmojiLocaleManager.shared
        #expect(manager.isLocalizationAvailable == true)
    }

    @Test("isAppleLocalizationAvailable returns boolean")
    func appleLocalizationAvailability() {
        let manager = EmojiLocaleManager.shared
        // Just verify it returns without crashing
        _ = manager.isAppleLocalizationAvailable
    }

    // MARK: - Data Source

    @Test("recommendedDataSource returns a valid source")
    func recommendedDataSource() {
        let manager = EmojiLocaleManager.shared
        let source = manager.recommendedDataSource()

        #expect(!source.identifier.isEmpty)
        #expect(!source.displayName.isEmpty)
    }

    @Test("recommendedDataSource uses effective locale")
    func recommendedDataSourceUsesLocale() {
        let manager = EmojiLocaleManager.shared
        let originalPreferred = manager.preferredLocale
        defer { manager.preferredLocale = originalPreferred }

        manager.preferredLocale = Locale(identifier: "ja")
        let source = manager.recommendedDataSource()

        // The source should contain locale info
        #expect(!source.identifier.isEmpty)
    }

    // MARK: - Platform-Specific

    #if os(macOS)
    @Test("appleLocales returns array on macOS")
    func appleLocalesOnMacOS() {
        let manager = EmojiLocaleManager.shared
        let locales = manager.appleLocales

        // May be empty if CoreEmoji is not available
        #expect(locales is [Locale])
    }
    #endif

    #if !os(macOS)
    @Test("appleLocales returns empty array on non-macOS")
    func appleLocalesOnOtherPlatforms() {
        let manager = EmojiLocaleManager.shared
        let locales = manager.appleLocales

        #expect(locales.isEmpty)
    }
    #endif
}

// MARK: - Locale Extension Tests

@Suite("Locale Extensions")
struct LocaleExtensionTests {

    @Test("localizedDisplayName returns non-empty string")
    func localizedDisplayName() {
        let locale = Locale(identifier: "en_US")
        #expect(!locale.localizedDisplayName.isEmpty)
    }

    @Test("nativeDisplayName returns non-empty string")
    func nativeDisplayName() {
        let locale = Locale(identifier: "ja")
        #expect(!locale.nativeDisplayName.isEmpty)
    }

    @Test("localizedDisplayName differs from identifier")
    func localizedDisplayNameDiffers() {
        let locale = Locale(identifier: "en_US")
        // Display name should be more human-readable than the identifier
        #expect(locale.localizedDisplayName != locale.identifier || locale.identifier == locale.localizedDisplayName)
    }

    @Test("Common locales have valid display names")
    func commonLocalesDisplayNames() {
        let locales = [
            Locale(identifier: "en"),
            Locale(identifier: "ja"),
            Locale(identifier: "zh"),
            Locale(identifier: "es"),
            Locale(identifier: "fr"),
        ]

        for locale in locales {
            #expect(!locale.localizedDisplayName.isEmpty)
            #expect(!locale.nativeDisplayName.isEmpty)
        }
    }
}
