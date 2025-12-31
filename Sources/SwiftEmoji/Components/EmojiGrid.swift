import SwiftUI
import SwiftEmojiIndex

/// A grid view for displaying and selecting emojis.
///
/// `EmojiGrid` provides a flexible way to display emojis. The layout
/// is controlled by the style - use `.emojiGridStyle()` to customize.
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
/// EmojiGrid(emojis: emojis, selection: $selected)
///     .emojiGridStyle(LargeEmojiGridStyle())
/// ```
public struct EmojiGrid: View {
    private let emojis: [Emoji]
    private let onTap: ((Emoji) -> Void)?
    private let selectionMode: SelectionMode

    @Binding private var singleSelection: Emoji?
    @Binding private var multipleSelection: Set<String>

    @Environment(\.emojiGridStyle) private var style

    private enum SelectionMode {
        case none
        case single
        case multiple
    }

    // MARK: - Tap-only

    /// Creates an emoji grid with tap-only interaction.
    public init(
        emojis: [Emoji],
        onTap: @escaping (Emoji) -> Void
    ) {
        self.emojis = emojis
        self.onTap = onTap
        self.selectionMode = .none
        self._singleSelection = .constant(nil)
        self._multipleSelection = .constant([])
    }

    // MARK: - Single Selection

    /// Creates an emoji grid with single selection.
    public init(
        emojis: [Emoji],
        selection: Binding<Emoji?>
    ) {
        self.emojis = emojis
        self.onTap = nil
        self.selectionMode = .single
        self._singleSelection = selection
        self._multipleSelection = .constant([])
    }

    // MARK: - Multiple Selection

    /// Creates an emoji grid with multiple selection.
    public init(
        emojis: [Emoji],
        selection: Binding<Set<String>>
    ) {
        self.emojis = emojis
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

// MARK: - Environment

/// Type-erased wrapper for EmojiGridStyle.
struct AnyEmojiGridStyle: @unchecked Sendable {
    private let _makeGrid: @MainActor (GridConfiguration) -> AnyView
    private let _makeCell: @MainActor (CellConfiguration) -> AnyView
    private let _makeSectionHeader: @MainActor (HeaderConfiguration) -> AnyView

    init<S: EmojiGridStyle>(_ style: S) {
        _makeGrid = { @MainActor in AnyView(style.makeGrid(configuration: $0)) }
        _makeCell = { @MainActor in AnyView(style.makeCell(configuration: $0)) }
        _makeSectionHeader = { @MainActor in AnyView(style.makeSectionHeader(configuration: $0)) }
    }

    @MainActor
    func makeGrid(configuration: GridConfiguration) -> AnyView {
        _makeGrid(configuration)
    }

    @MainActor
    func makeCell(configuration: CellConfiguration) -> AnyView {
        _makeCell(configuration)
    }

    @MainActor
    func makeSectionHeader(configuration: HeaderConfiguration) -> AnyView {
        _makeSectionHeader(configuration)
    }
}

private struct EmojiGridStyleKey: EnvironmentKey {
    static let defaultValue = AnyEmojiGridStyle(DefaultEmojiGridStyle())
}

extension EnvironmentValues {
    var emojiGridStyle: AnyEmojiGridStyle {
        get { self[EmojiGridStyleKey.self] }
        set { self[EmojiGridStyleKey.self] = newValue }
    }
}

extension View {
    /// Sets the style for emoji grids within this view.
    public func emojiGridStyle<S: EmojiGridStyle>(_ style: S) -> some View {
        environment(\.emojiGridStyle, AnyEmojiGridStyle(style))
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var singleSelection: Emoji?
    @Previewable @State var multipleSelection: Set<String> = []

    let sampleEmojis = [
        Emoji(character: "😀", name: "grinning face", category: .smileysAndEmotion),
        Emoji(character: "😂", name: "face with tears of joy", category: .smileysAndEmotion),
        Emoji(character: "🥹", name: "face holding back tears", category: .smileysAndEmotion),
        Emoji(character: "😍", name: "smiling face with heart-eyes", category: .smileysAndEmotion),
        Emoji(character: "🤔", name: "thinking face", category: .smileysAndEmotion),
        Emoji(character: "😎", name: "smiling face with sunglasses", category: .smileysAndEmotion),
    ]

    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Text("Default style")
                .font(.headline)
            EmojiGrid(emojis: sampleEmojis, selection: $singleSelection)

            Text("Large style")
                .font(.headline)
            EmojiGrid(emojis: sampleEmojis, selection: $multipleSelection)
                .emojiGridStyle(.large)

            Text("Compact style")
                .font(.headline)
            ScrollView(.horizontal) {
                EmojiGrid(emojis: sampleEmojis) { emoji in
                    print("Tapped: \(emoji.character)")
                }
                .emojiGridStyle(.compact)
            }
        }
        .padding()
    }
}
