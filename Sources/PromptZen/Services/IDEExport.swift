import AppKit
import Foundation

enum IDEExport {
    /// Plain prompt body for pasting into chat or editor.
    static func copyPlain(_ body: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(body, forType: .string)
    }

    /// Wrapped block for tools that benefit from a labeled paste (Cursor, VS Code notes, etc.).
    static func copyWithIDEHeader(title: String, category: String, body: String) {
        let block = """
        <!-- PromptZen: \(title) [\(category)] -->
        \(body)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(block, forType: .string)
    }
}
