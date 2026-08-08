import Testing
@testable import Kiln

@Suite("Markdown rendering")
struct MarkdownTests {
    let renderer = MarkdownRenderer()

    @Test("Images render with alt and are lazy-loaded")
    func imageLazyLoading() {
        let result = renderer.render("![A diagram](/img/diagram.png)")
        #expect(result.html.contains("<img"))
        #expect(result.html.contains("src=\"/img/diagram.png\""))
        #expect(result.html.contains("alt=\"A diagram\""))
        #expect(result.html.contains("loading=\"lazy\""))
        #expect(result.html.contains("decoding=\"async\""))
    }

    @Test("Admonitions render with kind and title")
    func admonitionWithTitle() {
        let result = renderer.render("""
        !!! tip "Heads up"
            Body text here.
        """)
        #expect(result.html.contains("<div class=\"admonition tip\">"))
        #expect(result.html.contains("<p class=\"admonition-title\">Heads up</p>"))
        #expect(result.html.contains("Body text here."))
    }

    @Test("Admonitions without a title use the capitalised kind")
    func admonitionDefaultTitle() {
        let result = renderer.render("""
        !!! warning
            Careful!
        """)
        #expect(result.html.contains("<div class=\"admonition warning\">"))
        #expect(result.html.contains("<p class=\"admonition-title\">Warning</p>"))
    }

    @Test("Collapsible admonitions render as details/summary")
    func collapsibleAdmonition() {
        let result = renderer.render("""
        ???+ info "More"
            Hidden detail.
        """)
        #expect(result.html.contains("<details class=\"admonition info\" open>"))
        #expect(result.html.contains("<summary class=\"admonition-title\">More</summary>"))
    }

    @Test("Headings get slugged ids, permalinks and a table of contents")
    func headingsAndTOC() {
        let result = renderer.render("""
        # Title

        ## First Section

        ### Nested

        ## Second Section
        """)
        #expect(result.html.contains("<h2 id=\"first-section\">"))
        #expect(result.html.contains("class=\"headerlink\""))
        #expect(result.firstHeading == "Title")

        // toc covers levels 2...3 by default: two top-level entries, one nested.
        #expect(result.tableOfContents.count == 2)
        #expect(result.tableOfContents.first?.id == "first-section")
        #expect(result.tableOfContents.first?.children.first?.title == "Nested")
    }

    @Test("Tables render as HTML tables")
    func tables() {
        let result = renderer.render("""
        | A | B |
        | - | - |
        | 1 | 2 |
        """)
        #expect(result.html.contains("<table>"))
        #expect(result.html.contains("<th>A</th>"))
        #expect(result.html.contains("<td>1</td>"))
    }

    @Test("HTML special characters in text and code are escaped")
    func escaping() {
        // Note: `<tag>` in prose is valid CommonMark raw HTML, so we use
        // characters that are unambiguously text: `<` followed by a space, and
        // a bare ampersand.
        let result = renderer.render("A `<tag>` and a comparison a < b and x & y.")
        #expect(result.html.contains("<code>&lt;tag&gt;</code>"))
        #expect(result.html.contains("a &lt; b"))
        #expect(result.html.contains("x &amp; y"))
    }

    @Test("Code blocks carry a language class")
    func codeBlockLanguage() {
        let result = renderer.render("""
        ```swift
        let x = 1
        ```
        """)
        #expect(result.html.contains("<code class=\"language-swift\">"))
    }

    @Test("Inline attributes are opt-in and render a normalized class")
    func inlineAttributes() {
        let source = #"^[formatted text](class: "badge   badge-warning")"#
        #expect(renderer.render(source).html == "<p>formatted text</p>\n")

        let attributed = MarkdownRenderer(options: MarkdownExtensions(inlineAttributes: true))
            .render(source)
        #expect(attributed.html == "<p><span class=\"badge badge-warning\">formatted text</span></p>\n")
    }

