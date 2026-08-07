/// Options controlling how headings are turned into a table of contents and
/// whether anchor permalinks are emitted next to them.
public struct TableOfContentsOptions: Sendable, Equatable {
    /// Emit a clickable permalink anchor next to each heading.
    public var permalink: Bool
    /// The symbol used for the permalink anchor.
    public var permalinkSymbol: String
    /// Heading levels to include in the table of contents (e.g. `2...3`).
    public var levels: ClosedRange<Int>

    public init(permalink: Bool = true, permalinkSymbol: String = "#", levels: ClosedRange<Int> = 2...3) {
        self.permalink = permalink
        self.permalinkSymbol = permalinkSymbol
        self.levels = levels
    }
}

/// Toggles for the markdown features Kiln supports.
///
/// Kiln supports the markdown features Vapor's docs actually use: CommonMark +
/// GFM (tables, strikethrough, task lists), MkDocs-style admonitions, heading
/// anchors / table of contents, a YAML front-matter block, and opt-in
/// swift-markdown inline attributes and block directives. Python-Markdown's
/// `footnotes` and `attr_list` remain unsupported.
public struct MarkdownExtensions: Sendable {
    /// Parse `!!! type "Title"` / `??? type "Title"` admonition blocks.
    public var admonitions: Bool
    /// Parse a YAML front-matter block (`meta`).
    public var metadata: Bool
    /// Render swift-markdown `^[content](class: "name")` nodes as `<span>`s.
    /// Only the JSON5 `class` property is accepted.
    public var inlineAttributes: Bool
    /// Code-defined handlers for swift-markdown block directives. A non-empty
    /// collection enables block-directive parsing; unknown directives preserve
    /// their rendered children without adding a wrapper.
    public var directiveHandlers: [MarkdownDirectiveHandler]
    /// Table-of-contents / heading anchor options (`toc`).
    public var tableOfContents: TableOfContentsOptions

    public init(
        admonitions: Bool = true,
        metadata: Bool = true,
        inlineAttributes: Bool = false,
        directiveHandlers: [MarkdownDirectiveHandler] = [],
        tableOfContents: TableOfContentsOptions = TableOfContentsOptions()
    ) {
        self.admonitions = admonitions
        self.metadata = metadata
        self.inlineAttributes = inlineAttributes
        self.directiveHandlers = directiveHandlers
        self.tableOfContents = tableOfContents
    }
}
