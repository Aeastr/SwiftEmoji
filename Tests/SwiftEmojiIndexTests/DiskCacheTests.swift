import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("DiskCache")
struct DiskCacheTests {

    // MARK: - Test Helpers

    /// Creates a temporary directory for test isolation.
    private func makeTestCache() -> DiskCache {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftEmojiIndexTests")
            .appendingPathComponent(UUID().uuidString)
        return DiskCache(cacheDirectory: testDir)
    }

    /// Creates sample emoji entries for testing.
    private func sampleEntries() -> [EmojiRawEntry] {
        [
            EmojiRawEntry(
                character: "😀",
                name: "grinning face",
                category: "Smileys & Emotion",
                shortcodes: ["grinning"],
                keywords: ["happy", "smile"],
                supportsSkinTone: false
            ),
            EmojiRawEntry(
                character: "👋",
                name: "waving hand",
                category: "People & Body",
                shortcodes: ["wave"],
                keywords: ["hello", "goodbye"],
                supportsSkinTone: true
            )
        ]
    }

    // MARK: - Save and Load

    @Suite("Save and Load")
    struct SaveAndLoad {
        @Test("Save and load round-trip preserves data")
        func roundTrip() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()
            let sourceId = "test-source"

            try await cache.save(entries, for: sourceId)
            let result = try await cache.load(for: sourceId)

            #expect(result != nil)
            #expect(result?.entries.count == 2)
            #expect(result?.entries.first?.character == "😀")
            #expect(result?.entries.last?.character == "👋")

            // Cleanup
            try await cache.clearAll()
        }

        @Test("Load returns nil for non-existent cache")
        func loadNonExistent() async throws {
            let cache = DiskCacheTests().makeTestCache()

            let result = try await cache.load(for: "non-existent")

            #expect(result == nil)
        }

        @Test("Save updates lastUpdated timestamp")
        func saveSetsTimestamp() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()
            let sourceId = "test-source"

            let before = Date()
            try await cache.save(entries, for: sourceId)
            let result = try await cache.load(for: sourceId)
            let after = Date()

            #expect(result != nil)
            #expect(result!.lastUpdated >= before)
            #expect(result!.lastUpdated <= after)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("Memory cache returns data without disk access")
        func memoryCache() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()
            let sourceId = "test-source"

            try await cache.save(entries, for: sourceId)

            // Second load should hit memory cache
            let result1 = try await cache.load(for: sourceId)
            let result2 = try await cache.load(for: sourceId)

            #expect(result1?.entries.count == result2?.entries.count)

            // Cleanup
            try await cache.clearAll()
        }
    }

    // MARK: - Clear Operations

    @Suite("Clear")
    struct Clear {
        @Test("Clear removes specific cache entry")
        func clearSpecific() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "source-a")
            try await cache.save(entries, for: "source-b")

            try await cache.clear(for: "source-a")

            let resultA = try await cache.load(for: "source-a")
            let resultB = try await cache.load(for: "source-b")

            #expect(resultA == nil)
            #expect(resultB != nil)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("ClearAll removes all cache entries")
        func clearAll() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "source-a")
            try await cache.save(entries, for: "source-b")

            try await cache.clearAll()

            let resultA = try await cache.load(for: "source-a")
            let resultB = try await cache.load(for: "source-b")

            #expect(resultA == nil)
            #expect(resultB == nil)
        }

        @Test("Clear non-existent entry does not throw")
        func clearNonExistent() async throws {
            let cache = DiskCacheTests().makeTestCache()

            // Should not throw
            try await cache.clear(for: "non-existent")
        }
    }

    // MARK: - Cache Expiry

    @Suite("Expiry")
    struct Expiry {
        @Test("isExpired returns true for missing cache")
        func expiredMissing() async {
            let cache = DiskCacheTests().makeTestCache()

            let expired = await cache.isExpired(for: "non-existent", maxAge: 3600)

            #expect(expired == true)
        }

        @Test("isExpired returns false for fresh cache")
        func notExpired() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "test-source")

            // Check with 1 hour max age
            let expired = await cache.isExpired(for: "test-source", maxAge: 3600)

            #expect(expired == false)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("clearExpired removes old entries")
        func clearExpired() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "test-source")

            // Clear with 0 max age (everything is expired)
            try await cache.clearExpired(maxAge: 0)

            let result = try await cache.load(for: "test-source")

            #expect(result == nil)
        }
    }

    // MARK: - Cache Management

    @Suite("Management")
    struct Management {
        @Test("listEntries returns all cached sources")
        func listEntries() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "source-a")
            try await cache.save(entries, for: "source-b")

            let list = await cache.listEntries()

            #expect(list.count == 2)
            let identifiers = list.map { $0.sourceIdentifier }
            #expect(identifiers.contains("source-a"))
            #expect(identifiers.contains("source-b"))

            // Cleanup
            try await cache.clearAll()
        }

        @Test("listEntries returns empty for no cache")
        func listEntriesEmpty() async {
            let cache = DiskCacheTests().makeTestCache()

            let list = await cache.listEntries()

            #expect(list.isEmpty)
        }

        @Test("totalSize returns combined size of all entries")
        func totalSize() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "source-a")
            try await cache.save(entries, for: "source-b")

            let size = await cache.totalSize()

            #expect(size > 0)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("CacheEntry contains correct metadata")
        func cacheEntryMetadata() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()

            try await cache.save(entries, for: "test-source")

            let list = await cache.listEntries()

            #expect(list.count == 1)
            let entry = list.first!
            #expect(entry.sourceIdentifier == "test-source")
            #expect(entry.emojiCount == 2)
            #expect(entry.fileSize > 0)
            #expect(entry.lastUpdated <= Date())

            // Cleanup
            try await cache.clearAll()
        }

        @Test("directoryURL returns cache directory")
        func directoryURL() async {
            let testDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("test-cache-dir")
            let cache = DiskCache(cacheDirectory: testDir)

            let dir = await cache.directoryURL
            #expect(dir == testDir)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCases {
        @Test("Empty entries array can be saved and loaded")
        func emptyEntries() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries: [EmojiRawEntry] = []

            try await cache.save(entries, for: "empty-source")
            let result = try await cache.load(for: "empty-source")

            #expect(result != nil)
            #expect(result?.entries.isEmpty == true)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("Source identifier with special characters")
        func specialCharacters() async throws {
            let cache = DiskCacheTests().makeTestCache()
            let entries = DiskCacheTests().sampleEntries()
            let sourceId = "test_source-v1.2"

            try await cache.save(entries, for: sourceId)
            let result = try await cache.load(for: sourceId)

            #expect(result != nil)
            #expect(result?.entries.count == 2)

            // Cleanup
            try await cache.clearAll()
        }

        @Test("Default initializer uses caches directory")
        func defaultInitializer() async {
            let cache = DiskCache()
            let dir = await cache.directoryURL

            #expect(dir.path.contains("SwiftEmojiIndex"))
        }

        @Test("Default initializer sets isUsingFallbackDirectory to false")
        func defaultNotUsingFallback() async {
            let cache = DiskCache()

            // In normal circumstances, caches directory should be available
            let isUsingFallback = await cache.isUsingFallbackDirectory
            #expect(isUsingFallback == false)
        }

        @Test("Custom directory initializer sets isUsingFallbackDirectory to false")
        func customNotUsingFallback() async {
            let testDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("custom-test")
            let cache = DiskCache(cacheDirectory: testDir)

            let isUsingFallback = await cache.isUsingFallbackDirectory
            #expect(isUsingFallback == false)
        }
    }
}
