import Foundation

@MainActor
public class SeriesObject: JavaScriptObject {

    public typealias DataChangedContinuation = AsyncStream<DataChangedScope>.Continuation

    nonisolated static var name: String { String(describing: self) }

    public let jsName: String

    public unowned var context: JavaScriptEvaluator
    weak var closureStore: ClosuresStore?
    internal var chartJSName: String?
    private weak var messageProducer: (any JavaScriptMessageProducer)?
    private let messageHandler: MessageHandler
    private var dataChangedSubscriptionState: Chart.SubscribeState = .declared
    private var manualDataChangedSubscription = false
    private var dataChangedContinuations: [UUID: DataChangedContinuation] = [:]

    public weak var delegate: SeriesDelegate?

    /// Tracks the last time set in the series for validation purposes
    internal var _lastDataTime: Time?

    /// Whether validation is enabled for this series
    internal var _validationEnabled: Bool = true

    required init(context: JavaScriptEvaluator, closureStore: ClosuresStore?) {
        self.jsName = Self.name + .uniqueString
        self.context = context
        self.closureStore = closureStore
        self.messageProducer = context as? any JavaScriptMessageProducer
        self.messageHandler = MessageHandler()
        self.messageHandler.delegate = self
    }

    internal init(context: JavaScriptEvaluator, closureStore: ClosuresStore?, jsName: String) {
        self.jsName = jsName
        self.context = context
        self.closureStore = closureStore
        self.messageProducer = context as? any JavaScriptMessageProducer
        self.messageHandler = MessageHandler()
        self.messageHandler.delegate = self
    }

    internal func activateDataChangedSubscriptionIfNeeded() {
        guard dataChangedSubscriptionState != .active else {
            return
        }

        guard let messageProducer else {
            return
        }

        let name = "\(Subscription.dataChanged.rawValue)_\(jsName)"
        var subscriberScript = ""
        if dataChangedSubscriptionState == .declared {
            subscriberScript = "var \(name) = postMessageFunction('\(name)');"
            messageProducer.addMessageHandler(messageHandler, name: name)
        }
        let script = subscriberScript + "\n\(jsName).subscribeDataChanged(\(name));"
        context.submitScript(script)
        dataChangedSubscriptionState = .active
    }

    internal func deactivateDataChangedSubscription() {
        guard dataChangedSubscriptionState == .active else {
            return
        }

        let name = "\(Subscription.dataChanged.rawValue)_\(jsName)"
        let script = "\(jsName).unsubscribeDataChanged(\(name));"
        context.submitScript(script)
        dataChangedSubscriptionState = .declared
    }

    internal func deactivateDataChangedSubscriptionIfPossible() {
        guard !manualDataChangedSubscription, dataChangedContinuations.isEmpty else {
            return
        }

        deactivateDataChangedSubscription()
    }

    internal func subscribeToDataChanged() {
        manualDataChangedSubscription = true
        activateDataChangedSubscriptionIfNeeded()
    }

    internal func unsubscribeFromDataChanged() {
        manualDataChangedSubscription = false
        deactivateDataChangedSubscriptionIfPossible()
    }

    internal func makeDataChangedStream() -> AsyncStream<DataChangedScope> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            dataChangedContinuations[id] = continuation
            activateDataChangedSubscriptionIfNeeded()

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.dataChangedContinuations.removeValue(forKey: id)
                    self.deactivateDataChangedSubscriptionIfPossible()
                }
            }
        }
    }

    internal func yieldDataChanged(_ scope: DataChangedScope) {
        dataChangedContinuations.values.forEach { $0.yield(scope) }
    }

}

extension SeriesObject: MessageHandlerDelegate {

    func messageHandler(_ messageHandler: MessageHandler, didReceiveClickWithParameters parameters: MouseEventParams) {
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveDblClickWithParameters parameters: MouseEventParams) {
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveCrosshairMoveWithParameters parameters: MouseEventParams) {
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveDataChangedWithScope scope: DataChangedScope) {
        if let series = self as? any SeriesApi {
            delegate?.didDataChange(onSeries: series, scope: scope)
        }
        yieldDataChanged(scope)
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveVisibleTimeRangeChangeWithParameters parameters: TimeRange?) {
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveVisibleLogicalRangeChangeWithParameters parameters: LogicalRange?) {
    }

    func messageHandler(_ messageHandler: MessageHandler, didReceiveTimeScaleSizeChangeWithParameters parameters: Rectangle?) {
    }
}
