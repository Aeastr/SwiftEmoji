<div align="center">
    <img width="120" height="120" src="/Resources/icon/icon.png" alt="SwiftEmoji Logo">
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
    @State private var sections: [EmojiSection] = []
    @State private var favorites: [Emoji] = []
    @State private var searchResults: [Emoji] = []

    let onSelect: (Emoji) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                // Favorites (flat, horizontal)
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

                // Sectioned grid when browsing, flat results when searching
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

### Sectioned Grid (with category headers)

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

### Single Selection
```swift
@State private var selected: Emoji?

ScrollView {
    EmojiGrid(sections: sections, selection: $selected)
}
```

### Multiple Selection
```swift
@State private var selected: Set<String> = []

ScrollView {
    EmojiGrid(sections: sections, selection: $selected)
}
```

## Searching

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

## Favorites & Usage Tracking

The grid doesn't track usage automatically - you control what gets tracked:

```swift
EmojiGrid(emojis: emojis) { emoji in
    EmojiUsageTracker.shared.recordUse(emoji.character)  // Track it
    onSelect(emoji)
}

// Get favorites (sorted by frequency + recency)
let favorites = await EmojiIndexProvider.shared.favorites()

// Use in search ranking
let results = await EmojiIndexProvider.shared.search(query, ranking: .usage)
```

### How It Works

Uses exponential moving average scoring:
- Each use: all scores decay by 0.9, used emoji gets +1
- This naturally surfaces frequently AND recently used emoji
- Minimum 10 favorites kept, maximum 24 returned
- New users get seeded defaults

### Configuration

```swift
let tracker = EmojiUsageTracker.shared

// Disable tracking entirely
tracker.isEnabled = false

// Customize behavior
tracker.minFavorites = 10        // Minimum to keep
tracker.maxFavorites = 24        // Maximum to return
tracker.decayFactor = 0.9        // Lower = faster decay
tracker.defaultEmoji = ["👍", "❤️", "😂"]  // Seeds for new users
tracker.defaultEmoji = []        // No default seeds

// Clear history
tracker.clearAll()

// Remove specific emoji from favorites
tracker.clearScore(for: "💩")

// Use separate tracker for different contexts
let workTracker = EmojiUsageTracker(storageKey: "Work.emojiUsage")
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

The shared instance automatically uses the best source for your platform and locale:
- **macOS**: Apple CoreEmoji (localized) + Gemoji (shortcodes)
- **iOS/tvOS/watchOS/visionOS**: Unicode CLDR (localized) + Gemoji (shortcodes)

```swift
// Recommended: uses system locale, optimal source
let provider = EmojiIndexProvider.shared

// Change locale dynamically (UI updates automatically)
await provider.setLocale(Locale(identifier: "ja"))

// Or create with specific locale
let japanese = EmojiIndexProvider(locale: Locale(identifier: "ja"))
```

### Why Blending?

Emoji data comes from multiple sources, each with different strengths:

| Source | Provides | Missing |
|--------|----------|---------|
| **Gemoji** | Standard order, shortcodes, keywords, categories | Localized names |
| **CLDR** | Localized names (100+ languages) | Order, shortcodes, categories |
| **Apple** | High-quality localized names (macOS) | Order, shortcodes, categories |

The default configuration blends these automatically:
- **Order & metadata** from Gemoji (standard emoji keyboard order)
- **Localized names** from CLDR or Apple

This ensures emojis appear in the familiar order users expect (matching system keyboards), with proper categories for sectioned display, while still showing localized names.

### Custom Sources (Advanced)

```swift
struct MySource: EmojiDataSource {
    let identifier = "my-source"
    let displayName = "My Source"

    func fetch() async throws -> [EmojiRawEntry] {
        // Fetch from your source
    }
}

let provider = EmojiIndexProvider(source: MySource())
```

### Apple CoreEmoji (macOS only)

On macOS, you can use Apple's private CoreEmoji framework for localized emoji names:

```swift
#if os(macOS)
import SwiftEmoji

// Check availability
if AppleEmojiDataSource.isAvailable {
    // Use Apple source with current locale
    let source = AppleEmojiDataSource(locale: .current)
    let provider = EmojiIndexProvider(source: source)
}

// List available locales
let locales = AppleEmojiDataSource.availableLocales()
// [en, ja, fr, de, es, ...]
#endif
```

### Blending Sources

Combine Apple's localized names with Gemoji's shortcodes:

```swift
#if os(macOS)
let blended = BlendedEmojiDataSource(
    primary: AppleEmojiDataSource(locale: .current),  // Localized names
    secondary: GemojiDataSource.shared                 // Shortcodes + keywords
)
let provider = EmojiIndexProvider(source: blended)
#endif
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

### Building Fallback Files

```bash
swift run BuildEmojiIndex
```

Interactive CLI for building fallback files. **Use `blended` (the default)** - it matches the app's runtime behavior and provides standard emoji order.

