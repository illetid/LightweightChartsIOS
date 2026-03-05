import Foundation
import WebKit

public protocol JavaScriptMessageProducer: AnyObject {
    
    func addMessageHandler(_ messageHandler: WKScriptMessageHandler, name: String)
    
}
