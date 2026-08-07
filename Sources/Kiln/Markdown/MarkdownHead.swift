/// Elements requested by Markdown rendering hooks for insertion in the page's
/// HTML `<head>`. Values are escaped by Kiln; URLs are emitted verbatim so hooks
/// can use root-relative or absolute references.
public struct MarkdownHead: Sendable, Equatable {
    public var metadata: [MarkdownMetadata]
    public var stylesheets: [MarkdownStylesheet]
    public var scripts: [MarkdownScript]

    public init(
        metadata: [MarkdownMetadata] = [],
        stylesheets: [MarkdownStylesheet] = [],
        scripts: [MarkdownScript] = []
    ) {
        self.metadata = metadata
        self.stylesheets = stylesheets
        self.scripts = scripts
    }

    mutating func merge(_ other: MarkdownHead) {
        appendUnique(other.metadata, to: &metadata)
        appendUnique(other.stylesheets, to: &stylesheets)
        appendUnique(other.scripts, to: &scripts)
    }

    private func appendUnique<Element: Equatable>(_ additions: [Element], to values: inout [Element]) {
        for addition in additions where !values.contains(addition) {
            values.append(addition)
        }
    }
}

/// A `<meta>` element requested by a Markdown rendering hook.
public struct MarkdownMetadata: Sendable, Equatable {
    public enum Key: String, Sendable {
        case name
        case property
        case httpEquiv = "http-equiv"
    }

    public var key: Key
    public var value: String
    public var content: String

    public init(_ key: Key = .name, value: String, content: String) {
        self.key = key
        self.value = value
        self.content = content
    }
}

/// A stylesheet link requested by a Markdown rendering hook.
public struct MarkdownStylesheet: Sendable, Equatable {
    public var href: String
    public var media: String?

    public init(_ href: String, media: String? = nil) {
        self.href = href
        self.media = media
    }
}

/// An external script requested by a Markdown rendering hook.
public struct MarkdownScript: Sendable, Equatable {
    public var src: String
    public var type: String?
    public var isDeferred: Bool
    public var isAsync: Bool

    public init(_ src: String, type: String? = nil, defer isDeferred: Bool = true, async isAsync: Bool = false) {
        self.src = src
        self.type = type
        self.isDeferred = isDeferred
        self.isAsync = isAsync
    }
}

extension MarkdownHead {
    var html: String {
        var result = ""
        for item in metadata {
            result += "<meta \(item.key.rawValue)=\"\(HTMLEscaping.attribute(item.value))\" content=\"\(HTMLEscaping.attribute(item.content))\">\n"
        }
        for stylesheet in stylesheets {
            result += "<link rel=\"stylesheet\" href=\"\(HTMLEscaping.attribute(stylesheet.href))\""
            if let media = stylesheet.media {
                result += " media=\"\(HTMLEscaping.attribute(media))\""
            }
            result += ">\n"
        }
        for script in scripts {
            result += "<script src=\"\(HTMLEscaping.attribute(script.src))\""
            if let type = script.type {
                result += " type=\"\(HTMLEscaping.attribute(type))\""
            }
            if script.isDeferred { result += " defer" }
            if script.isAsync { result += " async" }
            result += "></script>\n"
        }
        return result
    }
}