| Source | Recommended | Description |
|--------|-------------|-------------|
| **CLDR + Gemoji** | Yes | Localized names, standard order, shortcodes |
| **Apple + Gemoji** | Yes (macOS) | Apple localization, standard order, shortcodes |
| **GitHub Gemoji** | No | English only, no localization |
| **Unicode CLDR** | No | No standard order, no shortcodes, no categories |
| **Apple CoreEmoji** | No | No standard order, no shortcodes |

Non-blended sources exist for testing/debugging but produce incomplete data (wrong emoji order, missing categories).

Files are written to `Sources/SwiftEmojiIndex/Resources/` as `emoji-fallback-{locale}.json`.

### Automated Updates

A GitHub Action automatically checks for upstream changes quarterly (Jan, Apr, Jul, Oct) and creates a PR if updates are available.

To trigger manually (e.g., after a Unicode emoji release):
1. Go to Actions > "Update Emoji Fallbacks"
2. Click "Run workflow"
3. Optionally specify locales (comma-separated) or leave default

The CLI also supports non-interactive mode for CI:
```bash
# Specific locales
swift run BuildEmojiIndex --source blended --locales en,ja,ko,zh

# All available locales
swift run BuildEmojiIndex --source blended --all-locales
```

## Caching

Data is cached to disk at `~/Library/Caches/[bundleID]/SwiftEmojiIndex/[sourceId].json`.

Cache refreshes automatically when stale (default: 24 hours).

```swift
// Manual refresh
try await EmojiIndexProvider.shared.refresh()

// Clear cache and reload
try await EmojiIndexProvider.shared.clearCacheAndReload()
```

### Cache Management

```swift
let cache = DiskCache.shared

// List all cached entries
let entries = await cache.listEntries()
for entry in entries {
    print("\(entry.sourceIdentifier): \(entry.emojiCount) emoji, \(entry.fileSize) bytes")
    print("  Last updated: \(entry.lastUpdated)")
}

// Total cache size
let totalBytes = await cache.totalSize()

// Check if specific cache is expired
let isOld = await cache.isExpired(for: "gemoji", maxAge: 7 * 24 * 60 * 60) // 7 days

// Clear expired entries
try await cache.clearExpired(maxAge: 7 * 24 * 60 * 60)

// Clear specific source
try await cache.clear(for: "gemoji")

// Clear everything
try await cache.clearAll()
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

## Localization

Emoji names and keywords are available in 100+ languages via Unicode CLDR (all platforms) or Apple CoreEmoji (macOS).

### Unicode CLDR (All Platforms)

```swift
// Japanese emoji names - works on all Apple platforms
let source = CLDREmojiDataSource(locale: Locale(identifier: "ja"))
let provider = EmojiIndexProvider(source: source)

// With Gemoji shortcodes
let blended = BlendedEmojiDataSource(
    primary: CLDREmojiDataSource(locale: .current),
    secondary: GemojiDataSource.shared
)

// Fetch available locales (async, cached for 7 days)
let locales = await CLDREmojiDataSource.fetchAvailableLocales()
```

### Apple CoreEmoji (macOS)

Higher quality localization on macOS using Apple's private framework:

```swift
#if os(macOS)
if AppleEmojiDataSource.isAvailable {
    let source = AppleEmojiDataSource(locale: .current)
    // Or blend with Gemoji for shortcodes
    let blended = BlendedEmojiDataSource(
        primary: source,
        secondary: GemojiDataSource.shared
    )
}
#endif
```

### Locale Manager

```swift
let localeManager = EmojiLocaleManager.shared

// Fetch available locales (async)
let available = await localeManager.fetchAvailableLocales()

// Or use cached (sync, may be incomplete until fetched)
let cached = localeManager.availableLocales

// Set preferred locale (auto-persists to UserDefaults)
localeManager.preferredLocale = Locale(identifier: "ja")

// Get effective locale (preferred or system)
let current = localeManager.effectiveLocale

// Platform-specific
let cldrLocales = localeManager.cldrLocales      // All platforms
let appleLocales = localeManager.appleLocales    // macOS only
```

### Recommended Setup

Just use `.shared` - it handles platform/locale selection automatically:

```swift
// System locale (most common)
let provider = EmojiIndexProvider.shared

// Change locale dynamically
await provider.setLocale(Locale(identifier: "ja"))

// Read current locale
print(provider.locale)  // ja
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
```

### SkinTone
```swift
public enum SkinTone {
    case none, light, mediumLight, medium, mediumDark, dark
}

let modified = emoji.withSkinTone(.medium)  // Returns emoji character with modifier
```

## Sources

This package uses the following sources for emoji data:

| Source | Description | URL |
|--------|-------------|-----|
| **GitHub Gemoji** | Default source. Provides emoji characters, names, shortcodes, and keywords. | [github/gemoji](https://github.com/github/gemoji) |
| **Unicode CLDR** | Localized emoji names and keywords for 100+ languages. Cross-platform. | [unicode-org/cldr-json](https://github.com/unicode-org/cldr-json) |
| **Apple CoreEmoji** | macOS only. Higher quality localized names via Apple's private framework. | System framework |

## Requirements

- iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+
- Swift 6.0+

## License

MIT
