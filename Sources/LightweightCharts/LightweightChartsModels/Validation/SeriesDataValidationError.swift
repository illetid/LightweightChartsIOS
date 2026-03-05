import Foundation

/// Errors that can occur during series data validation
public enum SeriesDataValidationError: LocalizedError, Equatable {
    /// Data array is not in chronological order
    case dataNotChronological(invalidIndex: Int, time: Time, previousTime: Time)

    /// Duplicate time values found in data array
    case duplicateTime(time: Time, firstIndex: Int, duplicateIndex: Int)

    /// Update time is before the latest time in the series
    case updateTimeBeforeLatest(updateTime: Time, latestTime: Time)

    /// OHLC data validation failed (high < open/close or low > open/close)
    case invalidOhlcData(time: Time, open: Double?, high: Double?, low: Double?, close: Double?, reason: String)

    /// NaN or infinite value detected
    case invalidNumericValue(time: Time, field: String, value: Double)

    /// Empty data array when at least one element is required
    case emptyData

    public var errorDescription: String? {
        switch self {
        case .dataNotChronological(let index, let time, let previousTime):
            return "Data at index \(index) with time \(time) is not in chronological order (should be after \(previousTime))"
        case .duplicateTime(let time, let firstIndex, let duplicateIndex):
            return "Duplicate time \(time) found at indices \(firstIndex) and \(duplicateIndex)"
        case .updateTimeBeforeLatest(let updateTime, let latestTime):
            return "Update time \(updateTime) is before latest series time \(latestTime)"
        case .invalidOhlcData(let time, let open, let high, let low, let close, let reason):
            return "Invalid OHLC data at time \(time): \(reason) [open=\(open?.description ?? "nil"), high=\(high?.description ?? "nil"), low=\(low?.description ?? "nil"), close=\(close?.description ?? "nil")]"
        case .invalidNumericValue(let time, let field, let value):
            return "Invalid numeric value for field '\(field)' at time \(time): \(value)"
        case .emptyData:
            return "Data array cannot be empty"
        }
    }

    public static func == (lhs: SeriesDataValidationError, rhs: SeriesDataValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.dataNotChronological(let i1, let t1, let p1), .dataNotChronological(let i2, let t2, let p2)):
            return i1 == i2 && t1 == t2 && p1 == p2
        case (.duplicateTime(let t1, let f1, let d1), .duplicateTime(let t2, let f2, let d2)):
            return t1 == t2 && f1 == f2 && d1 == d2
        case (.updateTimeBeforeLatest(let u1, let l1), .updateTimeBeforeLatest(let u2, let l2)):
            return u1 == u2 && l1 == l2
        case (.invalidOhlcData(let t1, let o1, let h1, let lo1, let c1, let r1), .invalidOhlcData(let t2, let o2, let h2, let lo2, let c2, let r2)):
            return t1 == t2 && o1 == o2 && h1 == h2 && lo1 == lo2 && c1 == c2 && r1 == r2
        case (.invalidNumericValue(let t1, let f1, let v1), .invalidNumericValue(let t2, let f2, let v2)):
            return t1 == t2 && f1 == f2 && v1 == v2
        case (.emptyData, .emptyData):
            return true
        default:
            return false
        }
    }
}
