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
    /// HTML. Classes and attributes are normalized and attribute-escaped by
    /// Kiln.
    ///
    /// `attributes` covers what a class cannot: the `data-` values a component
    /// needs its own script or stylesheet to read, and the ARIA a wrapper needs
    /// to be announced correctly. Without it any handler wanting either has to
    /// abandon this helper and concatenate its own HTML, which is the one thing
    /// the helper exists to prevent.
    public static func container(
        _ element: MarkdownContainer = .div,
        bodyHTML: String,
        classes: [String] = [],
        attributes: [String: String] = [:],
        head: MarkdownHead = MarkdownHead()
    ) -> Self {
        let normalizedClasses = classes
            .flatMap { $0.split(whereSeparator: \Character.isWhitespace).map(String.init) }
            .filter { !$0.isEmpty }
        var markup = "<\(element.rawValue)"
        if !normalizedClasses.isEmpty {
            markup += " class=\"\(HTMLEscaping.attribute(normalizedClasses.joined(separator: " ")))\""
        }
        // Sorted so the same inputs always produce the same markup —
        // dictionary order is not stable, and unstable output would defeat
        // content-hashed caching and make snapshot tests flap.
        for name in attributes.keys.sorted() {
            guard Self.isSafeAttributeName(name), let value = attributes[name] else { continue }
            markup += " \(name)=\"\(HTMLEscaping.attribute(value))\""
        }
        markup += ">\n\(bodyHTML)</\(element.rawValue)>\n"
        return Self(html: markup, head: head)
    }

    /// Attribute names a handler may set. Escaping a *value* is enough to keep
    /// it inside its quotes, but a name is not inside quotes at all — so the
    /// name is restricted by construction rather than escaped, and anything
    /// that could open an event handler (`on…`) or a namespace is refused.
    static func isSafeAttributeName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 64, !name.lowercased().hasPrefix("on") else { return false }
        guard let first = name.first, first.isLetter else { return false }
        return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }
}

/// Code-defined rendering hook for one swift-markdown `BlockDirective` name.
public struct MarkdownDirectiveHandler: Sendable {
    public var name: String
    /// Renders one occurrence of the directive. Public so a handler can be
    /// exercised directly in a test, without standing up a whole site build.
    public let renderBody: @Sendable (MarkdownDirective) -> MarkdownDirectiveOutput

    public init(
        _ name: String,
        render: @escaping @Sendable (MarkdownDirective) -> MarkdownDirectiveOutput
    ) {
        self.name = name
        self.renderBody = render
    }
}
