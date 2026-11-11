import Foundation

/// One row on the Today timeline.
nonisolated struct TimelineItem: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case meal, workout, inProgress, planned, weighIn
    }

    var id: String
    var kind: Kind
    /// Nil for planned workouts, which have no time yet and go at the end.
    var start: Date?
    var end: Date?
    var title: String
    var detail: String
}

nonisolated enum TimelineEntry: Identifiable, Equatable, Sendable {
    case item(TimelineItem)
    /// A chip between two items, e.g. "50 min after training".
    case gap(id: String, text: String)

    var id: String {
        switch self {
        case .item(let item): item.id
        case .gap(let id, _): id
        }
    }
}

/// Builds the Today timeline from plain values so it can be unit tested.
nonisolated enum DayTimeline {
    struct FoodInput: Sendable {
        var name: String
        var meal: String
        var date: Date
        var calories: Double
        var protein: Double
    }

    /// One row per meal, at the earliest logged time: the foods eaten and the meal's totals.
    static func mealItems(from foods: [FoodInput]) -> [TimelineItem] {
        Dictionary(grouping: foods, by: \.meal).map { meal, entries in
            let sorted = entries.sorted { $0.date < $1.date }
            let calories: Double = entries.reduce(0) { $0 + $1.calories }
            let protein: Double = entries.reduce(0) { $0 + $1.protein }
            let caloriesText = calories.formatted(.number.precision(.fractionLength(0)))
            let proteinText = protein.formatted(.number.precision(.fractionLength(0)))
            return TimelineItem(
                id: "meal-\(meal)",
                kind: .meal,
                start: sorted.first?.date,
                end: nil,
                title: meal,
                detail: "\(foodList(sorted.map(\.name))) · \(caloriesText) kcal · \(proteinText) g protein"
            )
        }
    }

    /// "Oats", "Oats, Banana" or "Oats, Banana +2".
    static func foodList(_ names: [String]) -> String {
        let shown = names.prefix(2).joined(separator: ", ")
        let extra = names.count - 2
        return extra > 0 ? "\(shown) +\(extra)" : shown
    }

    /// Timed items in order with gap chips between them, then planned items.
    static func entries(for items: [TimelineItem], minimumGap: TimeInterval = 15 * 60) -> [TimelineEntry] {
        var timed: [(start: Date, item: TimelineItem)] = []
        for item in items {
            if let start = item.start {
                timed.append((start: start, item: item))
            }
        }
        timed.sort { lhs, rhs in
            if lhs.start == rhs.start { return lhs.item.id < rhs.item.id }
            return lhs.start < rhs.start
        }

        var result: [TimelineEntry] = []
        var previous: TimelineItem?
        for (start, item) in timed {
            if let previous {
                let previousEnd = previous.end ?? previous.start ?? start
                let gap = start.timeIntervalSince(previousEnd)
                if gap >= minimumGap {
                    result.append(.gap(
                        id: "gap-\(previous.id)-\(item.id)",
                        text: gapText(gap, after: previous.kind, before: item.kind)
                    ))
                }
            }
            result.append(.item(item))
            previous = item
        }
        result += items.filter { $0.start == nil }.map { .item($0) }
        return result
    }

    /// "4h 40m", "50 min after training", "2h before training".
    static func gapText(_ interval: TimeInterval, after previous: TimelineItem.Kind, before next: TimelineItem.Kind) -> String {
        let duration = durationText(interval)
        if previous == .workout && next == .meal {
            return "\(duration) after training"
        }
        if previous == .meal && (next == .workout || next == .inProgress) {
            return "\(duration) before training"
        }
        return duration
    }

    /// "50 min", "2h", "4h 40m".
    static func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}
