import Foundation
import os.log

private let logger = Logger(subsystem: "SwiftEmojiIndex", category: "DiskCache")

/// Disk-based cache with an in-memory layer for emoji data.
///
/// Cache files are stored in the app's cache directory at:
/// `~/Library/Caches/[bundleID]/SwiftEmojiIndex/[sourceId].json`
///
/// The cache uses file modification dates to track when data was last updated.
public actor DiskCache: EmojiCache {
    /// Shared instance with default configuration.
    public static let shared = DiskCache()

    /// In-memory cache layer for fast access.
    private var memoryCache: [String: (entries: [EmojiRawEntry], lastUpdated: Date)] = [:]

    /// The base directory for cache files.
    private let cacheDirectory: URL

    /// Whether the cache is using a fallback directory.
    ///
    /// This is `true` when the caches directory was unavailable and the
    /// temporary directory is being used instead. Cache data in the temporary
    /// directory may be cleared by the system at any time.
    public let isUsingFallbackDirectory: Bool

    /// Creates a new disk cache with the default cache directory.
    ///
    /// Falls back to the temporary directory if the caches directory is unavailable,
    /// logging a warning when this occurs.
    public init() {
        let baseDir: URL
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            baseDir = cachesDir
            self.isUsingFallbackDirectory = false
        } else {
            baseDir = FileManager.default.temporaryDirectory
            self.isUsingFallbackDirectory = true
            logger.warning("Caches directory unavailable, using temporary directory for emoji cache. Cache may be cleared by system.")
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "SwiftEmoji"
        self.cacheDirectory = baseDir
            .appendingPathComponent(bundleId)
            .appendingPathComponent("SwiftEmojiIndex")
    }

    /// Creates a new disk cache with a custom cache directory.
    ///
    /// - Parameter cacheDirectory: The directory to store cache files
    public init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        self.isUsingFallbackDirectory = false
    }

    /// Returns the cache file URL for a given source identifier.
    private func cacheFileURL(for sourceIdentifier: String) -> URL {
        cacheDirectory.appendingPathComponent("\(sourceIdentifier).json")
    }

    /// Ensures the cache directory exists.
    private func ensureCacheDirectoryExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    // MARK: - EmojiCache

    public func load(for sourceIdentifier: String) async throws -> (entries: [EmojiRawEntry], lastUpdated: Date)? {
        // Check memory cache first
        if let cached = memoryCache[sourceIdentifier] {
            return cached
        }

        let fileURL = cacheFileURL(for: sourceIdentifier)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data: Data
        let attributes: [FileAttributeKey: Any]

        do {
            data = try Data(contentsOf: fileURL)
            attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw EmojiIndexError.cacheReadFailed(underlying: error)
        }

        let entries: [EmojiRawEntry]
        do {
            entries = try JSONDecoder().decode([EmojiRawEntry].self, from: data)
        } catch {
            throw EmojiIndexError.decodingFailed(underlying: error)
        }

        let lastUpdated = (attributes[.modificationDate] as? Date) ?? Date.distantPast

        // Update memory cache
        memoryCache[sourceIdentifier] = (entries, lastUpdated)

        return (entries, lastUpdated)
    }

    public func save(_ entries: [EmojiRawEntry], for sourceIdentifier: String) async throws {
        do {
            try ensureCacheDirectoryExists()
        } catch {
            throw EmojiIndexError.cacheWriteFailed(underlying: error)
        }

        let fileURL = cacheFileURL(for: sourceIdentifier)

        let data: Data
        do {
            data = try JSONEncoder().encode(entries)
        } catch {
            throw EmojiIndexError.cacheWriteFailed(underlying: error)
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw EmojiIndexError.cacheWriteFailed(underlying: error)
        }

        // Update memory cache
        memoryCache[sourceIdentifier] = (entries, Date())
    }

    public func clear(for sourceIdentifier: String) async throws {
        // Clear memory cache
        memoryCache.removeValue(forKey: sourceIdentifier)

        let fileURL = cacheFileURL(for: sourceIdentifier)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw EmojiIndexError.cacheWriteFailed(underlying: error)
        }
    }

    public func clearAll() async throws {
        // Clear memory cache
        memoryCache.removeAll()

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: cacheDirectory.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: cacheDirectory)
        } catch {
            throw EmojiIndexError.cacheWriteFailed(underlying: error)
        }
    }

    // MARK: - Cache Management

    /// Information about a cached entry.
    public struct CacheEntry: Sendable {
        public let sourceIdentifier: String
        public let fileSize: Int64
        public let lastUpdated: Date
        public let emojiCount: Int
    }

    /// Lists all cached entries with their metadata.
    public func listEntries() async -> [CacheEntry] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: cacheDirectory.path),
              let files = try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path) else {
            return []
        }

        var entries: [CacheEntry] = []

        for file in files where file.hasSuffix(".json") {
            let sourceId = String(file.dropLast(5)) // Remove .json
            let fileURL = cacheFileURL(for: sourceId)

            guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let size = attrs[.size] as? Int64,
                  let modDate = attrs[.modificationDate] as? Date else {
                continue
            }

            // Try to get emoji count from memory cache or decode
            let count: Int
            if let cached = memoryCache[sourceId] {
                count = cached.entries.count
            } else if let data = try? Data(contentsOf: fileURL),
                      let decoded = try? JSONDecoder().decode([EmojiRawEntry].self, from: data) {
                count = decoded.count
            } else {
                count = 0
            }

            entries.append(CacheEntry(
                sourceIdentifier: sourceId,
                fileSize: size,
                lastUpdated: modDate,
                emojiCount: count
            ))
        }

        return entries
    }

    /// Total size of all cached data in bytes.
    public func totalSize() async -> Int64 {
        let entries = await listEntries()
        return entries.reduce(0) { $0 + $1.fileSize }
    }

    /// Checks if a cache entry is older than the specified interval.
    public func isExpired(for sourceIdentifier: String, maxAge: TimeInterval) async -> Bool {
        let fileURL = cacheFileURL(for: sourceIdentifier)

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return true // No cache = expired
        }

        return Date().timeIntervalSince(modDate) > maxAge
    }

    /// Clears entries older than the specified interval.
    public func clearExpired(maxAge: TimeInterval) async throws {
        let entries = await listEntries()
        let now = Date()

        for entry in entries {
            if now.timeIntervalSince(entry.lastUpdated) > maxAge {
                try await clear(for: entry.sourceIdentifier)
            }
        }
    }

    /// The cache directory URL.
    public var directoryURL: URL {
        cacheDirectory
    }
}
