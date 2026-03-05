import Foundation

public class SeriesObject: JavaScriptObject {

    static var name: String { String(describing: self) }

    public let jsName: String

    public unowned var context: JavaScriptEvaluator
    weak var closureStore: ClosuresStore?

    /// Tracks the last time set in the series for validation purposes
    internal var _lastDataTime: Time?

    /// Whether validation is enabled for this series
    internal var _validationEnabled: Bool = true

    required init(context: JavaScriptEvaluator, closureStore: ClosuresStore?) {
        self.context = context
        self.closureStore = closureStore
        self.jsName = Self.name + .uniqueString
    }

}
