<div align="center">
  <img width="128" height="128" src="/Resources/icon/icon.png" alt="SwiftEmoji Icon">
  <h1><b>SwiftEmoji</b></h1>
  <p>
    Emoji grid and index for SwiftUI. No hidden behaviors, full customization.
  </p>
</div>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0+-F05138?logo=swift&logoColor=white" alt="Swift 6.0+"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/iOS-17+-000000?logo=apple" alt="iOS 17+"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/macOS-14+-000000?logo=apple" alt="macOS 14+"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/tvOS-17+-000000?logo=apple" alt="tvOS 17+"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/watchOS-10+-000000?logo=apple" alt="watchOS 10+"></a>
  <a href="https://developer.apple.com"><img src="https://img.shields.io/badge/visionOS-1+-000000?logo=apple" alt="visionOS 1+"></a>
  <a href="https://github.com/aeastr/SwiftEmoji/actions/workflows/build.yml"><img src="https://github.com/aeastr/SwiftEmoji/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <a href="https://github.com/aeastr/SwiftEmoji/actions/workflows/tests.yml"><img src="https://github.com/aeastr/SwiftEmoji/actions/workflows/tests.yml/badge.svg" alt="Tests"></a>
</p>


## Overview

- SwiftUI emoji grid with sectioned or flat layouts
- Full-text search with relevance and usage-based ranking
- Favorites tracking with exponential moving average scoring
- Localized emoji names in 100+ languages (CLDR + Apple CoreEmoji)
- Completely customizable styling via `EmojiGridStyle` protocol
- Separate targets for UI (`SwiftEmoji`) and data-only (`SwiftEmojiIndex`)


## Installation

```swift
dependencies: [
    .package(url: "https://github.com/aeastr/SwiftEmoji.git", from: "1.0.0")
]
```

```swift
import SwiftEmoji
```

| Target | Description |
|--------|-------------|
| `SwiftEmoji` | SwiftUI components. Depends on SwiftEmojiIndex. |
| `SwiftEmojiIndex` | Emoji data, fetching, caching, searching. No UI dependencies. |


## Usage

### Basic Grid

```swift
@State private var sections: [EmojiSection] = []

ScrollView {
    EmojiGrid(sections: sections) { emoji in
        print("Selected: \(emoji.character)")
    }
}
.task {
    sections = (try? await EmojiIndexProvider.shared.sections) ?? []
}
```

### Flat Grid (search results, favorites)

```swift
@State private var emojis: [Emoji] = []

ScrollView {
    EmojiGrid(emojis: emojis) { emoji in
        print("Selected: \(emoji.character)")
    }
}
.task {
    emojis = (try? await EmojiIndexProvider.shared.allEmojis) ?? []
}
```

### Selection

```swift
// Single selection
@State private var selected: Emoji?

ScrollView {
    EmojiGrid(sections: sections, selection: $selected)
}

// Multiple selection
@State private var selected: Set<String> = []

ScrollView {
    EmojiGrid(sections: sections, selection: $selected)
}
```

### Full Picker Example

```swift
struct EmojiPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sections: [EmojiSection] = []
    @State private var favorites: [Emoji] = []
    @State private var searchResults: [Emoji] = []

    let onSelect: (Emoji) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if searchText.isEmpty && !favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        EmojiSectionHeader("Favorites", systemImage: "star")
                        EmojiGrid(emojis: favorites) { emoji in
                            select(emoji)
                        }
                        .emojiGridStyle(.default(cellSize: 60, spacing: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }

                if searchText.isEmpty {
                    EmojiGrid(sections: sections) { emoji in
                        select(emoji)
                    }
                    .emojiGridStyle(.default(cellSize: 60, spacing: 12))
                    .padding(.horizontal)
                } else {
                    EmojiGrid(emojis: searchResults) { emoji in
                        select(emoji)
                    }
                    .emojiGridStyle(.default(cellSize: 60, spacing: 12))
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Emoji")
            .searchable(text: $searchText, prompt: "Search emoji")
            .onChange(of: searchText) { _, query in
                Task {
                    searchResults = query.isEmpty ? [] :
                        await EmojiIndexProvider.shared.search(query, ranking: .usage)
                }
            }
            .task {
                sections = (try? await EmojiIndexProvider.shared.sections) ?? []
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

### Searching

```swift
let results = await EmojiIndexProvider.shared.search("smile")

