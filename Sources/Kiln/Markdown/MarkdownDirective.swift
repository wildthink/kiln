/// Parsed input supplied to a registered block-directive handler.
public struct MarkdownDirective: Sendable, Equatable {
    public var name: String
    /// Parsed `name: value` arguments. Duplicate names keep the last value.
    public var arguments: [String: String]
    /// Directive children rendered through Kiln's normal Markdown pipeline.
    public var bodyHTML: String

    public init(name: String, arguments: [String: String] = [:], bodyHTML: String = "") {
        self.name = name
        self.arguments = arguments
        self.bodyHTML = bodyHTML
    }
}

/// HTML block elements supported by the code-free container helper.
public enum MarkdownContainer: String, Sendable {
    case div
    case section
    case aside
    case figure
    case details
}

/// Result produced by a block-directive handler.
public struct MarkdownDirectiveOutput: Sendable, Equatable {
    /// Trusted body HTML. Prefer ``container(_:bodyHTML:classes:head:)`` when a
    /// semantic wrapper is sufficient.
    public var html: String
    public var head: MarkdownHead

    public init(html: String, head: MarkdownHead = MarkdownHead()) {
        self.html = html
        self.head = head
    }

    /// Wrap rendered directive children without requiring handlers to construct
    /// HTML. Classes are normalized and attribute-escaped by Kiln.
    public static func container(
        _ element: MarkdownContainer = .div,
        bodyHTML: String,
        classes: [String] = [],
        head: MarkdownHead = MarkdownHead()
    ) -> Self {
        let normalizedClasses = classes
            .flatMap { $0.split(whereSeparator: \Character.isWhitespace).map(String.init) }
            .filter { !$0.isEmpty }
        let classAttribute = normalizedClasses.isEmpty
            ? ""
            : " class=\"\(HTMLEscaping.attribute(normalizedClasses.joined(separator: " ")))\""
        return Self(
            html: "<\(element.rawValue)\(classAttribute)>\n\(bodyHTML)</\(element.rawValue)>\n",
            head: head
        )
    }
}

/// Code-defined rendering hook for one swift-markdown `BlockDirective` name.
public struct MarkdownDirectiveHandler: Sendable {
    public var name: String
    let renderBody: @Sendable (MarkdownDirective) -> MarkdownDirectiveOutput

    public init(
        _ name: String,
        render: @escaping @Sendable (MarkdownDirective) -> MarkdownDirectiveOutput
    ) {
        self.name = name
        self.renderBody = render
    }
}
