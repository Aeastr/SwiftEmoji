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

#Preview("Searchable Picker") {
    @Previewable @State var searchText = ""
    @Previewable @State var emojis: [Emoji] = []
    @Previewable @State var favorites: [Emoji] = []
    @Previewable @State var searchResults: [Emoji] = []
    @Previewable @State var selected: Emoji?

    NavigationStack {
        ScrollView {
            // Show favorites when not searching
            if searchText.isEmpty && !favorites.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frequently Used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        EmojiGrid(emojis: favorites) { emoji in
                            EmojiUsageTracker.shared.recordUse(emoji.character)
                            selected = emoji
                        }
                        .emojiGridStyle(.compact)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }

            EmojiGrid(emojis: searchText.isEmpty ? emojis : searchResults) { emoji in
                EmojiUsageTracker.shared.recordUse(emoji.character)
                selected = emoji
            }
            .padding(.horizontal)
        }
        .navigationTitle("Emoji")
        .searchable(text: $searchText, prompt: "Search emoji")
        .onChange(of: searchText) { _, query in
            Task {
                if query.isEmpty {
                    searchResults = []
                } else {
                    searchResults = await EmojiIndexProvider.shared.search(query, ranking: .usage)
                }
            }
        }
        .task {
            emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
            favorites = await EmojiIndexProvider.shared.favorites()
        }
        .overlay {
            if let selected {
                Text("Selected: \(selected.character)")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding()
            }
        }
    }
}

#Preview("Single Selection") {
    @Previewable @State var selected: Emoji?
    @Previewable @State var emojis: [Emoji] = []

    NavigationStack {
        ScrollView {
            EmojiGrid(emojis: emojis, selection: $selected)
                .padding(.horizontal)
        }
        .navigationTitle("Pick One")
        .task {
            emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
        }
        .toolbar {
            if let selected {
                Text(selected.character)
            }
        }
    }
}

#Preview("Multiple Selection") {
    @Previewable @State var selected: Set<String> = []
    @Previewable @State var emojis: [Emoji] = []

    NavigationStack {
        ScrollView {
            EmojiGrid(emojis: emojis, selection: $selected)
                .emojiGridStyle(.large)
                .padding(.horizontal)
        }
        .navigationTitle("Favorites")
        .task {
            emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
        }
        .toolbar {
            Text("\(selected.count) selected")
        }
    }
}

#Preview("Compact Horizontal") {
    @Previewable @State var emojis: [Emoji] = []

    VStack(alignment: .leading, spacing: 16) {
        Text("Recent")
            .font(.headline)
            .padding(.horizontal)

        ScrollView(.horizontal, showsIndicators: false) {
            EmojiGrid(emojis: Array(emojis.prefix(20))) { emoji in
                print("Tapped: \(emoji.character)")
            }
            .emojiGridStyle(.compact)
            .padding(.horizontal)
        }

        Spacer()
    }
    .padding(.top)
    .task {
        emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
    }
}

#Preview("Styles") {
    @Previewable @State var selected: Emoji?

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
            Text("Default")
                .font(.headline)
            EmojiGrid(emojis: sampleEmojis, selection: $selected)

            Text("Large")
                .font(.headline)
            EmojiGrid(emojis: sampleEmojis, selection: $selected)
                .emojiGridStyle(.large)

            Text("Compact")
                .font(.headline)
            ScrollView(.horizontal) {
                EmojiGrid(emojis: sampleEmojis, selection: $selected)
                    .emojiGridStyle(.compact)
            }

            Text("Custom Size")
                .font(.headline)
            EmojiGrid(emojis: sampleEmojis, selection: $selected)
                .emojiGridStyle(.default(cellSize: 60, spacing: 12))
        }
        .padding()
    }
}

