import Testing
import Foundation
@testable import SwiftEmojiIndex

@Suite("EmojiUsageTracker")
struct EmojiUsageTrackerTests {

    /// Creates a tracker with a unique storage key for test isolation
    func makeIsolatedTracker() -> EmojiUsageTracker {
        let uniqueKey = "test.\(UUID().uuidString)"
        let tracker = EmojiUsageTracker(storageKey: uniqueKey)
        tracker.defaultEmoji = [] // Disable default seeding for clean tests
        tracker.clearAll()
        return tracker
    }

    // MARK: - Shared Instance

    @Test("shared singleton exists")
    func sharedInstance() {
        let shared1 = EmojiUsageTracker.shared
        let shared2 = EmojiUsageTracker.shared
        #expect(shared1 === shared2)
    }

    // MARK: - Recording Usage

    @Suite("recordUse")
    struct RecordUse {
        @Test("Recording use increases score")
        func increasesScore() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            let initialScore = tracker.score(for: "😀")
            tracker.recordUse("😀")
            let newScore = tracker.score(for: "😀")

            #expect(newScore > initialScore)
        }

        @Test("Multiple uses increase score")
        func multipleUsesIncreaseScore() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            tracker.recordUse("🎉")
            let score1 = tracker.score(for: "🎉")

            tracker.recordUse("🎉")
            let score2 = tracker.score(for: "🎉")

            #expect(score2 > score1)
        }

        @Test("Does nothing when isEnabled is false")
        func respectsIsEnabled() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            tracker.isEnabled = false

            tracker.recordUse("😀")
            let score = tracker.score(for: "😀")

            #expect(score == 0)
        }

        @Test("Recording different emoji still affects first")
        func recordingDifferentEmoji() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            tracker.recordUse("😀")
            let score1 = tracker.score(for: "😀")

            tracker.recordUse("🎉")
            let score2 = tracker.score(for: "😀")

            // Score should decrease due to decay
            #expect(score2 < score1)
        }
    }

    // MARK: - Score

    @Suite("score(for:)")
    struct Score {
        @Test("Returns 0 for unused emoji")
        func unusedEmoji() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            #expect(tracker.score(for: "🦄") == 0)
        }

        @Test("Returns positive score for used emoji")
        func usedEmoji() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            tracker.recordUse("👍")
            #expect(tracker.score(for: "👍") > 0)
        }

        @Test("Score is 1 after first use")
        func firstUseScore() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            tracker.recordUse("😀")
            #expect(tracker.score(for: "😀") == 1)
        }
    }

    // MARK: - Favorites

    @Suite("favorites")
    struct Favorites {
        @Test("Returns empty array when isEnabled is false")
        func emptyWhenDisabled() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            tracker.recordUse("😀")
            tracker.isEnabled = false

            #expect(tracker.favorites.isEmpty)
        }

        @Test("Returns used emoji sorted by score")
        func sortedByScore() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            // Use 😀 once
            tracker.recordUse("😀")

            // Use 🎉 three more times (total more score)
            tracker.recordUse("🎉")
            tracker.recordUse("🎉")
            tracker.recordUse("🎉")

            let favorites = tracker.favorites

            #expect(favorites.count == 2)
            #expect(favorites.first == "🎉")
        }

        @Test("Respects maxFavorites limit")
        func respectsMaxFavorites() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()
            tracker.maxFavorites = 3

            // Use 5 different emoji
            for emoji in ["😀", "😂", "🎉", "🔥", "✨"] {
                tracker.recordUse(emoji)
            }

            #expect(tracker.favorites.count <= 3)
        }

        @Test("Returns emoji in correct order")
        func correctOrder() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            tracker.recordUse("🥇")
            tracker.recordUse("🥇")
            tracker.recordUse("🥇")
            tracker.recordUse("🥈")
            tracker.recordUse("🥈")
            tracker.recordUse("🥉")

            let favorites = tracker.favorites

            #expect(favorites.count == 3)
            #expect(favorites[0] == "🥇")
            #expect(favorites[1] == "🥈")
            #expect(favorites[2] == "🥉")
        }
    }

    // MARK: - Configuration

    @Test("Configuration properties are settable")
    func configurableProperties() {
        let tracker = makeIsolatedTracker()

        tracker.isEnabled = false
        #expect(tracker.isEnabled == false)

        tracker.minFavorites = 5
        #expect(tracker.minFavorites == 5)

        tracker.maxFavorites = 30
        #expect(tracker.maxFavorites == 30)

        tracker.decayFactor = 0.8
        #expect(tracker.decayFactor == 0.8)

        tracker.pruneThreshold = 0.05
        #expect(tracker.pruneThreshold == 0.05)
    }

    @Test("Default configuration values")
    func defaultConfiguration() {
        let tracker = EmojiUsageTracker(storageKey: "test.\(UUID().uuidString)")

        #expect(tracker.isEnabled == true)
        #expect(tracker.minFavorites == 10)
        #expect(tracker.maxFavorites == 24)
        #expect(tracker.decayFactor == 0.9)
        #expect(tracker.pruneThreshold == 0.01)
    }

    // MARK: - Clearing

    @Suite("Clearing")
    struct Clearing {
        @Test("clearScore removes specific emoji")
        func clearSpecificScore() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            tracker.recordUse("😀")
            tracker.recordUse("🎉")

            tracker.clearScore(for: "😀")

            #expect(tracker.score(for: "😀") == 0)
            #expect(tracker.score(for: "🎉") > 0)
        }

        @Test("clearAll removes all scores")
        func clearAll() {
            let tracker = EmojiUsageTrackerTests().makeIsolatedTracker()

            tracker.recordUse("😀")
            tracker.recordUse("🎉")

            tracker.clearAll()

            #expect(tracker.score(for: "😀") == 0)
            #expect(tracker.score(for: "🎉") == 0)
            #expect(tracker.favorites.isEmpty)
        }
    }

    // MARK: - Decay

    @Test("Decay factor reduces existing scores on new use")
    func decayReducesScores() {
        let tracker = makeIsolatedTracker()
        tracker.decayFactor = 0.5

        tracker.recordUse("😀")
        let initialScore = tracker.score(for: "😀")

        // Using a different emoji triggers decay on the first
        tracker.recordUse("🎉")
        let decayedScore = tracker.score(for: "😀")

        #expect(decayedScore < initialScore)
        #expect(decayedScore == initialScore * 0.5)
    }

    // MARK: - hasFavorites

    @Test("hasFavorites reflects state correctly")
    func hasFavorites() {
        let tracker = makeIsolatedTracker()

        #expect(tracker.hasFavorites == false)

        tracker.recordUse("😀")
        #expect(tracker.hasFavorites == true)
    }

    // MARK: - allScores

    @Test("allScores returns dictionary of scores")
    func allScores() {
        let tracker = makeIsolatedTracker()

        tracker.recordUse("😀")
        tracker.recordUse("🎉")

        let scores = tracker.allScores

        #expect(scores.count == 2)
        #expect(scores["😀"] != nil)
        #expect(scores["🎉"] != nil)
    }

    @Test("allScores is empty initially")
    func allScoresEmpty() {
        let tracker = makeIsolatedTracker()
        #expect(tracker.allScores.isEmpty)
    }
}
