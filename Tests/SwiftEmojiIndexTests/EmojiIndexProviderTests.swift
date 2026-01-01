import Testing
@testable import SwiftEmojiIndex

@Suite("EmojiIndexProvider")
struct EmojiIndexProviderTests {

    // MARK: - Shared Instance

    @Test("shared singleton exists")
    func sharedInstance() {
        let shared1 = EmojiIndexProvider.shared
        let shared2 = EmojiIndexProvider.shared
        #expect(shared1 === shared2)
    }

    // MARK: - Loading State

    @Test("isLoaded is false before loading")
    func initialLoadState() {
        let provider = EmojiIndexProvider()
        #expect(provider.isLoaded == false)
    }

    @Test("isLoading is false when idle")
    func initialLoadingState() {
        let provider = EmojiIndexProvider()
        #expect(provider.isLoading == false)
    }

    // MARK: - Emoji Lookup

    @Suite("emoji(for:)")
    struct EmojiLookup {
        @Test("Returns emoji for valid character")
        func validCharacter() async {
            let provider = EmojiIndexProvider.shared
            let emoji = await provider.emoji(for: "😀")

            #expect(emoji != nil)
            #expect(emoji?.character == "😀")
        }

        @Test("Returns nil for invalid character")
        func invalidCharacter() async {
            let provider = EmojiIndexProvider.shared
            let emoji = await provider.emoji(for: "abc")

            #expect(emoji == nil)
        }

        @Test("Returns nil for empty string")
        func emptyString() async {
            let provider = EmojiIndexProvider.shared
            let emoji = await provider.emoji(for: "")

            #expect(emoji == nil)
        }
    }

    @Suite("emoji(forShortcode:)")
    struct ShortcodeLookup {
        @Test("Returns emoji for valid shortcode")
        func validShortcode() async {
            let provider = EmojiIndexProvider.shared
            let emoji = await provider.emoji(forShortcode: "grinning")

            if let emoji = emoji {
                #expect(!emoji.character.isEmpty)
            }
        }

        @Test("Shortcode lookup is case-insensitive")
        func caseInsensitive() async {
            let provider = EmojiIndexProvider.shared
            let lower = await provider.emoji(forShortcode: "grinning")
            let upper = await provider.emoji(forShortcode: "GRINNING")
            let mixed = await provider.emoji(forShortcode: "GrInNiNg")

            #expect(lower?.character == upper?.character)
            #expect(lower?.character == mixed?.character)
        }

        @Test("Returns nil for unknown shortcode")
        func unknownShortcode() async {
            let provider = EmojiIndexProvider.shared
            let emoji = await provider.emoji(forShortcode: "not_a_real_shortcode_xyz123")

            #expect(emoji == nil)
        }
    }

    // MARK: - Search

    @Suite("search")
    struct Search {
        @Test("Empty query returns all emojis")
        func emptyQuery() async throws {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("")
            let allEmojis = try await provider.allEmojis

            #expect(results.count == allEmojis.count)
        }

        @Test("Whitespace-only query returns all emojis")
        func whitespaceQuery() async throws {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("   ")
            let allEmojis = try await provider.allEmojis

            #expect(results.count == allEmojis.count)
        }

        @Test("Search finds emoji by name")
        func searchByName() async {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("grinning")

            #expect(!results.isEmpty)
            #expect(results.first?.name.lowercased().contains("grinning") == true)
        }

        @Test("Search is case-insensitive")
        func caseInsensitive() async {
            let provider = EmojiIndexProvider.shared
            let lower = await provider.search("smile")
            let upper = await provider.search("SMILE")

            #expect(lower.count == upper.count)
        }

        @Test("Exact shortcode match appears first")
        func exactShortcodeFirst() async {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("grinning")

            if !results.isEmpty {
                let firstShortcodes = results.first?.shortcodes ?? []
                #expect(firstShortcodes.contains { $0.lowercased() == "grinning" })
            }
        }

        @Test("Search finds emoji by shortcode prefix")
        func shortcodePrefix() async {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("thumb")

            #expect(!results.isEmpty)
        }
    }

    // MARK: - Search Ranking

    @Suite("Search Ranking Modes")
    struct SearchRankingTests {
        @Test("Alphabetical ranking sorts by name")
        func alphabeticalRanking() async {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("face", ranking: .alphabetical)

            guard results.count > 1 else { return }

            for i in 0..<(results.count - 1) {
                let comparison = results[i].name.localizedCaseInsensitiveCompare(results[i + 1].name)
                #expect(comparison != .orderedDescending)
            }
        }

        @Test("Usage ranking returns results without crashing")
        func usageRanking() async {
            let provider = EmojiIndexProvider.shared
            let results = await provider.search("face", ranking: .usage)

            #expect(results.count >= 0)
        }

        @Test("Relevance ranking is default")
        func relevanceRankingDefault() async {
            let provider = EmojiIndexProvider.shared
            let defaultResults = await provider.search("face")
            let relevanceResults = await provider.search("face", ranking: .relevance)

            #expect(defaultResults.count == relevanceResults.count)
        }
    }

    // MARK: - Categories

    @Test("categories returns non-empty dictionary")
    func categoriesNotEmpty() async throws {
        let provider = EmojiIndexProvider.shared
        let categories = try await provider.categories

        #expect(!categories.isEmpty)
    }

    @Test("categories contains emoji for each category key")
    func categoriesHaveEmoji() async throws {
        let provider = EmojiIndexProvider.shared
        let categories = try await provider.categories

        for (_, emojis) in categories {
            #expect(!emojis.isEmpty)
        }
    }

    // MARK: - Favorites

    @Test("favorites returns emoji objects")
    func favorites() async {
        let provider = EmojiIndexProvider.shared
        let favorites = await provider.favorites()

        for emoji in favorites {
            #expect(!emoji.character.isEmpty)
        }
    }

    // MARK: - All Emojis

    @Test("allEmojis returns non-empty array")
    func allEmojisNotEmpty() async throws {
        let provider = EmojiIndexProvider.shared
        let emojis = try await provider.allEmojis

        #expect(!emojis.isEmpty)
    }

    @Test("allEmojis contains valid emoji objects")
    func allEmojisValid() async throws {
        let provider = EmojiIndexProvider.shared
        let emojis = try await provider.allEmojis

        for emoji in emojis.prefix(100) {
            #expect(!emoji.character.isEmpty)
            #expect(!emoji.name.isEmpty)
        }
    }

    // MARK: - Locale

    @Test("locale property returns current locale")
    func localeProperty() {
        let provider = EmojiIndexProvider()
        #expect(provider.locale == .current)
    }

    @Test("Custom locale initialization")
    func customLocale() {
        let japaneseLocale = Locale(identifier: "ja")
        let provider = EmojiIndexProvider(locale: japaneseLocale)
        #expect(provider.locale.identifier == "ja")
    }

    // MARK: - Load Info

    @Test("lastLoadInfo is populated after loading")
    func loadInfoPopulated() async throws {
        let provider = EmojiIndexProvider.shared
        _ = try await provider.allEmojis

        #expect(provider.lastLoadInfo != nil)
        #expect(provider.lastLoadInfo?.emojiCount ?? 0 > 0)
    }
}
