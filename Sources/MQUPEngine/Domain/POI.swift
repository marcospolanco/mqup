import Foundation

public struct POI: Equatable, Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let category: String
    public let attributes: Set<String>
    public let hours: WeeklySchedule
    public let latitude: Double
    public let longitude: Double
    public let description: String
    public let embedding: [Double]?

    public init(
        id: UUID,
        name: String,
        category: String,
        attributes: Set<String>,
        hours: WeeklySchedule,
        latitude: Double,
        longitude: Double,
        description: String,
        embedding: [Double]? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.attributes = attributes
        self.hours = hours
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.embedding = embedding
    }
}

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sun = 1, mon, tue, wed, thu, fri, sat

    public static func from(date: Date, calendar: Calendar = .current) -> Weekday {
        let weekday = calendar.component(.weekday, from: date)
        return Weekday(rawValue: weekday) ?? .mon
    }
}

public struct TimeRange: Equatable, Codable, Sendable {
    public let openHour: Int
    public let openMinute: Int
    public let closeHour: Int
    public let closeMinute: Int

    public init(openHour: Int, openMinute: Int, closeHour: Int, closeMinute: Int) {
        self.openHour = openHour
        self.openMinute = openMinute
        self.closeHour = closeHour
        self.closeMinute = closeMinute
    }

    public func contains(minutesFromMidnight minutes: Int) -> Bool {
        let open = openHour * 60 + openMinute
        let close = closeHour * 60 + closeMinute
        if close <= open {
            return minutes >= open || minutes < close
        }
        return minutes >= open && minutes < close
    }
}

public struct WeeklySchedule: Equatable, Codable, Sendable {
    public let hours: [Weekday: [TimeRange]]

    public init(hours: [Weekday: [TimeRange]]) {
        self.hours = hours
    }

    public func isOpen(at date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = Weekday.from(date: date, calendar: calendar)
        guard let ranges = hours[weekday], !ranges.isEmpty else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return ranges.contains { $0.contains(minutesFromMidnight: minutes) }
    }

    public static func alwaysOpen() -> WeeklySchedule {
        let range = TimeRange(openHour: 0, openMinute: 0, closeHour: 23, closeMinute: 59)
        var map: [Weekday: [TimeRange]] = [:]
        for day in Weekday.allCases {
            map[day] = [range]
        }
        return WeeklySchedule(hours: map)
    }

    public static func weekdayBusiness(open: Int = 7, close: Int = 21) -> WeeklySchedule {
        let range = TimeRange(openHour: open, openMinute: 0, closeHour: close, closeMinute: 0)
        var map: [Weekday: [TimeRange]] = [:]
        for day in [Weekday.mon, .tue, .wed, .thu, .fri, .sat, .sun] {
            map[day] = [range]
        }
        return WeeklySchedule(hours: map)
    }
}

extension WeeklySchedule {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: [TimeRange]].self)
        var mapped: [Weekday: [TimeRange]] = [:]
        for (key, value) in raw {
            guard let day = Weekday(rawValue: Int(key) ?? 0) else { continue }
            mapped[day] = value
        }
        hours = mapped
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var raw: [String: [TimeRange]] = [:]
        for (day, ranges) in hours {
            raw[String(day.rawValue)] = ranges
        }
        try container.encode(raw)
    }
}
