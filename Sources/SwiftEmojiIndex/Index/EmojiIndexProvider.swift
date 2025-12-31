import Foundation
import Observation

/// Default emoji index provider with caching and search.
///
/// This class manages emoji data from a data source, provides caching,
/// and implements efficient searching.
///
/// ## Usage
///
/// ```swift
/// // Use the shared instance (localized, platform-optimal)
/// let emojis = try await EmojiIndexProvider.shared.allEmojis
/// let results = await EmojiIndexProvider.shared.search("smile")
///
/// // Custom locale
/// let provider = EmojiIndexProvider.recommended(locale: Locale(identifier: "ja"))
///
/// // Custom data source
/// let customIndex = EmojiIndexProvider(source: MyCustomDataSource())
/// ```
@Observable
public final class EmojiIndexProvider: EmojiIndexProtocol, @unchecked Sendable {
    /// Shared instance using the recommended data source for the current platform and locale.
    public static let shared = EmojiIndexProvider.recommended()

    // MARK: - Configuration

    private let source: any EmojiDataSource
    private let cache: any EmojiCache
    private let customFallbackURL: URL?

    // MARK: - State

    /// All loaded emojis.
    private var emojis: [Emoji] = []

    /// Emojis indexed by character for O(1) lookup.
    private var byCharacter: [String: Emoji] = [:]

    /// Emojis indexed by shortcode for O(1) lookup.
    private var byShortcode: [String: Emoji] = [:]

    /// Emojis organized by category.
    private var byCategory: [EmojiCategory: [Emoji]] = [:]

    /// The date when data was last updated.
    public private(set) var lastUpdated: Date?

    /// Whether the index has been loaded.
    public private(set) var isLoaded: Bool = false

    /// Diagnostic info about the last load operation.
    public private(set) var lastLoadInfo: LoadInfo?

    /// Lock for thread-safe access.
    private let lock = NSLock()

    // MARK: - Diagnostics

    /// Information about a load operation for debugging.
    public struct LoadInfo: Sendable {
        /// The data source identifier used.
        public let sourceIdentifier: String
        /// The data source display name.
        public let sourceDisplayName: String
        /// Where the data came from.
        public let loadedFrom: LoadSource
        /// Number of emoji loaded.
        public let emojiCount: Int
        /// Time taken to load.
        public let loadDuration: TimeInterval
        /// When the load completed.
        public let timestamp: Date

        public enum LoadSource: String, Sendable {
            case cache = "Cache"
            case fallback = "Bundled Fallback"
            case network = "Network"
        }
    }

    /// The data source identifier for this provider.
    public var sourceIdentifier: String { source.identifier }

    /// The data source display name for this provider.
    public var sourceDisplayName: String { source.displayName }

    // MARK: - Initialization

    /// Creates a new index provider with a specific data source.
    ///
    /// - Parameters:
    ///   - source: The data source to fetch emoji data from
    ///   - cache: The cache to use for storing data (default: DiskCache)
    ///   - fallbackURL: Optional custom fallback file URL. Must be a JSON file in `EmojiRawEntry` format.
    ///                  If nil, uses the bundled fallback. Run `swift run BuildEmojiIndex` to generate one.
    public init(
        source: any EmojiDataSource,
        cache: any EmojiCache = DiskCache.shared,
        fallbackURL: URL? = nil
    ) {
        self.source = source
        self.cache = cache
        self.customFallbackURL = fallbackURL
    }

    // MARK: - Factory Methods

    /// Creates an index with the recommended data source for the current platform and locale.
    ///
    /// This automatically selects the best data source:
    /// - **macOS**: Apple CoreEmoji (localized) + Gemoji (shortcodes)
    /// - **iOS/visionOS**: Unicode CLDR (localized) + Gemoji (shortcodes)
    ///
    /// - Parameter locale: The locale for emoji names (default: system locale)
    /// - Returns: A configured `EmojiIndexProvider`
    public static func recommended(locale: Locale = .current) -> EmojiIndexProvider {
        #if os(macOS)
        if AppleEmojiDataSource.isAvailable {
            return EmojiIndexProvider(source: BlendedEmojiDataSource(
                primary: AppleEmojiDataSource(locale: locale),
                secondary: GemojiDataSource.shared
            ))
        }
        #endif

        return EmojiIndexProvider(source: BlendedEmojiDataSource(
            primary: CLDREmojiDataSource(locale: locale),
            secondary: GemojiDataSource.shared
        ))
    }

