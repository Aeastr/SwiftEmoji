import SwiftUI
import SwiftEmojiIndex

// MARK: - Style Shortcuts

extension EmojiGridStyle where Self == DefaultEmojiGridStyle {
    /// Default style with 44pt cells and 4pt spacing.
    public static var `default`: DefaultEmojiGridStyle { DefaultEmojiGridStyle() }

    /// Default style with custom cell size and spacing.
    public static func `default`(cellSize: CGFloat, spacing: CGFloat = 4) -> DefaultEmojiGridStyle {
        DefaultEmojiGridStyle(cellSize: cellSize, spacing: spacing)
    }
}

extension EmojiGridStyle where Self == LargeEmojiGridStyle {
    /// Large style with 56pt cells and backgrounds.
    public static var large: LargeEmojiGridStyle { LargeEmojiGridStyle() }
}

extension EmojiGridStyle where Self == CompactEmojiGridStyle {
    /// Compact horizontal style with 36pt cells.
    public static var compact: CompactEmojiGridStyle { CompactEmojiGridStyle() }
}

// MARK: - Default Style

/// The default emoji grid style.
public struct DefaultEmojiGridStyle: EmojiGridStyle, @unchecked Sendable {
    public let cellSize: CGFloat
    public let spacing: CGFloat
    public let columns: [GridItem]?

    public init(
        cellSize: CGFloat = 44,
        spacing: CGFloat = 4,
        columns: [GridItem]? = nil
    ) {
        self.cellSize = cellSize
        self.spacing = spacing
        self.columns = columns
    }

    public func makeGrid(configuration: GridConfiguration) -> some View {
        let gridColumns = columns ?? [GridItem(.adaptive(minimum: cellSize))]

        LazyVGrid(columns: gridColumns, spacing: spacing) {
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

    public func makeCell(configuration: CellConfiguration) -> some View {
        Button(action: configuration.onTap) {
            Text(configuration.emoji.character)
                .font(.system(size: cellSize * 0.7))
                .frame(width: cellSize, height: cellSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if configuration.isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.2))
            }
        }
        .accessibilityLabel(configuration.emoji.name)
    }

    public func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
        HStack {
            Image(systemName: configuration.category.symbolName)
                .foregroundStyle(.secondary)
            Text(configuration.category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

/// A style with larger cells and more spacing.
public struct LargeEmojiGridStyle: EmojiGridStyle {
    public init() {}

    public func makeGrid(configuration: GridConfiguration) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 8) {
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

    public func makeCell(configuration: CellConfiguration) -> some View {
        Button(action: configuration.onTap) {
            Text(configuration.emoji.character)
                .font(.system(size: 40))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(configuration.isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
        }
        .overlay {
            if configuration.isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
    }

    public func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
        Text(configuration.category.displayName)
            .font(.headline)
            .padding(.vertical, 12)
    }
}

/// A compact horizontal style.
public struct CompactEmojiGridStyle: EmojiGridStyle {
    public init() {}

    public func makeGrid(configuration: GridConfiguration) -> some View {
        LazyHGrid(rows: [GridItem(.fixed(36))], spacing: 4) {
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

    public func makeCell(configuration: CellConfiguration) -> some View {
        Button(action: configuration.onTap) {
            Text(configuration.emoji.character)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .background {
            if configuration.isSelected {
                Circle().fill(Color.accentColor.opacity(0.2))
            }
        }
    }

    public func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
        EmptyView()
    }
}
