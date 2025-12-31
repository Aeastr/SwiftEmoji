import SwiftUI
import SwiftEmojiIndex

/// A protocol for customizing the appearance and layout of emoji grids.
///
/// The style is responsible for creating the entire grid layout, cell views,
/// and section headers. This gives you full control over spacing, sizing,
/// animations, and visual appearance.
///
/// ## Creating a Custom Style
///
/// ```swift
/// struct MyStyle: EmojiGridStyle {
///     func makeGrid(configuration: GridConfiguration) -> some View {
///         LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
///             ForEach(configuration.emojis) { emoji in
///                 makeCell(configuration: CellConfiguration(
///                     emoji: emoji,
///                     isSelected: configuration.isSelected(emoji),
///                     isSelectable: configuration.isSelectable,
///                     onTap: { configuration.onTap(emoji) }
///                 ))
///             }
///         }
///     }
///
///     func makeCell(configuration: CellConfiguration) -> some View {
///         Button(action: configuration.onTap) {
///             Text(configuration.emoji.character)
///                 .font(.system(size: 32))
///         }
///         .background(configuration.isSelected ? Color.blue.opacity(0.2) : .clear)
///     }
///
///     func makeSectionHeader(configuration: HeaderConfiguration) -> some View {
///         Text(configuration.category.displayName)
///             .font(.headline)
///     }
/// }
/// ```
///
/// ## Applying a Style
///
/// ```swift
/// EmojiGrid(emojis: emojis, selection: $selection)
///     .emojiGridStyle(MyStyle())
/// ```
public protocol EmojiGridStyle {
    associatedtype GridBody: View
    associatedtype CellBody: View
    associatedtype HeaderBody: View

    /// Creates the grid layout with all cells.
    @ViewBuilder
    func makeGrid(configuration: GridConfiguration) -> GridBody

    /// Creates an individual cell view.
    @ViewBuilder
    func makeCell(configuration: CellConfiguration) -> CellBody

    /// Creates a section header view.
    @ViewBuilder
    func makeSectionHeader(configuration: HeaderConfiguration) -> HeaderBody
}