    // MARK: - EmojiIndexProtocol

    public var allEmojis: [Emoji] {
        get async throws {
            try await ensureLoaded()
            return lock.withLock { emojis }
        }
    }

    public var categories: [EmojiCategory: [Emoji]] {
        get async throws {
            try await ensureLoaded()
            return lock.withLock { byCategory }
        }
    }

    public var isStale: Bool {
        get async {
            guard let lastUpdated = self.lastUpdated else {
                return true
            }
            return Date().timeIntervalSince(lastUpdated) > source.refreshInterval
        }
    }

    public func emoji(for character: String) async -> Emoji? {
        try? await ensureLoaded()
        return lock.withLock { byCharacter[character] }
    }

    public func emoji(forShortcode shortcode: String) async -> Emoji? {
        try? await ensureLoaded()
        let lowercased = shortcode.lowercased()
        return lock.withLock { byShortcode[lowercased] }
    }

    /// Search emoji by query.
    ///
    /// - Parameters:
    ///   - query: The search query
    ///   - ranking: How to rank results (default: `.relevance`)
    /// - Returns: Matching emoji
    ///
    /// For `.relevance` ranking:
    /// 1. Exact shortcode match (pinned to top)
    /// 2. Name contains query
    /// 3. Shortcode prefix match
    /// 4. Keyword prefix match
    public func search(_ query: String, ranking: SearchRanking = .relevance) async -> [Emoji] {
        try? await ensureLoaded()

        let query = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            let all = lock.withLock { emojis }
            return applyRanking(all, ranking: ranking)
        }

