import Testing
import SwiftUI
@testable import SwiftEmoji
@testable import SwiftEmojiIndex

@Suite("EmojiGrid")
struct EmojiGridTests {

    static let sampleEmojis = [
        Emoji(character: "😀", name: "grinning face", category: .smileysAndEmotion),
        Emoji(character: "😂", name: "face with tears of joy", category: .smileysAndEmotion),
        Emoji(character: "🎉", name: "party popper", category: .activities),
    ]

    // MARK: - Initialization Modes

    @Suite("Initialization")
    struct Initialization {
        @Test("Tap-only mode initializes correctly")
        @MainActor
        func tapOnlyMode() {
            var tappedEmoji: Emoji?

            let grid = EmojiGrid(emojis: EmojiGridTests.sampleEmojis) { emoji in
                tappedEmoji = emoji
            }

            _ = grid
            #expect(tappedEmoji == nil) // Not tapped yet
        }

        @Test("Single selection mode initializes correctly")
        @MainActor
        func singleSelectionMode() {
            var selection: Emoji? = nil

            let grid = EmojiGrid(
                emojis: EmojiGridTests.sampleEmojis,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
        }

        @Test("Multiple selection mode initializes correctly")
        @MainActor
        func multipleSelectionMode() {
            var selection: Set<String> = []

            let grid = EmojiGrid(
                emojis: EmojiGridTests.sampleEmojis,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
        }

        @Test("Single selection with pre-selected value")
        @MainActor
        func singleSelectionPreselected() {
            var selection: Emoji? = EmojiGridTests.sampleEmojis[0]

            let grid = EmojiGrid(
                emojis: EmojiGridTests.sampleEmojis,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
            #expect(selection?.character == "😀")
        }

        @Test("Multiple selection with pre-selected values")
        @MainActor
        func multipleSelectionPreselected() {
            var selection: Set<String> = ["😀", "🎉"]

            let grid = EmojiGrid(
                emojis: EmojiGridTests.sampleEmojis,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
            #expect(selection.count == 2)
            #expect(selection.contains("😀"))
            #expect(selection.contains("🎉"))
        }
    }

    // MARK: - Empty State

    @Suite("Empty State")
    struct EmptyState {
        @Test("Handles empty emoji array in tap mode")
        @MainActor
        func emptyEmojisTapMode() {
            var tappedEmoji: Emoji?

            let grid = EmojiGrid(emojis: []) { emoji in
                tappedEmoji = emoji
            }

            _ = grid
            #expect(tappedEmoji == nil)
        }

        @Test("Handles empty emoji array in single selection mode")
        @MainActor
        func emptyEmojisSingleSelection() {
            var selection: Emoji? = nil

            let grid = EmojiGrid(
                emojis: [],
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
        }

        @Test("Handles empty emoji array in multiple selection mode")
        @MainActor
        func emptyEmojisMultipleSelection() {
            var selection: Set<String> = []

            let grid = EmojiGrid(
                emojis: [],
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                )
            )

            _ = grid
            #expect(selection.isEmpty)
        }
    }

    // MARK: - Large Data Sets

    @Test("Handles large emoji array")
    @MainActor
    func largeEmojiArray() {
        let manyEmojis = (0..<1000).map { i in
            Emoji(character: "😀", name: "emoji \(i)", category: .smileysAndEmotion)
        }

        let grid = EmojiGrid(emojis: manyEmojis) { _ in }

        _ = grid
    }
}

// MARK: - View Modifier Tests

@Suite("EmojiGrid Modifiers")
struct EmojiGridModifierTests {

    static let sampleEmojis = [
        Emoji(character: "😀", name: "grinning", category: .smileysAndEmotion)
    ]

    @Test("emojiGridStyle modifier can be applied with default")
    @MainActor
    func styleModifierDefault() {
        let grid = EmojiGrid(emojis: Self.sampleEmojis) { _ in }
            .emojiGridStyle(.default)

        _ = grid
    }

    @Test("emojiGridStyle modifier can be applied with compact")
    @MainActor
    func styleModifierCompact() {
        let grid = EmojiGrid(emojis: Self.sampleEmojis) { _ in }
            .emojiGridStyle(.compact)

        _ = grid
    }

    @Test("emojiGridStyle modifier can be applied with large")
    @MainActor
    func styleModifierLarge() {
        let grid = EmojiGrid(emojis: Self.sampleEmojis) { _ in }
            .emojiGridStyle(.large)

        _ = grid
    }

    @Test("emojiGridStyle modifier can be applied with custom")
    @MainActor
    func styleModifierCustom() {
        let grid = EmojiGrid(emojis: Self.sampleEmojis) { _ in }
            .emojiGridStyle(.default(cellSize: 60, spacing: 12))

        _ = grid
    }

    @Test("Multiple style modifiers compile correctly")
    @MainActor
    func nestedStyleModifiers() {
        let grid = EmojiGrid(emojis: Self.sampleEmojis) { _ in }
            .emojiGridStyle(.large)
            .emojiGridStyle(.compact)

        _ = grid
    }

    @Test("Style modifier works with single selection")
    @MainActor
    func styleModifierSingleSelection() {
        var selection: Emoji? = nil

        let grid = EmojiGrid(
            emojis: Self.sampleEmojis,
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            )
        )
        .emojiGridStyle(.large)

        _ = grid
    }

    @Test("Style modifier works with multiple selection")
    @MainActor
    func styleModifierMultipleSelection() {
        var selection: Set<String> = []

        let grid = EmojiGrid(
            emojis: Self.sampleEmojis,
            selection: Binding(
                get: { selection },
                set: { selection = $0 }
            )
        )
        .emojiGridStyle(.compact)

        _ = grid
    }
}

// MARK: - Custom Style Tests

@Suite("Custom Styles")
struct CustomStyleTests {

    @Test("Custom style can be created")
    @MainActor
    func customStyleCreation() {
        let customStyle = DefaultEmojiGridStyle(
            cellSize: 80,
            spacing: 16,
            columns: [GridItem(.fixed(80)), GridItem(.fixed(80)), GridItem(.fixed(80))]
        )

        #expect(customStyle.cellSize == 80)
        #expect(customStyle.spacing == 16)
        #expect(customStyle.columns?.count == 3)
    }

    @Test("Custom style can be applied to grid")
    @MainActor
    func customStyleApplied() {
        let customStyle = DefaultEmojiGridStyle(cellSize: 100, spacing: 20)

        let emojis = [
            Emoji(character: "😀", name: "grinning", category: .smileysAndEmotion)
        ]

        let grid = EmojiGrid(emojis: emojis) { _ in }
            .emojiGridStyle(customStyle)

        _ = grid
    }
}
