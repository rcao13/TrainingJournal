import Foundation

/// A plain value copy of a completed set, so the training math can be tested without SwiftData.
nonisolated struct SetPerformance: Equatable, Sendable {
    var weight: Double
    var reps: Int
    var targetReps: Int
    var isWarmup: Bool = false
}

nonisolated enum TrainingMath {
    /// Epley estimate of a one-rep max. Returns 0 for sets with no reps.
    static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Suggests the next working weight when every working set from last time hit its target reps.
    /// Warm-ups are ignored. Returns nil if there's nothing to go on or a target was missed.
    static func suggestedWeight(lastSets: [SetPerformance], increment: Double) -> Double? {
        let working = lastSets.filter { !$0.isWarmup }
        guard !working.isEmpty, increment > 0,
              working.allSatisfy({ $0.reps >= $0.targetReps }),
              let heaviest = working.map(\.weight).max(), heaviest > 0
        else { return nil }
        return heaviest + increment
    }
}

/// Best lifts for one exercise across a set of performances (warm-ups excluded).
nonisolated struct PersonalRecords: Equatable, Sendable {
    var heaviestWeight: Double = 0
    var bestEstimated1RM: Double = 0

    init(heaviestWeight: Double = 0, bestEstimated1RM: Double = 0) {
        self.heaviestWeight = heaviestWeight
        self.bestEstimated1RM = bestEstimated1RM
    }

    init(_ sets: [SetPerformance]) {
        for set in sets where !set.isWarmup && set.reps > 0 {
            heaviestWeight = max(heaviestWeight, set.weight)
            bestEstimated1RM = max(bestEstimated1RM, TrainingMath.estimated1RM(weight: set.weight, reps: set.reps))
        }
    }

    var isEmpty: Bool { heaviestWeight == 0 && bestEstimated1RM == 0 }
}

/// A personal record set during a session.
nonisolated struct RecordHit: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case heaviestWeight = "Heaviest weight"
        case estimated1RM = "Best est. 1RM"
    }

    var exerciseName: String
    var kind: Kind
    var value: Double

    var id: String { "\(exerciseName)-\(kind.rawValue)" }

    /// Compares this session's sets for one exercise with all earlier history.
    /// The first time an exercise is ever logged doesn't count as a record.
    static func hits(exerciseName: String, current: [SetPerformance], history: [SetPerformance]) -> [RecordHit] {
        let now = PersonalRecords(current)
        let before = PersonalRecords(history)
        guard !before.isEmpty, !now.isEmpty else { return [] }
        var hits: [RecordHit] = []
        if now.heaviestWeight > before.heaviestWeight {
            hits.append(RecordHit(exerciseName: exerciseName, kind: .heaviestWeight, value: now.heaviestWeight))
        }
        if now.bestEstimated1RM > before.bestEstimated1RM + 0.05 {
            hits.append(RecordHit(exerciseName: exerciseName, kind: .estimated1RM, value: now.bestEstimated1RM))
        }
        return hits
    }
}
