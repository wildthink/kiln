import Foundation
import Markdown

extension HTMLRenderer {
    mutating func visitInlineAttributes(_ attributes: InlineAttributes) {
        guard rendersInlineAttributes else {
            descendInto(attributes)
            return
        }

        struct ParsedAttributes: Decodable {
            var `class`: String
        }

        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        let data = Data("{\(attributes.attributes)}".utf8)
        let className = (try? decoder.decode(ParsedAttributes.self, from: data).class)
            .map { $0.split(whereSeparator: \Character.isWhitespace).joined(separator: " ") }
            .flatMap { $0.isEmpty ? nil : $0 }

        result += "<span"
        if let className {
            result += " class=\"\(HTMLEscaping.attribute(className))\""
        }
        result += ">"
        descendInto(attributes)
        result += "</span>"
    }
}
