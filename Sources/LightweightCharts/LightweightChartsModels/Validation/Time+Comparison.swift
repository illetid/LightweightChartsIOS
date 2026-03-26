import Foundation

extension Time {

    /// Compares two Time values for ordering
    /// - Returns: -1 if self < other, 0 if equal, 1 if self > other, or nil if incomparable
    func compare(_ other: Time) -> Int? {
        switch (self, other) {
        case (.utc(let lhs), .utc(let rhs)):
            if lhs < rhs { return -1 }
            if lhs > rhs { return 1 }
            return 0

        case (.string(let lhs), .string(let rhs)):
            // For ISO8601 strings, do lexical comparison which works for chronological ordering
            if lhs < rhs { return -1 }
            if lhs > rhs { return 1 }
            return 0

        case (.businessDay(let lhs), .businessDay(let rhs)):
            // Compare year, then month, then day
            if lhs.year != rhs.year {
                return lhs.year < rhs.year ? -1 : 1
            }
            if lhs.month != rhs.month {
                return lhs.month < rhs.month ? -1 : 1
            }
            if lhs.day != rhs.day {
                return lhs.day < rhs.day ? -1 : 1
            }
            return 0

        case (.utc, .businessDay), (.businessDay, .utc),
             (.utc, .string), (.string, .utc),
             (.businessDay, .string), (.string, .businessDay):
            // Cannot compare different time types
            return nil
        }
    }

    /// Returns true if this time is strictly after the other time
    func isAfter(_ other: Time) -> Bool {
        return compare(other) == 1
    }

    /// Returns true if this time is strictly before the other time
    func isBefore(_ other: Time) -> Bool {
        return compare(other) == -1
    }

    /// Returns true if this time is equal to or after the other time
    func isAfterOrEqual(_ other: Time) -> Bool {
        guard let comparison = compare(other) else { return false }
        return comparison >= 0
    }

    /// Returns true if this time is equal to or before the other time
    func isBeforeOrEqual(_ other: Time) -> Bool {
        guard let comparison = compare(other) else { return false }
        return comparison <= 0
    }

    /// Returns true if the two times are equal
    func isEqual(to other: Time) -> Bool {
        return compare(other) == 0
    }
}
