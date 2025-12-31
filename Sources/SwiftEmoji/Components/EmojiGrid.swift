import SwiftUI
import SwiftEmojiIndex

/// A grid view for displaying and selecting emojis.
///
/// `EmojiGrid` provides a flexible way to display emojis. The actual layout
/// is controlled entirely by the style - use `.emojiGridStyle()` to customize.
///
/// It does NOT include a ScrollView - you wrap it yourself for full control.
///
/// ## Selection Modes
///
/// ### Tap-only (no selection state)
/// ```swift
/// ScrollView {
///     EmojiGrid(emojis: emojis) { emoji in
///         canvas.add(emoji)
///         dismiss()
///     }
/// }
/// ```
///
/// ### Single selection
/// ```swift
/// ScrollView {
///     EmojiGrid(emojis: emojis, selection: $selected)
/// }
/// ```
///
/// ### Multiple selection
/// ```swift
/// ScrollView {
///     EmojiGrid(emojis: emojis, selection: $selectedSet)
/// }
/// ```
///
/// ## Styling
///
/// ```swift
/// EmojiGrid(emojis: emojis) { _ in }
///     .emojiGridStyle(LargeEmojiGridStyle())
/// ```
public struct EmojiGrid<Style: EmojiGridStyle>: View {
    private let emojis: [Emoji]
    private let style: Style
    private let onTap: ((Emoji) -> Void)?
    private let selectionMode: SelectionMode

    @Binding private var singleSelection: Emoji?
    @Binding private var multipleSelection: Set<String>

    private enum SelectionMode {
        case none
        case single
        case multiple
    }

    // MARK: - Tap-only Initializer

    /// Creates an emoji grid with tap-only interaction.
    public init(
        emojis: [Emoji],
        style: Style = DefaultEmojiGridStyle() as! Style,
        onTap: @escaping (Emoji) -> Void
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = onTap
        self.selectionMode = .none
        self._singleSelection = .constant(nil)
        self._multipleSelection = .constant([])
    }

    /// Creates an emoji grid with tap-only interaction and custom style.
    public init(
        emojis: [Emoji],
        style: Style,
        onTap: @escaping (Emoji) -> Void
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = onTap
        self.selectionMode = .none
        self._singleSelection = .constant(nil)
        self._multipleSelection = .constant([])
    }

    // MARK: - Single Selection Initializers

    /// Creates an emoji grid with single selection.
    public init(
        emojis: [Emoji],
        style: Style = DefaultEmojiGridStyle() as! Style,
        selection: Binding<Emoji?>
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = nil
        self.selectionMode = .single
        self._singleSelection = selection
        self._multipleSelection = .constant([])
    }

    /// Creates an emoji grid with single selection and custom style.
    public init(
        emojis: [Emoji],
        style: Style,
        selection: Binding<Emoji?>
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = nil
        self.selectionMode = .single
        self._singleSelection = selection
        self._multipleSelection = .constant([])
    }

    // MARK: - Multiple Selection Initializers

    /// Creates an emoji grid with multiple selection.
    public init(
        emojis: [Emoji],
        style: Style = DefaultEmojiGridStyle() as! Style,
        selection: Binding<Set<String>>
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = nil
        self.selectionMode = .multiple
        self._singleSelection = .constant(nil)
        self._multipleSelection = selection
    }

    /// Creates an emoji grid with multiple selection and custom style.
    public init(
        emojis: [Emoji],
        style: Style,
        selection: Binding<Set<String>>
    ) {
        self.emojis = emojis
        self.style = style
        self.onTap = nil
        self.selectionMode = .multiple
        self._singleSelection = .constant(nil)
        self._multipleSelection = selection
    }

    // MARK: - Body

    public var body: some View {
        style.makeGrid(configuration: GridConfiguration(
            emojis: emojis,
            selection: currentSelection,
            isSelectable: selectionMode != .none,
            isSelected: isEmojiSelected,
            onTap: handleTap
        ))
    }

    // MARK: - Private

    private var currentSelection: Set<String> {
        switch selectionMode {
        case .none:
            return []
        case .single:
            if let selected = singleSelection {
                return [selected.id]
            }
            return []
        case .multiple:
            return multipleSelection
        }
    }

    private func isEmojiSelected(_ emoji: Emoji) -> Bool {
        switch selectionMode {
        case .none:
            return false
        case .single:
            return singleSelection?.id == emoji.id
        case .multiple:
            return multipleSelection.contains(emoji.id)
        }
    }

    private func handleTap(_ emoji: Emoji) {
        switch selectionMode {
        case .none:
            onTap?(emoji)
        case .single:
            singleSelection = (singleSelection?.id == emoji.id) ? nil : emoji
        case .multiple:
            if multipleSelection.contains(emoji.id) {
                multipleSelection.remove(emoji.id)
            } else {
                multipleSelection.insert(emoji.id)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
private struct PreviewWrapper: View {
    @State private var singleSelection: Emoji?
    @State private var multipleSelection: Set<String> = []

    let sampleEmojis = [
        Emoji(character: "😀", name: "grinning face", category: .smileysAndEmotion),
        Emoji(character: "😂", name: "face with tears of joy", category: .smileysAndEmotion),
        Emoji(character: "🥹", name: "face holding back tears", category: .smileysAndEmotion),
        Emoji(character: "😍", name: "smiling face with heart-eyes", category: .smileysAndEmotion),
        Emoji(character: "🤔", name: "thinking face", category: .smileysAndEmotion),
        Emoji(character: "😎", name: "smiling face with sunglasses", category: .smileysAndEmotion),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Default style")
                    .font(.headline)
                EmojiGrid(emojis: sampleEmojis, selection: $singleSelection)

                Text("Large style")
                    .font(.headline)
                EmojiGrid(emojis: sampleEmojis, style: LargeEmojiGridStyle(), selection: $multipleSelection)

                Text("Compact style")
                    .font(.headline)
                ScrollView(.horizontal) {
                    EmojiGrid(emojis: sampleEmojis, style: CompactEmojiGridStyle()) { emoji in
                        print("Tapped: \(emoji.character)")
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    PreviewWrapper()
}
#endif
