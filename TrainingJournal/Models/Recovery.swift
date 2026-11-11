import Foundation

/// Estimates how recovered each muscle group is from when it was last trained.
/// This is a rule of thumb (time since training vs. a typical recovery window),
/// not a physiological measurement, and the UI labels it as an estimate.
nonisolated enum Recovery {
    typealias Muscle = ExerciseCatalog.Muscle

    /// A finished workout: when it ended and which exercises had completed working sets.
    struct Session: Sendable {
        var date: Date
        var exerciseNames: [String]
    }

    struct Status: Identifiable, Equatable, Sendable {
        var muscle: Muscle
        var lastTrained: Date
        /// 0 = just trained, 1 = fully recovered.
        var progress: Double
        var remaining: TimeInterval

        var id: Muscle { muscle }
        var isReady: Bool { progress >= 1 }
    }

    /// Typical recovery windows: larger muscle groups take longer.
    static func recoveryWindow(for muscle: Muscle) -> TimeInterval {
        switch muscle {
        case .chest, .back, .legs: 72 * 3600
        case .shoulders, .arms: 48 * 3600
        case .core: 24 * 3600
        }
    }

    /// Maps an exercise to a muscle group: exact catalog match first, then keywords.
    /// Returns nil for names it can't place.
    static func muscle(for exerciseName: String) -> Muscle? {
        let name = exerciseName.trimmingCharacters(in: .whitespaces)
        if let entry = ExerciseCatalog.entries.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return entry.muscle
        }
        // Keywords match at the start of a word, so "machine" doesn't count as "chin"
        // but "curls" still counts as "curl".
        let words = name.lowercased()
            .split { !$0.isLetter }
            .joined(separator: " ")
        let padded = " " + words
        for (muscle, keywords) in keywordTable where keywords.contains(where: { padded.contains(" " + $0) }) {
            return muscle
        }
        return nil
    }

    /// Checked in order, so more specific groups come first
    /// ("leg curl" is legs, "overhead tricep extension" is arms).
    /// Multi-word keywords use spaces; hyphens in names are treated as spaces.
    private static let keywordTable: [(Muscle, [String])] = [
        (.legs, ["squat", "leg", "lunge", "calf", "calves", "glute", "hamstring", "quad", "hip thrust", "romanian", "rdl", "step up"]),
        (.arms, ["curl", "tricep", "bicep", "skull", "pushdown", "extension"]),
        (.shoulders, ["shoulder", "overhead", "lateral", "delt", "shrug", "military", "arnold", "rear", "reverse fly", "face pull"]),
        (.chest, ["bench", "chest", "fly", "flye", "pec", "push up", "pushup", "dip"]),
        (.back, ["row", "pull", "deadlift", "lat", "chin", "back"]),
        (.core, ["plank", "crunch", "abs", "ab wheel", "core", "sit up", "situp", "oblique"]),
    ]

    /// Recovery for every muscle trained within `lookback`, least recovered first.
    static func statuses(for sessions: [Session], now: Date = .now, lookback: TimeInterval = 14 * 86_400) -> [Status] {
        var lastTrained: [Muscle: Date] = [:]
        for session in sessions where session.date <= now && now.timeIntervalSince(session.date) <= lookback {
            for name in session.exerciseNames {
                guard let muscle = muscle(for: name) else { continue }
                if let existing = lastTrained[muscle], existing >= session.date { continue }
                lastTrained[muscle] = session.date
            }
        }

        return lastTrained.map { muscle, date in
            let window = recoveryWindow(for: muscle)
            let elapsed = now.timeIntervalSince(date)
            return Status(
                muscle: muscle,
                lastTrained: date,
                progress: min(max(elapsed / window, 0), 1),
                remaining: max(window - elapsed, 0)
            )
        }
        .sorted { lhs, rhs in
            lhs.progress != rhs.progress ? lhs.progress < rhs.progress : lhs.muscle.rawValue < rhs.muscle.rawValue
        }
    }

    /// "Ready", "~36 h" or "~3 d".
    static func remainingText(for status: Status) -> String {
        guard !status.isReady else { return "Ready" }
        let hours = Int((status.remaining / 3600).rounded(.up))
        if hours >= 48 {
            return "~\(Int((Double(hours) / 24).rounded())) d"
        }
        return "~\(max(hours, 1)) h"
    }

    /// "Today", "Yesterday" or "3 days ago".
    static func lastTrainedText(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    /// A one-line summary such as "Back and legs ready".
    static func summary(for statuses: [Status]) -> String {
        guard !statuses.isEmpty else { return "" }
        let ready = statuses.filter(\.isReady).map { $0.muscle.rawValue.lowercased() }
        if ready.count == statuses.count { return "All recovered" }
        if ready.isEmpty { return "Recovering" }
        let list = ready.formatted(.list(type: .and))
        return list.prefix(1).uppercased() + list.dropFirst() + " ready"
    }
}
