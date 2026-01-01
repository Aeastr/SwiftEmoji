import Testing
import SwiftUI
@testable import SwiftEmoji
@testable import SwiftEmojiIndex

@Suite("EmojiGridStyle")
struct EmojiGridStyleTests {

    // MARK: - Pre-built Styles

    @Suite("Pre-built Styles")
    struct PrebuiltStyles {
        @Test("Default style exists and has expected cell size")
        @MainActor
        func defaultStyle() {
            let style = DefaultEmojiGridStyle.default
            #expect(style.cellSize == 44)
            #expect(style.spacing == 4)
        }

        @Test("Default style with custom parameters")
        @MainActor
        func defaultStyleCustom() {
            let style = DefaultEmojiGridStyle.default(cellSize: 60, spacing: 12)
            #expect(style.cellSize == 60)
            #expect(style.spacing == 12)
        }

        @Test("Default style with only cell size")
        @MainActor
        func defaultStyleCellSizeOnly() {
            let style = DefaultEmojiGridStyle.default(cellSize: 50)
            #expect(style.cellSize == 50)
            #expect(style.spacing == 4) // Default spacing
        }

        @Test("Large style can be created")
        @MainActor
        func largeStyle() {
            let style = LargeEmojiGridStyle.large
            _ = style
        }

        @Test("Compact style can be created")
        @MainActor
        func compactStyle() {
            let style = CompactEmojiGridStyle.compact
            _ = style
        }
    }

    // MARK: - DefaultEmojiGridStyle

    @Suite("DefaultEmojiGridStyle")
    struct DefaultStyleTests {
        @Test("Default initializer values")
        @MainActor
        func defaultValues() {
            let style = DefaultEmojiGridStyle()
            #expect(style.cellSize == 44)
            #expect(style.spacing == 4)
            #expect(style.columns == nil)
        }

        @Test("Custom initializer values")
        @MainActor
        func customValues() {
            let columns = [GridItem(.fixed(50))]
            let style = DefaultEmojiGridStyle(
                cellSize: 50,
                spacing: 8,
                columns: columns
            )

            #expect(style.cellSize == 50)
            #expect(style.spacing == 8)
            #expect(style.columns != nil)
            #expect(style.columns?.count == 1)
        }

        @Test("Custom columns override adaptive behavior")
        @MainActor
        func customColumnsOverride() {
            let columns = [GridItem(.fixed(60)), GridItem(.fixed(60))]
            let style = DefaultEmojiGridStyle(columns: columns)

            #expect(style.columns?.count == 2)
        }
    }

    // MARK: - LargeEmojiGridStyle

    @Test("LargeEmojiGridStyle initializer")
    @MainActor
    func largeStyleInit() {
        let style = LargeEmojiGridStyle()
        _ = style
    }

    // MARK: - CompactEmojiGridStyle

    @Test("CompactEmojiGridStyle initializer")
    @MainActor
    func compactStyleInit() {
        let style = CompactEmojiGridStyle()
        _ = style
    }
}

// MARK: - Configuration Tests

@Suite("Grid Configurations")
struct GridConfigurationTests {

    static let sampleEmoji = Emoji(
        character: "😀",
        name: "grinning face",
        category: .smileysAndEmotion
    )

    @Test("GridConfiguration initializes correctly")
    @MainActor
    func gridConfiguration() {
        let emojis = [Self.sampleEmoji]

        var tappedEmoji: Emoji?

        let config = GridConfiguration(
            emojis: emojis,
            selection: ["😀"],
            isSelectable: true,
            isSelected: { $0.character == "😀" },
            onTap: { tappedEmoji = $0 }
        )

        #expect(config.emojis.count == 1)
        #expect(config.selection.contains("😀"))
        #expect(config.isSelectable == true)
        #expect(config.isSelected(emojis[0]) == true)

        config.onTap(emojis[0])
        #expect(tappedEmoji?.character == "😀")
    }

    @Test("GridConfiguration with no selection")
    @MainActor
    func gridConfigurationNoSelection() {
        let emojis = [Self.sampleEmoji]

        let config = GridConfiguration(
            emojis: emojis,
            selection: [],
            isSelectable: false,
            isSelected: { _ in false },
            onTap: { _ in }
        )

        #expect(config.selection.isEmpty)
        #expect(config.isSelectable == false)
        #expect(config.isSelected(emojis[0]) == false)
    }

    @Test("CellConfiguration initializes correctly")
    @MainActor
    func cellConfiguration() {
        let emoji = Emoji(character: "🎉", name: "party", category: .activities)
        var tapped = false

        let config = CellConfiguration(
            emoji: emoji,
            isSelected: true,
            isSelectable: true,
            onTap: { tapped = true }
        )

        #expect(config.emoji.character == "🎉")
        #expect(config.isSelected == true)
        #expect(config.isSelectable == true)

        config.onTap()
        #expect(tapped == true)
    }

    @Test("CellConfiguration with unselected state")
    @MainActor
    func cellConfigurationUnselected() {
        let emoji = Emoji(character: "🔥", name: "fire", category: .travelAndPlaces)

        let config = CellConfiguration(
            emoji: emoji,
            isSelected: false,
            isSelectable: true,
            onTap: { }
        )

        #expect(config.emoji.character == "🔥")
        #expect(config.isSelected == false)
        #expect(config.isSelectable == true)
    }

    @Test("HeaderConfiguration initializes correctly")
    func headerConfiguration() {
        let config = HeaderConfiguration(category: .smileysAndEmotion)
        #expect(config.category == .smileysAndEmotion)
    }

    @Test("HeaderConfiguration with all categories", arguments: EmojiCategory.allCases)
    func headerConfigurationAllCategories(category: EmojiCategory) {
        let config = HeaderConfiguration(category: category)
        #expect(config.category == category)
    }
}
