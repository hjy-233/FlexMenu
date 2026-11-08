import Foundation

struct EditableMenuItem: Identifiable, Equatable {
    let identity = UUID()
    var id: String
    var title: String
    var action: String

    init(_ item: MenuItemDefinition) {
        id = item.id
        title = item.title
        action = item.action
    }

    init() {
        id = ""
        title = ""
        action = ""
    }

    var definition: MenuItemDefinition {
        MenuItemDefinition(id: id, title: title, action: action)
    }
}

struct VisualMenuScript {
    enum Kind {
        case plain
        case fileOnly
    }

    let kind: Kind
    let output: MenuOutput

    private static let fileOnlyPrefix = "#!/bin/zsh\n" +
        "if (( $# == 0 )); then\n" +
        "    print -r -- '{\"mode\":\"dragging\",\"items\":[]}'\n" +
        "    exit 0\n" +
        "fi\n"

    static func parse(_ source: String) -> VisualMenuScript? {
        let kind: Kind
        let body: String
        if source.hasPrefix(fileOnlyPrefix) {
            kind = .fileOnly
            body = String(source.dropFirst(fileOnlyPrefix.count))
        } else {
            kind = .plain
            body = source
        }
        guard let json = jsonBody(body),
              let output = try? JSONDecoder().decode(MenuOutput.self, from: Data(json.utf8))
        else { return nil }
        return VisualMenuScript(kind: kind, output: output)
    }

    func render(mode: String, items: [EditableMenuItem]) throws -> String {
        let output = MenuOutput(
            mode: mode == "any" ? nil : mode,
            items: items.map(\.definition)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)
        guard let json = String(data: data, encoding: .utf8) else {
            throw FlexMenuFailure.message(L10n.text("无法生成菜单 JSON"))
        }
        let prefix = kind == .fileOnly ? Self.fileOnlyPrefix : "#!/bin/zsh\n"
        return prefix + "cat <<'JSON'\n" + json + "\nJSON\n"
    }

    private static func jsonBody(_ source: String) -> String? {
        let heredoc = "cat <<'JSON'\n"
        if source.hasPrefix(heredoc), source.hasSuffix("\nJSON\n") {
            let start = source.index(source.startIndex, offsetBy: heredoc.count)
            let end = source.index(source.endIndex, offsetBy: -"\nJSON\n".count)
            return String(source[start ..< end])
        }
        let plainHeredoc = source.hasPrefix("#!/bin/zsh\n" + heredoc) &&
            source.hasSuffix("\nJSON\n")
        if plainHeredoc {
            let start = source.index(source.startIndex, offsetBy: "#!/bin/zsh\n".count + heredoc.count)
            let end = source.index(source.endIndex, offsetBy: -"\nJSON\n".count)
            return String(source[start ..< end])
        }
        if source.hasPrefix("print -r -- '"), source.hasSuffix("'\n") {
            return String(source.dropFirst("print -r -- '".count).dropLast(2))
        }
        return nil
    }
}
