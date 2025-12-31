import Foundation

/// A data source that blends two sources, using one for base data and another for enrichment.
///
/// Useful for combining Apple's localized names with Gemoji's shortcodes and keywords.
///
/// ## Usage
///
/// ```swift
/// #if os(macOS)
/// let blended = BlendedEmojiDataSource(
///     primary: AppleEmojiDataSource(locale: .current),
///     secondary: GemojiDataSource.shared
/// )
/// let provider = EmojiIndexProvider(source: blended)
/// #endif
/// ```
///
/// ## Blending Behavior
///
/// - Primary source provides: character, name, category (if available)
/// - Secondary source enriches: shortcodes, keywords, supportsSkinTone
/// - Emoji only in secondary are added at the end
public struct BlendedEmojiDataSource: EmojiDataSource {
    public let identifier: String
    public let displayName: String

    private let primary: any EmojiDataSource
    private let secondary: any EmojiDataSource

    /// Creates a blended data source.
    ///
    /// - Parameters:
    ///   - primary: The main source (provides names, categories)
    ///   - secondary: The enrichment source (provides shortcodes, keywords)
    public init(primary: any EmojiDataSource, secondary: any EmojiDataSource) {
        self.primary = primary
        self.secondary = secondary
        self.identifier = "\(primary.identifier)+\(secondary.identifier)"
        self.displayName = "\(primary.displayName) + \(secondary.displayName)"
    }

    public var refreshInterval: TimeInterval {
        min(primary.refreshInterval, secondary.refreshInterval)
    }

    public func fetch() async throws -> [EmojiRawEntry] {
        // Fetch from both sources
        let primaryEntries = try await primary.fetch()
        let secondaryEntries = try await secondary.fetch()

        #if DEBUG
        print("[BlendedEmojiDataSource] Primary (\(primary.identifier)): \(primaryEntries.count) entries")
        print("[BlendedEmojiDataSource] Secondary (\(secondary.identifier)): \(secondaryEntries.count) entries")
        if let first = primaryEntries.first {
            print("[BlendedEmojiDataSource] Primary first: \(first.character) = \"\(first.name)\"")
        }
        #endif

        // Index secondary by character for fast lookup
        var secondaryByChar: [String: EmojiRawEntry] = [:]
        for entry in secondaryEntries {
            secondaryByChar[entry.character] = entry
        }

        // Blend: primary data enriched with secondary
        var results: [EmojiRawEntry] = []
        var seen = Set<String>()

        for entry in primaryEntries {
            seen.insert(entry.character)

            if let enrichment = secondaryByChar[entry.character] {
                // Merge: primary name + secondary shortcodes/keywords
                let merged = EmojiRawEntry(
                    character: entry.character,
                    name: entry.name,
                    category: entry.category != "Unknown" ? entry.category : enrichment.category,
                    shortcodes: enrichment.shortcodes,
                    keywords: mergeKeywords(entry.keywords, enrichment.keywords),
                    supportsSkinTone: enrichment.supportsSkinTone
                )
                results.append(merged)
            } else {
                results.append(entry)
            }
        }

        // Add any emoji only in secondary
        for entry in secondaryEntries {
            if !seen.contains(entry.character) {
                results.append(entry)
            }
        }

        #if DEBUG
        if let first = results.first {
            print("[BlendedEmojiDataSource] Result first: \(first.character) = \"\(first.name)\"")
        }
        print("[BlendedEmojiDataSource] Total blended: \(results.count) entries")
        #endif

        return results
    }

    private func mergeKeywords(_ a: [String], _ b: [String]) -> [String] {
        var set = Set(a)
        set.formUnion(b)
        return Array(set)
    }
}
