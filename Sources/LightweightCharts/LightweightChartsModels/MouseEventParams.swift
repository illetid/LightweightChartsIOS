
import Foundation

// MARK: -
public enum EventTime {
    case utc(timestamp: Double)
    case businessDay(BusinessDay)
    case businessDayString(String)
}

// MARK: -
public enum EventPrices {
    case barData(BarData)
    case lineData(LineData)
    case none
}

// MARK: -
public struct TouchMouseEventData: Codable {
    
    /**
     * The X coordinate of the mouse pointer in local (DOM content) coordinates.
     */
    public let  clientX: Double?
    
    /**
     * The Y coordinate of the mouse pointer in local (DOM content) coordinates.
     */
    public let  clientY: Double?
    
    /**
     * The X coordinate of the mouse pointer relative to the whole document.
     */
    public let  pageX: Double?
    
    /**
     * The Y coordinate of the mouse pointer relative to the whole document.
     */
    public let  pageY: Double?
    
    /**
     * The X coordinate of the mouse pointer in global (screen) coordinates.
     */
    public let  screenX: Double?
    
    /**
     * The Y coordinate of the mouse pointer in global (screen) coordinates.
     */
    public let  screenY: Double?
    
    /**
     * The X coordinate of the mouse pointer relative to the chart / price axis / time axis canvas element.
     */
    public let  localX: Double?
    
    /**
     * The Y coordinate of the mouse pointer relative to the chart / price axis / time axis canvas element.
     */
    public let  localY: Double?
    
    /**
     * Returns a boolean value that is true if the Ctrl key was active when the key event was generated.
     */
    public let  ctrlKey: Bool?
    
    /**
     * Returns a boolean value that is true if the Alt (Option or ⌥ on macOS) key was active when the
     * key event was generated.
     */
    public let  altKey: Bool?
    
    /**
     * Returns a boolean value that is true if the Shift key was active when the key event was generated.
     */
    public let  shiftKey: Bool?
    
    /**
     * Returns a boolean value that is true if the Meta key (on Mac keyboards, the ⌘ Command key; on
     * Windows keyboards, the Windows key (⊞)) was active when the key event was generated.
     */
    public let  metaKey: Bool?
    
    public init(clientX: Double?,
                clientY: Double?,
                pageX: Double?,
                pageY: Double?,
                screenX: Double?,
                screenY: Double?,
                localX: Double?,
                localY: Double?,
                ctrlKey: Bool?,
                altKey: Bool?,
                shiftKey: Bool?,
                metaKey: Bool?) {
        self.clientX = clientX
        self.clientY = clientY
        self.pageX = pageX
        self.pageY = pageY
        self.screenX = screenX
        self.screenY = screenY
        self.localX = localX
        self.localY = localY
        self.ctrlKey = ctrlKey
        self.altKey = altKey
        self.shiftKey = shiftKey
        self.metaKey = metaKey
    }
    
}


// MARK: -
public struct MouseEventParams: Codable {
    
    public let time: EventTime?
    public let logical: Int?
    public let point: Point?
    public let hoveredObjectId: Int?
    public let sourceEvent: TouchMouseEventData?
    
    public let hoveredSeries: String?
    
    private let seriesData: [String: EventPrices?]

    enum CodingKeys: String, CodingKey {
        case time
        case logical
        case point
        case hoveredObjectId
        case sourceEvent
        case hoveredSeries
        case seriesData
    }
    
    public init(time: EventTime?, logical: Int?, point: Point?, hoveredObjectId: Int?, sourceEvent: TouchMouseEventData?, hoveredSeries: String?) {
        self.time = time
        self.logical = logical
        self.point = point
        self.hoveredObjectId = hoveredObjectId
        self.sourceEvent = sourceEvent
        self.seriesData = [:]
        self.hoveredSeries = hoveredSeries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decodeIfPresent(EventTime.self, forKey: .time)
        logical = try container.decodeIfPresent(Int.self, forKey: .logical)
        point = try container.decodeIfPresent(Point.self, forKey: .point)
        hoveredObjectId = try container.decodeIfPresent(Int.self, forKey: .hoveredObjectId)
        sourceEvent = try container.decodeIfPresent(TouchMouseEventData.self, forKey: .sourceEvent)
        hoveredSeries = try container.decodeIfPresent(String.self, forKey: .hoveredSeries)
        seriesData = try container.decodeIfPresent([String: EventPrices?].self, forKey: .seriesData) ?? [:]
    }
    
    public func price(forSeries series: SeriesObject) -> EventPrices? {
        seriesData[series.jsName] ?? nil
    }
    
}

// MARK: - EventTime Cadable
extension EventTime: Codable, Equatable {
    
    // MARK: Decodable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let utcTimestamp = try? container.decode(Double.self) {
            self = .utc(timestamp: utcTimestamp)
        } else if let businessDay = try? container.decode(BusinessDay.self) {
            self = .businessDay(businessDay)
        } else if let businessDayString = try? container.decode(String.self) {
            self = .businessDayString(businessDayString)
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Error decoding \(type(of: self))")
        }
    }
    
    // MARK: Encodable
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .utc(timestamp: timestamp):
            try container.encode(timestamp)
        case let .businessDay(businessDay):
            try container.encode(businessDay)
        case let .businessDayString(businessDayString):
            try container.encode(businessDayString)
        }
    }
    
}

// MARK: - EventPrices Cadable
extension EventPrices: Codable, Equatable {
    
    // MARK: Decodable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        struct EventLineValue: Decodable {
            let value: Double?
        }

        struct EventBarValue: Decodable {
            let open: Double?
            let high: Double?
            let low: Double?
            let close: Double?
        }

        if let lineValue = try? container.decode(EventLineValue.self), let value = lineValue.value {
            self = .lineData(LineData(time: .utc(timestamp: 0), value: value))
            return
        }

        if let barValue = try? container.decode(EventBarValue.self),
           let open = barValue.open,
           let high = barValue.high,
           let low = barValue.low,
           let close = barValue.close {
            self = .barData(BarData(time: .utc(timestamp: 0), open: open, high: high, low: low, close: close))
            return
        }

        if let lineData = try? container.decode(LineData.self), lineData.value != nil {
            self = .lineData(lineData)
        } else if let barData = try? container.decode(BarData.self) {
            self = .barData(barData)
        } else {
            self = .none
        }
    }
    
    // MARK: Encodable
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .barData(value):
            try container.encode(value)
        case let .lineData(value):
            try container.encode(value)
        case .none:
            break
        }
    }
    
}
