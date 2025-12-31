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

### Tap-only (pickers, sheets)
```swift
@State private var emojis: [Emoji] = []

ScrollView {
    EmojiGrid(emojis: emojis) { emoji in
        print("Selected: \(emoji.character)")
        dismiss()
    }
}
.task {
    emojis = try await EmojiIndexProvider.shared.allEmojis
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
```

## Customization

### Cell Size & Spacing
```swift
EmojiGrid(emojis: emojis) { _ in }
    .emojiCellSize(52)
    .emojiCellSpacing(8)
```

### Grid Columns
```swift
EmojiGrid(
    emojis: emojis,
    columns: [GridItem(.fixed(60)), GridItem(.fixed(60)), GridItem(.fixed(60))]
) { _ in }
```

### Custom Styles
```swift
struct MyStyle: EmojiGridStyle {
    func makeGrid(configuration: GridConfiguration) -> some View {
        configuration.content
            .padding()
    }

    func makeCell(configuration: CellConfiguration) -> some View {
        configuration.content
            .scaleEffect(configuration.isSelected ? 1.2 : 1.0)
            .background(configuration.isSelected ? Color.blue.opacity(0.2) : .clear)
    }

    func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
        configuration.content
    }
}

// Usage
EmojiGrid(emojis: emojis, selection: $selected)
    .emojiGridStyle(MyStyle())
```

Built-in styles: `DefaultEmojiGridStyle`, `SelectionHighlightStyle`, `RoundedEmojiGridStyle`

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
