import Foundation

/// Protocol for chart objects that provide JavaScript evaluation context.
///
/// This protocol defines the basic requirements for objects that represent
/// charts and need to evaluate JavaScript code.
public protocol ChartObject: JavaScriptObject {

    /// The JavaScript evaluator context for script execution.
    var context: any JavaScriptEvaluator { get }

}
