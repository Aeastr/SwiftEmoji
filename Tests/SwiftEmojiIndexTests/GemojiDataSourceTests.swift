import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("GemojiDataSource")
struct GemojiDataSourceTests {

    // MARK: - Properties

    @Suite("Properties")
    struct Properties {
        @Test("identifier is 'gemoji'")
        func identifier() {
            let source = GemojiDataSource.shared
            #expect(source.identifier == "gemoji")
        }

        @Test("displayName is 'GitHub Gemoji'")
        func displayName() {
            let source = GemojiDataSource.shared
            #expect(source.displayName == "GitHub Gemoji")
        }

        @Test("remoteURL is valid GitHub URL")
        func remoteURL() {
            let source = GemojiDataSource.shared
            #expect(source.remoteURL != nil)
            #expect(source.remoteURL?.host == "raw.githubusercontent.com")
            #expect(source.remoteURL?.path.contains("gemoji") == true)
        }

        @Test("refreshInterval uses default of 24 hours")
        func refreshInterval() {
            let source = GemojiDataSource.shared
            #expect(source.refreshInterval == 24 * 60 * 60)
        }

        @Test("shared instance returns same instance")
        func sharedInstance() {
            let source1 = GemojiDataSource.shared
            let source2 = GemojiDataSource.shared
            #expect(source1.identifier == source2.identifier)
        }

        @Test("init creates valid instance")
        func initCreatesValidInstance() {
            let source = GemojiDataSource()
            #expect(source.identifier == "gemoji")
            #expect(source.displayName == "GitHub Gemoji")
        }
    }

    // MARK: - Protocol Conformance

    @Suite("Protocol Conformance")
    struct ProtocolConformance {
        @Test("Conforms to EmojiDataSource")
        func conformsToProtocol() {
            let source: any EmojiDataSource = GemojiDataSource.shared
            #expect(source.identifier == "gemoji")
        }

        @Test("Conforms to Sendable")
        func conformsToSendable() {
            let source: any Sendable = GemojiDataSource.shared
            #expect(source is GemojiDataSource)
        }
    }

    // MARK: - Fetch (Network Tests)

    @Suite("Fetch")
    struct Fetch {
        @Test("Fetch returns non-empty array of entries")
        func fetchReturnsEntries() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()

            #expect(!entries.isEmpty)
            #expect(entries.count > 1000) // Gemoji has 1800+ emojis
        }

        @Test("Fetched entries have valid structure")
        func entriesHaveValidStructure() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let firstEntry = entries.first!

            #expect(!firstEntry.character.isEmpty)
            #expect(!firstEntry.name.isEmpty)
            #expect(!firstEntry.category.isEmpty)
        }

        @Test("Fetched entries include common emojis")
        func includesCommonEmojis() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let characters = Set(entries.map { $0.character })

            #expect(characters.contains("😀"))
            #expect(characters.contains("❤️"))
            #expect(characters.contains("👍"))
        }

        @Test("Fetched entries include shortcodes")
        func includesShortcodes() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let entriesWithShortcodes = entries.filter { !$0.shortcodes.isEmpty }

            #expect(!entriesWithShortcodes.isEmpty)
            #expect(entriesWithShortcodes.count > entries.count / 2) // Most should have shortcodes
        }

        @Test("Fetched entries include skin tone info")
        func includesSkinToneInfo() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let skinToneEntries = entries.filter { $0.supportsSkinTone }

            #expect(!skinToneEntries.isEmpty)
        }

        @Test("Categories are populated")
        func categoriesPopulated() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let categories = Set(entries.map { $0.category })

            #expect(categories.count >= 8) // At least 8 emoji categories
        }
    }

    // MARK: - EmojiRawEntry Conversion

    @Suite("Entry Conversion")
    struct EntryConversion {
        @Test("Fetched entries can be converted to Emoji")
        func entriesToEmoji() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            let emojis = entries.compactMap { $0.toEmoji() }

            // Most entries should convert successfully
            #expect(emojis.count > entries.count / 2)
        }

        @Test("Converted emojis have correct properties")
        func convertedEmojiProperties() async throws {
            let source = GemojiDataSource.shared

            let entries = try await source.fetch()
            guard let grinningEntry = entries.first(where: { $0.character == "😀" }) else {
                Issue.record("Grinning face not found in entries")
                return
            }

            let emoji = grinningEntry.toEmoji()

            #expect(emoji != nil)
            #expect(emoji?.character == "😀")
            #expect(emoji?.category == .smileysAndEmotion)
        }
    }
}