    @Test("Malformed inline attributes cannot inject HTML attributes")
    func malformedInlineAttributes() {
        let attributed = MarkdownRenderer(options: MarkdownExtensions(inlineAttributes: true))
            .render(#"^[safe text](class: "\"><script>")"#)
        #expect(!attributed.html.contains("<script>"))
        #expect(attributed.html.contains("class=\"&quot;&gt;&lt;script&gt;\""))
    }

    @Test("Block directive handlers render children and collect page head elements")
    func blockDirectiveHandler() {
        let head = MarkdownHead(
            metadata: [.init(value: "kiln-component", content: "card")],
            stylesheets: [.init("/components/card.css")],
            scripts: [.init("/components/card.js")]
        )
        let handler = MarkdownDirectiveHandler("Card") { directive in
            .container(
                .aside,
                bodyHTML: directive.bodyHTML,
                classes: ["card", directive.arguments["tone"] ?? ""],
                head: head
            )
        }
        let renderer = MarkdownRenderer(options: MarkdownExtensions(directiveHandlers: [handler]))
        let result = renderer.render("""
        @Card(tone: warning) {
          ## Details

          Read the [guide](guide.md).

          ![Diagram](diagram.png)
        }
        """)

        #expect(result.html.contains("<aside class=\"card warning\">"))
        #expect(result.html.contains("<h2 id=\"details\">"))
        #expect(result.links == ["guide.md"])
        #expect(result.images == ["diagram.png"])
        #expect(result.tableOfContents.map(\.id) == ["details"])
        #expect(result.metaDescription == "Read the guide.")
        #expect(result.head == head)
        #expect(result.head.html.contains(#"<meta name="kiln-component" content="card">"#))
        #expect(result.head.html.contains(#"<link rel="stylesheet" href="/components/card.css">"#))
        #expect(result.head.html.contains(#"<script src="/components/card.js" defer></script>"#))
    }

    @Test("Unknown directives preserve children when directive parsing is enabled")
    func unknownDirective() {
        let known = MarkdownDirectiveHandler("Known") { directive in
            .init(html: directive.bodyHTML)
        }
        let renderer = MarkdownRenderer(options: MarkdownExtensions(directiveHandlers: [known]))
        let result = renderer.render("""
        @Unknown {
          Body survives.
        }
        """)
        #expect(result.html == "<p>Body survives.</p>\n")
    }

    @Test("Repeated directives deduplicate identical page head elements")
    func directiveHeadDeduplication() {
        let stylesheet = MarkdownStylesheet("/components/card.css")
        let handler = MarkdownDirectiveHandler("Card") { directive in
            .init(html: directive.bodyHTML, head: MarkdownHead(stylesheets: [stylesheet]))
        }
        let renderer = MarkdownRenderer(options: MarkdownExtensions(directiveHandlers: [handler]))
        let result = renderer.render("""
        @Card { One }

        @Card { Two }
        """)
        #expect(result.head.stylesheets == [stylesheet])
    }

    @Test("Page head values are HTML attribute escaped")
    func directiveHeadEscaping() {
        let head = MarkdownHead(
            metadata: [.init(value: #"x" onload="bad"#, content: "<&")],
            stylesheets: [.init(#"/styles/"bad.css"#)],
            scripts: [.init(#"/scripts/"bad.js"#)]
        )
        #expect(head.html.contains(#"name="x&quot; onload=&quot;bad""#))
        #expect(head.html.contains(#"content="&lt;&amp;""#))
        #expect(head.html.contains(#"href="/styles/&quot;bad.css""#))
        #expect(head.html.contains(#"src="/scripts/&quot;bad.js""#))
        #expect(!head.html.contains(" onload=\"bad\""))
    }

    @Test("Container attributes are emitted in a stable order and escaped")
    func containerAttributes() {
        let output = MarkdownDirectiveOutput.container(
            .figure,
            bodyHTML: "<p>Body</p>\n",
            classes: ["map"],
            attributes: ["data-zoom": "14", "data-src": #"a" onerror="bad"#, "aria-label": "Places"]
        )
        // Sorted by name, so identical inputs always produce identical markup.
        #expect(output.html.hasPrefix(
            #"<figure class="map" aria-label="Places" data-src="a&quot; onerror=&quot;bad" data-zoom="14">"#
        ))
        #expect(!output.html.contains(" onerror=\"bad\""))
        #expect(output.html.contains("<p>Body</p>"))
    }

    @Test("An attribute name that could open an event handler is refused, not escaped")
    func containerRefusesUnsafeAttributeNames() {
        let output = MarkdownDirectiveOutput.container(
            bodyHTML: "",
            attributes: ["onclick": "steal()", "on": "x", "data bad": "y", "": "z", "9lives": "w", "data-ok": "yes"]
        )
        #expect(output.html.contains(#"data-ok="yes""#))
        for refused in ["onclick", "data bad", "9lives"] {
            #expect(!output.html.contains(refused))
        }
    }

    @Test("A handler's render closure is reachable, so a component can be tested on its own")
    func handlerRenderIsPublic() {
        let handler = MarkdownDirectiveHandler("Echo") { .init(html: "<p>\($0.arguments["say"] ?? "")</p>") }
        let output = handler.renderBody(MarkdownDirective(name: "Echo", arguments: ["say": "hello"]))
        #expect(output.html == "<p>hello</p>")
    }

    @Test("Enabling directives does not change an existing page's meta description")
    func metaDescriptionIsStableWithoutDirectives() {
        // A page opening with a list: its first *top-level* paragraph is the
        // prose below, and descending into the list would wrongly pick the
        // list item instead — rewriting the description of every such page.
        let source = """
        # Title

        - A list item first

        The real opening paragraph.
        """
        #expect(MarkdownRenderer.metaDescription(from: source) == "The real opening paragraph.")
        #expect(
            MarkdownRenderer.metaDescription(from: source, parseBlockDirectives: true)
                == "A list item first"
        )
    }
}

@Suite("Slugger")
struct SluggerTests {
    @Test("Produces GitHub-style slugs")
    func basic() {
        let slugger = Slugger()
        #expect(slugger.slug(for: "Hello, World!") == "hello-world")
    }

    @Test("Disambiguates repeated headings")
    func unique() {
        let slugger = Slugger()
        #expect(slugger.slug(for: "Overview") == "overview")
        #expect(slugger.slug(for: "Overview") == "overview-1")
        #expect(slugger.slug(for: "Overview") == "overview-2")
    }
}