// Search priority (default .relevance ranking):
// 1. Exact shortcode match ("sob" → 😭)
// 2. Name contains query
// 3. Shortcode prefix match
// 4. Keyword prefix match

// Usage-based ranking (frequently used emoji first)
let ranked = await EmojiIndexProvider.shared.search("smile", ranking: .usage)

// Alphabetical
let alphabetical = await EmojiIndexProvider.shared.search("smile", ranking: .alphabetical)
```

### Favorites & Usage Tracking

The grid doesn't track usage automatically - you control what gets tracked:

```swift
EmojiGrid(emojis: emojis) { emoji in
    EmojiUsageTracker.shared.recordUse(emoji.character)
    onSelect(emoji)
}

// Get favorites (sorted by frequency + recency)
let favorites = await EmojiIndexProvider.shared.favorites()

// Use in search ranking
let results = await EmojiIndexProvider.shared.search(query, ranking: .usage)
```

### Models

```swift
public struct Emoji {
    let character: String        // "😀"
    let name: String             // "grinning face"
    let category: EmojiCategory  // .smileysAndEmotion, .peopleAndBody, etc.
    let shortcodes: [String]     // ["grinning"]
    let keywords: [String]       // ["face", "grin", "happy"]
    let supportsSkinTone: Bool
}

// Direct init (no metadata)
let emoji = Emoji("🎨")

// Lookup with full metadata
if let emoji = await Emoji.lookup("🎨") {
    print(emoji.name) // "artist palette"

## Customization

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

Create your own styles by conforming to `EmojiGridStyle`:

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

### Tracker Configuration

```swift
let tracker = EmojiUsageTracker.shared

tracker.isEnabled = false                       // Disable tracking
tracker.minFavorites = 10                       // Minimum to keep
tracker.maxFavorites = 24                       // Maximum to return
tracker.decayFactor = 0.9                       // Lower = faster decay
tracker.defaultEmoji = ["👍", "❤️", "😂"]       // Seeds for new users
tracker.clearAll()                              // Clear history
tracker.clearScore(for: "💩")                   // Remove specific emoji

// Separate tracker for different contexts
let workTracker = EmojiUsageTracker(storageKey: "Work.emojiUsage")
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

// Direct init (no metadata)
let emoji = Emoji("🎨")

// Lookup with full metadata
if let emoji = await Emoji.lookup("🎨") {
    print(emoji.name) // "artist palette"
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
## How It Works

The shared instance automatically selects the best data source for your platform:
- **macOS**: Apple CoreEmoji (localized) + Gemoji (shortcodes)
- **iOS/tvOS/watchOS/visionOS**: Unicode CLDR (localized) + Gemoji (shortcodes)

| Source | Provides | Missing |
|--------|----------|---------|
| **Gemoji** | Standard order, shortcodes, keywords, categories | Localized names |
| **CLDR** | Localized names (100+ languages) | Order, shortcodes, categories |
| **Apple** | High-quality localized names (macOS) | Order, shortcodes, categories |

Data is cached to disk and refreshes automatically when stale (default: 24 hours). A bundled fallback ensures offline functionality.

Favorites use exponential moving average scoring - each use decays all scores by 0.9 and adds +1 to the used emoji, naturally surfacing frequently AND recently used emoji.

For more details:
- [Data Sources](docs/SwiftEmojiIndex/DataSources.md) - custom sources, blending, protocols
- [Localization](docs/SwiftEmojiIndex/Localization.md) - locale manager, CLDR, Apple CoreEmoji
- [Cache Management](docs/SwiftEmojiIndex/CacheManagement.md) - inspection, custom cache
- [Fallback Files](docs/SwiftEmojiIndex/FallbackFiles.md) - building, automation, file format


## Contributing

Contributions welcome. Please feel free to submit a Pull Request.


## License

MIT. See [LICENSE](LICENSE) for details.
