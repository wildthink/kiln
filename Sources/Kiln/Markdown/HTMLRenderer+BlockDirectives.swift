import Markdown

extension HTMLRenderer {
    mutating func visitBlockDirective(_ blockDirective: BlockDirective) {
        let outerHTML = result
        result = ""
        descendInto(blockDirective)
        let bodyHTML = result
        result = outerHTML

        guard let handler = directiveHandlers.first(where: { $0.name == blockDirective.name }) else {
            // Unknown directives are transparent containers. This preserves their
            // Markdown children without inventing HTML semantics.
            result += bodyHTML
            return
        }

        var arguments: [String: String] = [:]
        for argument in blockDirective.argumentText.parseNameValueArguments() {
            arguments[argument.name] = argument.value
        }
        let output = handler.renderBody(MarkdownDirective(
            name: blockDirective.name,
            arguments: arguments,
            bodyHTML: bodyHTML
        ))
        result += output.html
        head.merge(output.head)
    }
}
