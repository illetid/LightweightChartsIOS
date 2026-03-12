import Foundation

/// Protocol for validating series data before rendering
public protocol SeriesDataValidator: Sendable {

    /// Validates an array of data points
    /// - Parameter data: The data array to validate
    /// - Throws: SeriesDataValidationError if validation fails
    func validate<T: SeriesData>(data: [T]) throws

    /// Validates a single data point for update operations
    /// - Parameters:
    ///   - bar: The data point to validate
    ///   - latestData: The current latest data point in the series (if any)
    /// - Throws: SeriesDataValidationError if validation fails
    func validateUpdate<T: SeriesData>(bar: T, latestData: T?) throws
}

/// Default validator for all series types
public struct DefaultSeriesDataValidator: SeriesDataValidator, Sendable {

    public init() {}

    public func validate<T: SeriesData>(data: [T]) throws {
        // Empty data is technically valid (clears the series)
        guard !data.isEmpty else { return }

        // Check chronological order and duplicates
        for index in 1..<data.count {
            let previous = data[index - 1]
            let current = data[index]

            guard let comparison = current.time.compare(previous.time) else {
                throw SeriesDataValidationError.dataNotChronological(
                    invalidIndex: index,
                    time: current.time,
                    previousTime: previous.time
                )
            }

            if comparison < 0 {
                throw SeriesDataValidationError.dataNotChronological(
                    invalidIndex: index,
                    time: current.time,
                    previousTime: previous.time
                )
            }

            if comparison == 0 {
                throw SeriesDataValidationError.duplicateTime(
                    time: current.time,
                    firstIndex: index - 1,
                    duplicateIndex: index
                )
            }
        }

        // Type-specific validation
        for item in data {
            try validateItem(item)
        }
    }

    public func validateUpdate<T: SeriesData>(bar: T, latestData: T?) throws {
        // Validate the bar itself
        try validateItem(bar)

        // Check time ordering if we have existing data
        if let latest = latestData {
            guard let comparison = bar.time.compare(latest.time) else {
                throw SeriesDataValidationError.updateTimeBeforeLatest(
                    updateTime: bar.time,
                    latestTime: latest.time
                )
            }

            if comparison < 0 {
                throw SeriesDataValidationError.updateTimeBeforeLatest(
                    updateTime: bar.time,
                    latestTime: latest.time
                )
            }
        }
    }

    private func validateItem<T: SeriesData>(_ item: T) throws {
        // Validate OHLC data
        if let ohlcItem = item as? OhlcData {
            try validateOhlc(ohlcItem)
        }

        // Validate single value data
        if let singleValueItem = item as? SingleValueSeriesData {
            try validateSingleValue(singleValueItem)
        }
    }

    private func validateOhlc(_ item: OhlcData) throws {
        let time = item.time

        // Check for NaN/infinity in numeric values
        if let open = item.open, !open.isFinite {
            throw SeriesDataValidationError.invalidNumericValue(time: time, field: "open", value: open)
        }
        if let high = item.high, !high.isFinite {
            throw SeriesDataValidationError.invalidNumericValue(time: time, field: "high", value: high)
        }
        if let low = item.low, !low.isFinite {
            throw SeriesDataValidationError.invalidNumericValue(time: time, field: "low", value: low)
        }
        if let close = item.close, !close.isFinite {
            throw SeriesDataValidationError.invalidNumericValue(time: time, field: "close", value: close)
        }

        // Validate OHLC relationships if all values are present
        guard let open = item.open,
              let high = item.high,
              let low = item.low,
              let close = item.close else {
            // Partial data is allowed
            return
        }

        if high < open {
            throw SeriesDataValidationError.invalidOhlcData(
                time: time,
                open: open,
                high: high,
                low: low,
                close: close,
                reason: "high (\(high)) is less than open (\(open))"
            )
        }

        if high < close {
            throw SeriesDataValidationError.invalidOhlcData(
                time: time,
                open: open,
                high: high,
                low: low,
                close: close,
                reason: "high (\(high)) is less than close (\(close))"
            )
        }

        if low > open {
            throw SeriesDataValidationError.invalidOhlcData(
                time: time,
                open: open,
                high: high,
                low: low,
                close: close,
                reason: "low (\(low)) is greater than open (\(open))"
            )
        }

        if low > close {
            throw SeriesDataValidationError.invalidOhlcData(
                time: time,
                open: open,
                high: high,
                low: low,
                close: close,
                reason: "low (\(low)) is greater than close (\(close))"
            )
        }
    }

    private func validateSingleValue(_ item: SingleValueSeriesData) throws {
        if let value = item.value, !value.isFinite {
            throw SeriesDataValidationError.invalidNumericValue(time: item.time, field: "value", value: value)
        }
    }
}

/// Shared validator instance
internal let sharedSeriesDataValidator = DefaultSeriesDataValidator()
