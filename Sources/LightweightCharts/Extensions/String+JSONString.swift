import Foundation

extension String {

    /// Returns a JSON-encoded string representation.
    ///
    /// This method escapes special characters for JSON compatibility,
    /// including quotes, backslashes, and control characters.
    ///
    /// - Returns: A JSON-encoded string with quotes and proper escaping.
    func jsonString() -> String {
        // Escape backslashes and quotes
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")

        // Wrap in quotes for JSON string representation
        return "\"\(escaped)\""
    }

}