        return lock.withLock {
            var exactMatch: Emoji?
            var results: [Emoji] = []
            var seen = Set<String>()

            // Priority 1: Exact shortcode match (will be inserted at front)
            if let exact = byShortcode[query] {
                exactMatch = exact
                seen.insert(exact.character)
            }

            // Priority 2: Name contains query
            for emoji in emojis {
                guard !seen.contains(emoji.character) else { continue }
                if emoji.name.lowercased().contains(query) {
                    results.append(emoji)
                    seen.insert(emoji.character)
                }
            }

            // Priority 3: Shortcode prefix match
            for emoji in emojis {
                guard !seen.contains(emoji.character) else { continue }
                if emoji.shortcodes.contains(where: { $0.lowercased().hasPrefix(query) }) {
                    results.append(emoji)
                    seen.insert(emoji.character)
                }
            }

            // Priority 4: Keyword prefix match
            for emoji in emojis {
                guard !seen.contains(emoji.character) else { continue }
                if emoji.keywords.contains(where: { $0.lowercased().hasPrefix(query) }) {
                    results.append(emoji)
                    seen.insert(emoji.character)
                }
            }

            // Apply ranking
            results = applyRanking(results, ranking: ranking)

            // Insert exact match at front (always, regardless of ranking)
            if let exact = exactMatch {
                results.insert(exact, at: 0)
            }

            return results
        }
    }

    /// Apply ranking to emoji list.
    private func applyRanking(_ emojis: [Emoji], ranking: SearchRanking) -> [Emoji] {
        switch ranking {
        case .relevance:
            return emojis // Already in relevance order
        case .usage:
            let tracker = EmojiUsageTracker.shared
            return emojis.sorted { tracker.score(for: $0.character) > tracker.score(for: $1.character) }
        case .alphabetical:
            return emojis.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    /// Get favorite emoji based on usage history.
    ///
    /// Returns emoji objects for the user's most frequently/recently used emoji.
    public func favorites() async -> [Emoji] {
        try? await ensureLoaded()
        let favoriteChars = EmojiUsageTracker.shared.favorites
        return lock.withLock {
            favoriteChars.compactMap { byCharacter[$0] }
        }
    }

    public func refresh() async throws {
        let startTime = Date()
        let entries = try await source.fetch()
        try await cache.save(entries, for: source.identifier)
        await loadFromEntries(entries, source: .network, startTime: startTime)
    }

    // MARK: - Loading

    /// Ensures the index is loaded, loading from cache or source if needed.
    private func ensureLoaded() async throws {
        if lock.withLock({ isLoaded }) {
            return
        }

        let startTime = Date()

        // Try loading from cache first
        if let cached = try? await cache.load(for: source.identifier) {
            await loadFromEntries(cached.entries, source: .cache, startTime: startTime)
            lock.withLock {
                lastUpdated = cached.lastUpdated
            }

            // Refresh in background if stale
            if await isStale {
                Task {
                    try? await refresh()
                }
            }
            return
        }

        // Try loading from bundled fallback
        if let fallback = try? await loadBundledFallback() {
            await loadFromEntries(fallback, source: .fallback, startTime: startTime)

            // Fetch fresh data in background
            Task {
                try? await refresh()
            }
            return
        }

        // Fetch from source
        try await refresh()
    }

    /// Loads emoji data from raw entries.
    private func loadFromEntries(
        _ entries: [EmojiRawEntry],
        source loadSource: LoadInfo.LoadSource? = nil,
        startTime: Date? = nil
    ) async {
        var newEmojis: [Emoji] = []
        var newByCharacter: [String: Emoji] = [:]
        var newByShortcode: [String: Emoji] = [:]
        var newByCategory: [EmojiCategory: [Emoji]] = [:]

        for entry in entries {
            guard let emoji = entry.toEmoji() else { continue }

            newEmojis.append(emoji)
            newByCharacter[emoji.character] = emoji

            for shortcode in emoji.shortcodes {
                newByShortcode[shortcode.lowercased()] = emoji
            }

            newByCategory[emoji.category, default: []].append(emoji)
        }

        lock.withLock {
            emojis = newEmojis
            byCharacter = newByCharacter
            byShortcode = newByShortcode
            byCategory = newByCategory
            isLoaded = true
            if lastUpdated == nil {
                lastUpdated = Date()
            }

            // Record diagnostic info
            if let loadSource = loadSource {
                lastLoadInfo = LoadInfo(
                    sourceIdentifier: source.identifier,
                    sourceDisplayName: source.displayName,
                    loadedFrom: loadSource,
                    emojiCount: newEmojis.count,
                    loadDuration: startTime.map { Date().timeIntervalSince($0) } ?? 0,
                    timestamp: Date()
                )
            }
        }
    }

    /// Loads fallback emoji data from custom URL or bundled resource.
    ///
    /// Priority:
    /// 1. Custom fallback URL (if provided in init)
    /// 2. Bundled fallback resource
    ///
    /// The fallback must be in `EmojiRawEntry` JSON format.
    /// Run `swift run BuildEmojiIndex` to generate a compatible file.
    private func loadBundledFallback() async throws -> [EmojiRawEntry]? {
        // Try custom fallback first
        if let customURL = customFallbackURL {
            let data = try Data(contentsOf: customURL)
            return try JSONDecoder().decode([EmojiRawEntry].self, from: data)
        }

        // Fall back to bundled resource
        guard let url = Bundle.module.url(forResource: "emoji-fallback", withExtension: "json") else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([EmojiRawEntry].self, from: data)
    }

    // MARK: - Manual Loading

    /// Manually triggers loading of the emoji index.
    ///
    /// Normally, the index loads automatically on first access.
    /// Use this method to preload data.
    public func load() async throws {
        try await ensureLoaded()
    }

    /// Clears the cache and reloads from the source.
    public func clearCacheAndReload() async throws {
        try await cache.clear(for: source.identifier)
        lock.withLock {
            isLoaded = false
            emojis = []
            byCharacter = [:]
            byShortcode = [:]
            byCategory = [:]
            lastUpdated = nil
        }
        try await refresh()
    }
}
