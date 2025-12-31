# SwiftEmoji

Emoji grid and index for SwiftUI. No hidden behaviors, full customization.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/aeastr/SwiftEmoji.git", from: "1.0.0")
]

// Target
.target(
    name: "YourApp",
    dependencies: [
        "SwiftEmoji",        // UI components
        "SwiftEmojiIndex"    // Data only (optional, if you just need the index)
    ]
)
```

## Targets

| Target | Description |
|--------|-------------|
| `SwiftEmojiIndex` | Emoji data, fetching, caching, searching. No UI dependencies. |
| `SwiftEmoji` | SwiftUI components. Depends on SwiftEmojiIndex. |

Import what you need:
```swift
import SwiftEmojiIndex  // Just data/search
import SwiftEmoji       // UI + data
```

## Basic Usage

### Full Picker with Search & Favorites

```swift
struct EmojiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var emojis: [Emoji] = []
    @State private var favorites: [Emoji] = []
    @State private var searchResults: [Emoji] = []

    let onSelect: (Emoji) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if searchText.isEmpty && !favorites.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            EmojiGrid(emojis: favorites) { emoji in
                                select(emoji)
                            }
                            .emojiGridStyle(.compact)
                            .padding(.horizontal)
                        }
                    } header: {
                        Text("Frequently Used")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }

                EmojiGrid(emojis: searchText.isEmpty ? emojis : searchResults) { emoji in
                    select(emoji)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Emoji")
            .searchable(text: $searchText, prompt: "Search emoji")
            .onChange(of: searchText) { _, query in
                Task {
                    searchResults = query.isEmpty ? [] :
                        await EmojiIndexProvider.shared.search(query, rankByUsage: true)
                }
            }
            .task {
                emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
                favorites = await EmojiIndexProvider.shared.favorites()
            }
        }
    }

    private func select(_ emoji: Emoji) {
        EmojiUsageTracker.shared.recordUse(emoji.character)
        onSelect(emoji)
        dismiss()
    }
}
```

### Tap-only (simple)
```swift
@State private var emojis: [Emoji] = []

ScrollView {
    EmojiGrid(emojis: emojis) { emoji in
        print("Selected: \(emoji.character)")
        dismiss()
    }
}
.task {
    emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
}
```

### Single Selection
```swift
@State private var selected: Emoji?

ScrollView {
    EmojiGrid(emojis: emojis, selection: $selected)
}
```

### Multiple Selection
```swift
@State private var selected: Set<String> = []

ScrollView {
    EmojiGrid(emojis: emojis, selection: $selected)
}
```

## Searching

```swift
let results = await EmojiIndexProvider.shared.search("smile")

// Search priority:
// 1. Exact shortcode match ("sob" → 😭)
// 2. Name contains query
// 3. Shortcode prefix match
// 4. Keyword prefix match

// With usage-based ranking (frequently used emoji appear first)
let ranked = await EmojiIndexProvider.shared.search("smile", rankByUsage: true)
```

## Favorites & Usage Tracking

Track emoji usage to show favorites and rank search results:

```swift
// Record when user selects an emoji
EmojiUsageTracker.shared.recordUse(emoji.character)

// Get favorites (sorted by frequency + recency)
let favorites = await EmojiIndexProvider.shared.favorites()

// Use in search ranking
let results = await EmojiIndexProvider.shared.search(query, rankByUsage: true)
```

### How It Works

Uses exponential moving average scoring:
- Each use: all scores decay by 0.9, used emoji gets +1
- This naturally surfaces frequently AND recently used emoji
- Minimum 10 favorites kept, maximum 24 returned
- New users get seeded defaults

### Customization

```swift
let tracker = EmojiUsageTracker.shared
tracker.minFavorites = 10        // Minimum to keep
tracker.maxFavorites = 24        // Maximum to return
tracker.decayFactor = 0.9        // Lower = faster decay
tracker.defaultEmoji = ["👍", "❤️", "😂"]  // Seeds for new users

// Clear history
tracker.clearAll()

// Remove specific emoji from favorites
tracker.clearScore(for: "💩")
```

## Styling

The style controls all layout and appearance:

```swift
EmojiGrid(emojis: emojis, selection: $selected)
    .emojiGridStyle(.large)
```

### Built-in Styles

```swift
// Default - 44pt cells, 4pt spacing
EmojiGrid(emojis: emojis, selection: $selected)

// Default with custom size
EmojiGrid(emojis: emojis, selection: $selected)
    .emojiGridStyle(.default(cellSize: 52, spacing: 8))

// Large - 56pt cells with backgrounds
EmojiGrid(emojis: emojis, selection: $selected)
    .emojiGridStyle(.large)

