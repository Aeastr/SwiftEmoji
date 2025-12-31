import Foundation
import Observation

/// Tracks emoji usage with exponential moving average for smart favorites and search ranking.
///
/// Each time an emoji is used, all scores decay and the used emoji gets a boost.
/// This naturally surfaces frequently and recently used emoji.
///
/// ## Usage
///
/// ```swift
/// // Record usage
/// EmojiUsageTracker.shared.recordUse("😀")
///
/// // Get favorites
/// let favorites = EmojiUsageTracker.shared.favorites
///
/// // Get score for search ranking
/// let score = EmojiUsageTracker.shared.score(for: "😀")
/// ```
@Observable
public final class EmojiUsageTracker: @unchecked Sendable {
    /// Shared instance using UserDefaults storage.
    public static let shared = EmojiUsageTracker()

    // MARK: - Configuration

    /// Minimum number of favorites to keep even with low scores.
    public var minFavorites: Int = 10

    /// Maximum number of favorites to return.
    public var maxFavorites: Int = 24

    /// Decay factor applied to all scores on each use (0.0-1.0).
    /// Lower values = faster decay = more emphasis on recent usage.
    public var decayFactor: Double = 0.9

    /// Threshold below which scores are pruned.
    public var pruneThreshold: Double = 0.01

    /// Default emoji for new users (seeded with tiny scores).
    public var defaultEmoji: [String] = ["👍", "❤️", "😂", "🔥", "✨", "🙏", "💀", "👀", "🎉", "💯"]

    // MARK: - State

    /// Emoji character -> score (higher = more used recently)
    private var scores: [String: Double] = [:]

    /// Lock for thread-safe access.
    private let lock = NSLock()

    /// Storage key for UserDefaults.
    private let storageKey: String

    // MARK: - Initialization

    /// Creates a tracker with custom storage key.
    ///
    /// - Parameter storageKey: The UserDefaults key for persisting scores.
    public init(storageKey: String = "SwiftEmojiIndex.usageScores") {
        self.storageKey = storageKey
        loadScores()
        seedDefaultsIfNeeded()
    }

    // MARK: - Public API

    /// Record an emoji being used.
    ///
    /// This decays all scores and boosts the used emoji.
    public func recordUse(_ emoji: String) {
        lock.withLock {
            applyDecay()
            scores[emoji, default: 0] += 1
        }
        saveScores()
    }

    /// Get usage score for a specific emoji.
    ///
    /// Use this for search ranking - higher scores should appear first.
    public func score(for emoji: String) -> Double {
        lock.withLock { scores[emoji] ?? 0 }
    }

    /// Get all scores (for custom ranking implementations).
    public var allScores: [String: Double] {
        lock.withLock { scores }
    }

    /// Get favorite emoji characters sorted by score (highest first).
    public var favorites: [String] {
        lock.withLock {
            scores
                .filter { $0.value > pruneThreshold }
                .sorted { $0.value > $1.value }
                .prefix(maxFavorites)
                .map { $0.key }
        }
    }

    /// Whether there are any recorded favorites.
    public var hasFavorites: Bool {
        lock.withLock { !scores.isEmpty }
    }

    /// Clear score for a specific emoji (remove from favorites).
    public func clearScore(for emoji: String) {
        lock.withLock {
            scores.removeValue(forKey: emoji)
        }
        saveScores()
    }

    /// Clear all usage history.
    public func clearAll() {
        lock.withLock {
            scores = [:]
        }
        saveScores()
        seedDefaultsIfNeeded()
    }

    // MARK: - Private

    /// Apply decay to all scores.
    /// Keeps at least minFavorites emoji even if scores are low.
    private func applyDecay() {
        // Decay all scores
        for (emoji, score) in scores {
            scores[emoji] = score * decayFactor
        }

        // Only prune if we have more than minFavorites
        guard scores.count > minFavorites else { return }

        // Sort by score and keep at least minFavorites
        let sorted = scores.sorted { $0.value > $1.value }
        let toKeep = Set(sorted.prefix(minFavorites).map { $0.key })

        // Remove low scores, but only if not in the top minFavorites
        for (emoji, score) in scores {
            if score < pruneThreshold && !toKeep.contains(emoji) {
                scores.removeValue(forKey: emoji)
            }
        }
    }

    /// Seed default emoji with tiny scores for new users.
    private func seedDefaultsIfNeeded() {
        lock.withLock {
            guard scores.isEmpty else { return }
            for emoji in defaultEmoji {
                scores[emoji] = pruneThreshold * 2 // Just above prune threshold
            }
        }
        saveScores()
    }

    private func loadScores() {
        if let data = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] {
            lock.withLock {
                scores = data
            }
        }
    }

    private func saveScores() {
        let toSave = lock.withLock { scores }
        UserDefaults.standard.set(toSave, forKey: storageKey)
    }
}