#Preview("Localization") {
    @Previewable @State var availableLocales: [Locale] = []
    @Previewable @State var showDiagnostics = true

    // Single provider instance - observe it directly
    let provider = EmojiIndexProvider.shared

    NavigationStack {
        List {
            // Diagnostics section
            if showDiagnostics, let info = provider.lastLoadInfo {
                Section("Diagnostics") {
                    LabeledContent("Locale", value: provider.locale.identifier)
                    LabeledContent("Source ID", value: info.sourceIdentifier)
                    LabeledContent("Source", value: info.sourceDisplayName)
                    LabeledContent("Loaded From", value: info.loadedFrom.rawValue)
                    LabeledContent("Emoji Count", value: "\(info.emojiCount)")
                    LabeledContent("Load Time", value: String(format: "%.2fs", info.loadDuration))
                }
                .font(.caption)
            }

            // Emoji list - directly observe provider.currentEmojis
            Section("Emoji (First 50)") {
                ForEach(provider.currentEmojis.prefix(50)) { emoji in
                    HStack {
                        Text(emoji.character)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(emoji.name)
                            if !emoji.shortcodes.isEmpty {
                                Text(":\(emoji.shortcodes.first ?? ""):")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .opacity(provider.isLoading ? 0.5 : 1)
        }
        .navigationTitle(provider.locale.identifier.uppercased())
        .overlay {
            if provider.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading \(provider.locale.identifier) emoji...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Menu {
                    ForEach(availableLocales, id: \.identifier) { locale in
                        Button {
                            Task {
                                await provider.setLocale(locale)
                            }
                        } label: {
                            HStack {
                                Text(locale.localizedDisplayName)
                                if locale.identifier == provider.locale.identifier {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(availableLocales.isEmpty ? "Loading..." : provider.locale.identifier.uppercased())
                        Image(systemName: "chevron.down")
                    }
                }
                .disabled(provider.isLoading || availableLocales.isEmpty)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Show Diagnostics", isOn: $showDiagnostics)

                    Divider()

                    Button("Clear All Caches", role: .destructive) {
                        Task {
                            try? await DiskCache.shared.clearAll()
                            try? await provider.clearCacheAndReload()
                        }
                    }

                    Button("Force Refresh") {
                        Task {
                            try? await provider.refresh()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            // Fetch available locales
            availableLocales = await EmojiLocaleManager.shared.fetchAvailableLocales()
            // Trigger initial load
            try? await provider.load()
        }
    }
}

#Preview("Usage Tracker") {
    @Previewable @State var emojis: [Emoji] = []
    @Previewable @State var favorites: [Emoji] = []

    let tracker = EmojiUsageTracker.shared

    NavigationStack {
        List {
            Section("Settings") {
                Stepper("Min Favorites: \(tracker.minFavorites)", value: Binding(
                    get: { tracker.minFavorites },
                    set: { tracker.minFavorites = $0 }
                ), in: 1...20)

                Stepper("Max Favorites: \(tracker.maxFavorites)", value: Binding(
                    get: { tracker.maxFavorites },
                    set: { tracker.maxFavorites = $0 }
                ), in: 10...50)

                Button("Clear All Usage") {
                    tracker.clearAll()
                    Task {
                        favorites = await EmojiIndexProvider.shared.favorites()
                    }
                }
                .foregroundStyle(.red)
            }

            Section("Favorites (\(favorites.count))") {
                if favorites.isEmpty {
                    Text("Tap emoji below to add favorites")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(favorites) { emoji in
                                VStack {
                                    Text(emoji.character)
                                        .font(.title)
                                    Text(String(format: "%.1f", tracker.score(for: emoji.character)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Tap to Use") {
                ScrollView(.horizontal, showsIndicators: false) {
                    EmojiGrid(emojis: Array(emojis.prefix(30))) { emoji in
                        tracker.recordUse(emoji.character)
                        Task {
                            favorites = await EmojiIndexProvider.shared.favorites()
                        }
                    }
                    .emojiGridStyle(.compact)
                }
            }
        }
        .navigationTitle("Usage Tracker")
        .task {
            emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
            favorites = await EmojiIndexProvider.shared.favorites()
        }
    }
}
