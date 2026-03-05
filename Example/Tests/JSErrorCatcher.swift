import XCTest
import WebKit
@testable import LightweightCharts

/// Captures JavaScript evaluation errors for testing purposes
class JSErrorCatcher: NSObject {

    struct JSError: Equatable {
        let script: String
        let errorDescription: String

        static func == (lhs: JSError, rhs: JSError) -> Bool {
            return lhs.script == rhs.script && lhs.errorDescription == rhs.errorDescription
        }
    }

    private(set) var errors: [JSError] = []

    override init() {
        super.init()
    }

    func recordError(script: String, error: Error) {
        let errorDesc = error.localizedDescription
        errors.append(JSError(script: script, errorDescription: errorDesc))
    }

    func clear() {
        errors.removeAll()
    }

    var hasErrors: Bool {
        return !errors.isEmpty
    }

    var lastError: JSError? {
        return errors.last
    }

    /// Asserts that at least one JavaScript error was captured
    func assertErrorOccurred(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(hasErrors, "Expected a JavaScript error to occur, but none were captured", file: file, line: line)
    }

    /// Asserts that no JavaScript errors were captured
    func assertNoErrors(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(hasErrors, "Expected no JavaScript errors, but \(errors.count) error(s) were captured: \(errors)", file: file, line: line)
    }

    /// Asserts that an error containing the expected substring was captured
    func assertErrorContains(_ substring: String, file: StaticString = #file, line: UInt = #line) {
        let contains = errors.contains { error in
            error.errorDescription.contains(substring) || error.script.contains(substring)
        }
        XCTAssertTrue(contains, "Expected to find an error containing '\(substring)', but got: \(errors)", file: file, line: line)
    }

    // MARK: - Script Evaluation Failure Assertions

    /// Asserts that exactly the specified number of errors were captured
    func assertErrorCount(_ expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        let actualCount = errors.count
        XCTAssertEqual(
            actualCount,
            expectedCount,
            "Expected \(expectedCount) error(s), but captured \(actualCount): \(errors)",
            file: file,
            line: line
        )
    }

    /// Asserts that a specific script (or script containing substring) failed to evaluate
    func assertScriptFailed(_ scriptSubstring: String, file: StaticString = #file, line: UInt = #line) {
        let failed = errors.contains { error in
            error.script.contains(scriptSubstring)
        }
        XCTAssertTrue(
            failed,
            "Expected script containing '\(scriptSubstring)' to fail, but no such error was found. Captured errors: \(errors)",
            file: file,
            line: line
        )
    }

    /// Asserts that the last error contains the expected substring
    func assertLastErrorContains(_ substring: String, file: StaticString = #file, line: UInt = #line) {
        guard let last = lastError else {
            XCTFail("Expected last error to contain '\(substring)', but no errors were captured", file: file, line: line)
            return
        }
        XCTAssertTrue(
            last.errorDescription.contains(substring) || last.script.contains(substring),
            "Expected last error to contain '\(substring)', but got: \(last)",
            file: file,
            line: line
        )
    }

    /// Asserts that an error matching the given regex pattern was captured
    func assertErrorMatches(_ pattern: String, file: StaticString = #file, line: UInt = #line) {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = errors.contains { error in
                regex.firstMatch(in: error.errorDescription, range: NSRange(error.errorDescription.startIndex..., in: error.errorDescription)) != nil
            }
            XCTAssertTrue(
                matches,
                "Expected to find an error matching pattern '\(pattern)', but got: \(errors)",
                file: file,
                line: line
            )
        } catch {
            XCTFail("Invalid regex pattern '\(pattern)': \(error)", file: file, line: line)
        }
    }

    /// Asserts that an error of the expected category/type was captured
    func assertErrorCategory(_ category: ErrorCategory, file: StaticString = #file, line: UInt = #line) {
        let matches = errors.contains { error in
            category.matches(error.errorDescription)
        }
        XCTAssertTrue(
            matches,
            "Expected to find a \(category.rawValue) error, but got: \(errors)",
            file: file,
            line: line
        )
    }

    /// Asserts that all errors contain the expected substring
    func assertAllErrorsContain(_ substring: String, file: StaticString = #file, line: UInt = #line) {
        let allMatch = errors.allSatisfy { error in
            error.errorDescription.contains(substring)
        }
        XCTAssertTrue(
            allMatch,
            "Expected all errors to contain '\(substring)', but some did not: \(errors)",
            file: file,
            line: line
        )
    }

    /// Asserts that no errors contain the specified substring
    func assertNoErrorsContain(_ substring: String, file: StaticString = #file, line: UInt = #line) {
        let contains = errors.contains { error in
            error.errorDescription.contains(substring)
        }
        XCTAssertFalse(
            contains,
            "Expected no errors to contain '\(substring)', but found some: \(errors)",
            file: file,
            line: line
        )
    }

    /// Returns the first error whose description contains the given substring
    func firstErrorContaining(_ substring: String) -> JSError? {
        return errors.first { error in
            error.errorDescription.contains(substring)
        }
    }

    /// Asserts that an error was captured for a script and returns that error
    func assertErrorForScript(
        _ scriptSubstring: String,
        file: StaticString = #file,
        line: UInt = #line
    ) -> JSError? {
        let matchingError = errors.first { error in
            error.script.contains(scriptSubstring)
        }

        XCTAssertNotNil(
            matchingError,
            "Expected to find error for script containing '\(scriptSubstring)', but got: \(errors)",
            file: file,
            line: line
        )

        return matchingError
    }
}

/// Categories of JavaScript errors that can occur during script evaluation
enum ErrorCategory: String {
    case syntaxError = "SyntaxError"
    case referenceError = "ReferenceError"
    case typeError = "TypeError"
    case rangeError = "RangeError"
    case genericError = "Error"

    func matches(_ errorDescription: String) -> Bool {
        return errorDescription.contains(rawValue)
    }
}

// MARK: - JavaScriptErrorDelegate
extension JSErrorCatcher: JavaScriptErrorDelegate {

    func didFailEvaluateScript(_ script: String, withError error: Error) {
        recordError(script: script, error: error)
    }
}

// MARK: - TestErrorCatcher Type Alias
/// Type alias for JSErrorCatcher for consistency across test files
typealias TestErrorCatcher = JSErrorCatcher

// MARK: - XCTest Assertions
extension XCTestCase {

    /// Creates a JSErrorCatcher and attaches it to the LightweightCharts instance
    func attachErrorCatcher(to charts: LightweightCharts) -> JSErrorCatcher {
        let catcher = JSErrorCatcher()
        charts.errorDelegate = catcher
        return catcher
    }
}
