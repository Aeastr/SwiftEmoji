import SwiftUI
import SwiftEmojiIndex

/// The default emoji grid style.
public struct DefaultEmojiGridStyle: EmojiGridStyle {
    public var cellSize: CGFloat
    public var spacing: CGFloat
    public var columns: [GridItem]?

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
