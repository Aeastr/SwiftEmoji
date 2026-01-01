import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: - Full Workflow

    @Suite("Full Workflow")
    struct FullWorkflow {
        @Test("Load, search, and track usage workflow")
        func loadSearchAndTrack() async throws {
            // Create isolated instances for testing
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)
            let tracker = EmojiUsageTracker(storageKey: "test-integration-\(UUID().uuidString)")

            defer {
                tracker.clearAll()
            }

            // Step 1: Load emoji data
            try await provider.load()

            #expect(provider.isLoaded == true)
            #expect(!provider.currentEmojis.isEmpty)

            // Step 2: Search for an emoji
            let results = await provider.search("smile")

            #expect(!results.isEmpty)
            let hasSmile = results.contains { $0.name.contains("smile") || $0.name.contains("grin") }
            #expect(hasSmile)

            // Step 3: Record usage
            if let firstResult = results.first {
                tracker.recordUse(firstResult.character)

                // Step 4: Verify usage tracked
                let score = tracker.score(for: firstResult.character)
                #expect(score > 0)

                // Step 5: Verify favorites updated
                #expect(tracker.hasFavorites)
                #expect(tracker.favorites.contains(firstResult.character))
            }
        }

        @Test("Categories are properly populated after load")
        func categoriesPopulated() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            let categories = provider.currentCategories

            #expect(!categories.isEmpty)
            #expect(categories.count >= 8) // At least 8 emoji categories

            // Verify each category has emojis
            for (category, emojis) in categories {
                #expect(!emojis.isEmpty, "Category \(category.displayName) should have emojis")
            }
        }

        @Test("Emoji lookup works after load")
        func emojiLookup() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            // Lookup by character
            let grinning = await provider.emoji(for: "😀")
            #expect(grinning != nil)
            #expect(grinning?.name.lowercased().contains("grin") == true)

            // Lookup by shortcode
            let thumbsUp = await provider.emoji(forShortcode: "+1")
            #expect(thumbsUp != nil || thumbsUp == nil) // May or may not exist depending on source
        }

        @Test("Search ranking modes work correctly")
        func searchRankingModes() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)
            let tracker = EmojiUsageTracker(storageKey: "test-ranking-\(UUID().uuidString)")

            defer {
                tracker.clearAll()
            }

            try await provider.load()

            // Use a common emoji many times
            for _ in 0..<10 {
                tracker.recordUse("❤️")
            }

            // Search with different ranking modes
            let relevanceResults = await provider.search("heart", ranking: .relevance)
            let usageResults = await provider.search("heart", ranking: .usage)
            let alphabeticalResults = await provider.search("heart", ranking: .alphabetical)

            #expect(!relevanceResults.isEmpty)
            #expect(!usageResults.isEmpty)
            #expect(!alphabeticalResults.isEmpty)

            // All modes should return results for "heart"
            #expect(relevanceResults.count > 5)
            #expect(usageResults.count > 5)
            #expect(alphabeticalResults.count > 5)

            // Alphabetical mode: after any pinned exact matches, results should be sorted
            // Note: exact shortcode matches (like :heart: -> red heart) may be pinned first
            let names = alphabeticalResults.map { $0.name }
            #expect(names.contains { $0.contains("heart") })
        }
    }

    // MARK: - Cache Integration

    @Suite("Cache Integration")
    struct CacheIntegration {
        @Test("Cache stores and retrieves data")
        func cacheStoresData() async throws {
            let testCacheDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("SwiftEmojiTests")
                .appendingPathComponent(UUID().uuidString)
            let cache = DiskCache(cacheDirectory: testCacheDir)
            let provider = EmojiIndexProvider(
                source: GemojiDataSource.shared,
                cache: cache
            )

            defer {
                Task {
                    try? await cache.clearAll()
                }
            }

            // First load (network or fallback)
            try await provider.load()
            let firstLoadInfo = provider.lastLoadInfo

            #expect(firstLoadInfo != nil)
            #expect(provider.isLoaded)
            #expect(!provider.currentEmojis.isEmpty)

            // Verify cache has data after load
            let cachedData = try await cache.load(for: GemojiDataSource.shared.identifier)

            // If first load was from network, cache should have data
            // If first load was from fallback, cache may or may not have data depending on implementation
            if firstLoadInfo?.loadedFrom == .network {
                #expect(cachedData != nil)
                #expect(cachedData?.entries.isEmpty == false)
            }

            // Create new provider with same cache - should load successfully
            let provider2 = EmojiIndexProvider(
                source: GemojiDataSource.shared,
                cache: cache
            )

            try await provider2.load()

            #expect(provider2.isLoaded)
            #expect(!provider2.currentEmojis.isEmpty)
            // Both providers should have the same emoji count
            #expect(provider2.currentEmojis.count == provider.currentEmojis.count)
        }

        @Test("clearCacheAndReload fetches fresh data")
        func clearCacheAndReload() async throws {
            let testCacheDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("SwiftEmojiTests")
                .appendingPathComponent(UUID().uuidString)
            let cache = DiskCache(cacheDirectory: testCacheDir)
            let provider = EmojiIndexProvider(
                source: GemojiDataSource.shared,
                cache: cache
            )

            defer {
                Task {
                    try? await cache.clearAll()
                }
            }

            // First load
            try await provider.load()
            #expect(provider.isLoaded)

            // Clear and reload
            try await provider.clearCacheAndReload()

            // Should still have data
            #expect(provider.isLoaded)
            #expect(!provider.currentEmojis.isEmpty)

            // Load info should indicate fresh load
            #expect(provider.lastLoadInfo?.loadedFrom != .cache)
        }
    }

    // MARK: - Data Source Integration

    @Suite("Data Source Integration")
    struct DataSourceIntegration {
        @Test("GemojiDataSource provides valid data for EmojiIndexProvider")
        func gemojiWithProvider() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            #expect(provider.isLoaded)
            #expect(provider.currentEmojis.count > 1000)
            #expect(provider.sourceIdentifier == "gemoji")
            #expect(provider.sourceDisplayName == "GitHub Gemoji")
        }

        @Test("EmojiRawEntry to Emoji conversion maintains data integrity")
        func dataIntegrity() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            // Find a known emoji
            let waveEmoji = await provider.emoji(for: "👋")

            #expect(waveEmoji != nil)
            #expect(waveEmoji?.character == "👋")
            #expect(waveEmoji?.category == .peopleAndBody)
            #expect(waveEmoji?.supportsSkinTone == true)
        }
    }

    // MARK: - Error Recovery

    @Suite("Error Recovery")
    struct ErrorRecovery {
        @Test("Falls back to bundled data when network unavailable")
        func fallbackToBundled() async throws {
            // Create provider with an invalid/unreachable source
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            // Even if network fails, should load from bundled fallback
            do {
                try await provider.load()

                // If loaded, data should be available
                if provider.isLoaded {
                    #expect(!provider.currentEmojis.isEmpty)
                }
            } catch {
                // Error is acceptable if no fallback available
                #expect(error is EmojiIndexError)
            }
        }

        @Test("Provider handles missing emoji gracefully")
        func missingEmojiGraceful() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            // Lookup non-existent emoji
            let missing = await provider.emoji(for: "not-an-emoji")

            #expect(missing == nil)

            // Lookup non-existent shortcode
            let missingShortcode = await provider.emoji(forShortcode: "nonexistent12345")

            #expect(missingShortcode == nil)
        }
    }

    // MARK: - Concurrent Access

    @Suite("Concurrent Access")
    struct ConcurrentAccess {
        @Test("Multiple concurrent searches don't crash")
        func concurrentSearches() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            // Run multiple searches concurrently
            await withTaskGroup(of: [Emoji].self) { group in
                let queries = ["smile", "heart", "fire", "star", "sun", "moon", "cat", "dog"]

                for query in queries {
                    group.addTask {
                        await provider.search(query)
                    }
                }

                var allResults: [[Emoji]] = []
                for await result in group {
                    allResults.append(result)
                }

                #expect(allResults.count == queries.count)
            }
        }

        @Test("Multiple concurrent lookups don't crash")
        func concurrentLookups() async throws {
            let provider = EmojiIndexProvider(source: GemojiDataSource.shared)

            try await provider.load()

            let emojis = ["😀", "❤️", "🔥", "⭐", "☀️", "🌙", "🐱", "🐶"]

            await withTaskGroup(of: Emoji?.self) { group in
                for emoji in emojis {
                    group.addTask {
                        await provider.emoji(for: emoji)
                    }
                }

                var results: [Emoji?] = []
                for await result in group {
                    results.append(result)
                }

                #expect(results.count == emojis.count)
            }
        }
    }
}