// Compact - horizontal 36pt cells
ScrollView(.horizontal) {
    EmojiGrid(emojis: emojis) { emoji in }
        .emojiGridStyle(.compact)
}
```

### Custom Styles

The style creates the entire grid. You control layout, sizing, spacing, everything:

```swift
struct MyStyle: EmojiGridStyle {
    func makeGrid(configuration: GridConfiguration) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
            ForEach(configuration.emojis) { emoji in
                makeCell(configuration: CellConfiguration(
                    emoji: emoji,
                    isSelected: configuration.isSelected(emoji),
                    isSelectable: configuration.isSelectable,
                    onTap: { configuration.onTap(emoji) }
                ))
            }
        }
    }

    func makeCell(configuration: CellConfiguration) -> some View {
        Button(action: configuration.onTap) {
            Text(configuration.emoji.character)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
        }
        .background(configuration.isSelected ? Color.blue.opacity(0.3) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
        Text(configuration.category.displayName)
            .font(.headline)
    }
}

// Usage
EmojiGrid(emojis: emojis, selection: $selected)
    .emojiGridStyle(MyStyle())
```

## Data Sources

The index fetches emoji data from remote sources. Default is GitHub Gemoji.

```swift
// Default (Gemoji)
let provider = EmojiIndexProvider.shared

// Custom source
struct MySource: EmojiDataSource {
    let identifier = "my-source"
    let displayName = "My Source"

    func fetch() async throws -> [EmojiRawEntry] {
        // Fetch from your source
    }
}

let provider = EmojiIndexProvider(source: MySource())
```

### EmojiDataSource Protocol

```swift
public protocol EmojiDataSource: Sendable {
    var identifier: String { get }           // Cache namespace
    var displayName: String { get }
    var remoteURL: URL? { get }              // Optional
    var refreshInterval: TimeInterval { get } // Default: 24 hours

    func fetch() async throws -> [EmojiRawEntry]
}
```

## Fallback

The package includes a bundled fallback for offline use. Data loads in this order:

1. **Cache** - Previously fetched data
2. **Fallback** - Bundled or custom fallback file
3. **Remote** - Fresh fetch from data source

### Custom Fallback

Provide your own fallback file:

```swift
let customFallback = Bundle.main.url(forResource: "my-emojis", withExtension: "json")!

let provider = EmojiIndexProvider(
    source: GemojiDataSource.shared,
    fallbackURL: customFallback
)
```

Fallback must be JSON array of `EmojiRawEntry`:

```json
[
  {
    "character": "😀",
    "name": "grinning face",
    "category": "Smileys & Emotion",
    "shortcodes": ["grinning"],
    "keywords": ["face", "grin", "happy"],
    "supportsSkinTone": false
  }
]
```

### Regenerating Bundled Fallback

```bash
swift run BuildEmojiIndex
```

Downloads latest Gemoji data and writes to `Sources/SwiftEmojiIndex/Resources/emoji-fallback.json`.

## Caching

Data is cached to disk at `~/Library/Caches/[bundleID]/SwiftEmojiIndex/[sourceId].json`.

Cache refreshes automatically when stale (default: 24 hours).

```swift
// Manual refresh
try await EmojiIndexProvider.shared.refresh()

// Clear cache and reload
try await EmojiIndexProvider.shared.clearCacheAndReload()
```

### Custom Cache

```swift
struct MyCache: EmojiCache {
    func load(for sourceIdentifier: String) async throws -> (entries: [EmojiRawEntry], lastUpdated: Date)? { }
    func save(_ entries: [EmojiRawEntry], for sourceIdentifier: String) async throws { }
    func clear(for sourceIdentifier: String) async throws { }
    func clearAll() async throws { }
}

let provider = EmojiIndexProvider(
    source: GemojiDataSource.shared,
    cache: MyCache()
)
```

## Models

### Emoji
```swift
public struct Emoji {
    let character: String        // "😀"
    let name: String             // "grinning face"
    let category: EmojiCategory
    let shortcodes: [String]     // ["grinning"]
    let keywords: [String]       // ["face", "grin", "happy"]
    let supportsSkinTone: Bool
}
```

### EmojiCategory
```swift
public enum EmojiCategory {
    case smileysAndEmotion
    case peopleAndBody
    case animalsAndNature
    case foodAndDrink
    case travelAndPlaces
    case activities
    case objects
    case symbols
    case flags
}
```

### SkinTone
```swift
public enum SkinTone {
    case none, light, mediumLight, medium, mediumDark, dark
}

let modified = emoji.withSkinTone(.medium)  // Returns emoji character with modifier
```

## Requirements

- iOS 17+, macOS 14+, visionOS 1+
- Swift 6.2+

## License

MIT
