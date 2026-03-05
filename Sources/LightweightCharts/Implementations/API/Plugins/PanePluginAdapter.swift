import Foundation

/// Base adapter class for pane plugins.
///
/// This class provides shared functionality for all plugins attached to a chart pane,
/// including JavaScript variable naming strategy and detach behavior.
///
/// Subclasses should:
/// 1. Call the designated initializer with the chart reference and pane index
/// 2. Implement any plugin-specific functionality
/// 3. Optionally override `detach()` if custom cleanup is needed
open class PanePluginAdapter<Chart>: PanePlugin where Chart: JavaScriptObject {

    // MARK: - PanePlugin Conformance

    /// The index of the pane this plugin is attached to.
    ///
    /// Pane indices correspond to the chart's `panes()` array,
    /// where 0 is the main pane.
    public let paneIndex: Int

    // MARK: - Properties

    /// The JavaScript variable name for this plugin instance.
    ///
    /// This name is generated once during initialization and used
    /// to reference the plugin object in JavaScript.
    public let jsName: String

    /// The JavaScript variable name of the chart.
    private let chartJsName: String

    /// The JavaScript evaluator context for script execution.
    /// Accessible to subclasses for script evaluation.
    private weak var _context: JavaScriptEvaluator?

    /// The JavaScript evaluator context for script execution, if still available.
    var context: JavaScriptEvaluator? {
        _context
    }

    /// Whether this plugin has been detached.
    private(set) public var isDetached: Bool = false

    // MARK: - Initialization

    /// Initializes a new pane plugin adapter.
    ///
    /// - Parameters:
    ///   - chart: The chart this plugin is attached to. Used to access the chart's JavaScript name.
    ///   - paneIndex: The index of the pane this plugin is attached to.
    ///   - context: The JavaScript evaluator context for script execution.
    public init(chart: Chart, paneIndex: Int, context: JavaScriptEvaluator) {
        self.chartJsName = chart.jsName
        self.paneIndex = paneIndex
        self._context = context
        self.jsName = PanePluginAdapter.makeJSName()
    }

    // MARK: - Plugin Conformance

    /// Detaches (removes) the plugin from the chart.
    ///
    /// After calling this method, the plugin is removed from the chart
    /// and should no longer be used. This is an irreversible operation.
    ///
    /// Subclasses can override this method to perform custom cleanup,
    /// but must call `super.detach()` to ensure proper cleanup.
    public func detach() {
        isDetached = true
    }

    // MARK: - Helper Methods

    /// Evaluates JavaScript code in the chart context.
    ///
    /// - Parameter script: The JavaScript code to evaluate.
    /// - Parameter completion: Optional completion handler with result and error.
    func evaluateScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        guard let context = _context else {
            completion?(nil, nil)
            return
        }
        context.evaluateScript(script, completion: completion)
    }

    /// Evaluates JavaScript code and decodes the result as a specified type.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - type: The type to decode the result as.
    ///   - completion: Completion handler with the decoded result or error.
    func evaluate<T: Decodable>(
        script: String,
        resultType: T.Type,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let context = _context else {
            completion(.failure(NSError(domain: "LightweightCharts", code: 1, userInfo: [NSLocalizedDescriptionKey: "JavaScript context is no longer available."])))
            return
        }
        context.evaluate(script: script, resultType: resultType, completion: completion)
    }

    /// Evaluates JavaScript code and decodes the result as a specified type.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - completion: Completion handler with the decoded result or nil if decoding fails.
    func decodedResult<T: Decodable>(
        forScript script: String,
        completion: @escaping (T?) -> Void
    ) {
        guard let context = _context else {
            completion(nil)
            return
        }
        context.decodedResult(forScript: script, completion: completion)
    }

    /// Returns a JavaScript expression that accesses the pane this plugin is attached to.
    ///
    /// This can be used by subclasses to build JavaScript scripts that
    /// operate on the pane.
    ///
    /// - Returns: A JavaScript expression for accessing the pane.
    func paneExpression() -> String {
        return "\(chartJsName).panes()[\(paneIndex)]"
    }

    // MARK: - Private Methods

    /// Generates a unique JavaScript variable name for a plugin instance.
    ///
    /// - Returns: A unique JavaScript variable name.
    private static func makeJSName() -> String {
        return "paneplugin_\(String.uniqueString)"
    }
}
