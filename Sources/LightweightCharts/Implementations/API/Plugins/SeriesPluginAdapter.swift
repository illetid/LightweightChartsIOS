import Foundation

/// Base adapter class for series plugins.
///
/// This class provides shared functionality for all plugins attached to a series,
/// including JavaScript variable naming strategy and detach behavior.
///
/// Subclasses should:
/// 1. Call the designated initializer with the series reference
/// 2. Implement any plugin-specific functionality
/// 3. Optionally override `detach()` if custom cleanup is needed
@MainActor
open class SeriesPluginAdapter<Series>: SeriesPlugin where Series: SeriesApi & SeriesObject {

    // MARK: - SeriesPlugin Conformance

    /// The series this plugin is attached to.
    ///
    /// This reference is weak to avoid retain cycles,
    /// as the series typically holds strong references to its plugins.
    public weak var series: Series?

    // MARK: - Properties

    /// The JavaScript variable name for this plugin instance.
    ///
    /// This name is generated once during initialization and used
    /// to reference the plugin object in JavaScript.
    public let jsName: String

    /// The JavaScript evaluator context for script execution.
    private weak var context: JavaScriptEvaluator?

    /// Whether this plugin has been detached.
    private(set) public var isDetached: Bool = false

    // MARK: - Initialization

    /// Initializes a new series plugin adapter.
    ///
    /// - Parameter series: The series this plugin is attached to.
    public init(series: Series) {
        self.series = series
        self.context = series.context
        self.jsName = SeriesPluginAdapter.makeJSName(for: type(of: series))
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

        // Clear the series reference
        series = nil
    }

    // MARK: - Helper Methods

    /// Evaluates JavaScript code in the chart context.
    ///
    /// - Parameter script: The JavaScript code to evaluate.
    func evaluateScript(_ script: String) {
        guard let context = context else { return }
        context.submitScript(script)
    }

    func requireContext() throws(JavaScriptBridgeError) -> JavaScriptEvaluator {
        guard let context else {
            throw JavaScriptBridgeError.contextUnavailable
        }
        return context
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
        guard let context = context else {
            completion(.failure(JavaScriptBridgeError.contextUnavailable))
            return
        }

        if let callbackContext = context as? JavaScriptCallbackEvaluator {
            callbackContext.evaluate(script: script, resultType: resultType, completion: completion)
            return
        }

        completion(.failure(JavaScriptBridgeError.contextUnavailable))
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
        guard let context = context else {
            completion(nil)
            return
        }

        guard let callbackContext = context as? JavaScriptCallbackEvaluator else {
            completion(nil)
            return
        }

        callbackContext.decodedResult(forScript: script) { (result: Result<T, Error>) in
            switch result {
            case .success(let value):
                completion(value)
            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - Private Methods

    /// Generates a unique JavaScript variable name for a plugin instance.
    ///
    /// - Parameter seriesType: The type of the series the plugin is attached to.
    /// - Returns: A unique JavaScript variable name.
    private static func makeJSName(for seriesType: Any.Type) -> String {
        let seriesName = String(describing: seriesType)
        return "plugin_\(seriesName)_\(String.uniqueString)"
    }
}
