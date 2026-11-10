import Foundation
import SwiftData

/// A performed workout session. While `endDate` is nil the session is in progress,
/// which is what lets an interrupted workout resume after the app relaunches.
@Model
final class WorkoutLog {
    var workoutName: String
    var startDate: Date
    var endDate: Date?
    var notes: String = ""
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.log)
    var exercises: [LoggedExercise] = []

    init(workoutName: String, startDate: Date = .now, workout: Workout? = nil) {
        self.workoutName = workoutName
        self.startDate = startDate
        self.workout = workout
    }

    var isFinished: Bool { endDate != nil }

    var sortedExercises: [LoggedExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(startDate)
    }

    var completedSets: [LoggedSet] {
        exercises.flatMap(\.sets).filter(\.isCompleted)
    }

    /// Total weight × reps of completed working sets.
    var volume: Double {
        completedSets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
}

@Model
final class LoggedExercise {
    var name: String
    var order: Int
    var restSeconds: Int
    var notes: String = ""
    var log: WorkoutLog?
    /// The planned exercise this came from, used to write results back on finish.
    var template: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var sets: [LoggedSet] = []

    init(name: String, order: Int, restSeconds: Int, notes: String = "", template: Exercise? = nil) {
        self.name = name
        self.order = order
        self.restSeconds = restSeconds
        self.notes = notes
        self.template = template
    }

    var sortedSets: [LoggedSet] {
        sets.sorted { $0.order < $1.order }
    }

    var performances: [SetPerformance] {
        sets.filter(\.isCompleted).map(\.performance)
    }
}

@Model
final class LoggedSet {
    var order: Int
    var weight: Double
    var reps: Int
    var targetReps: Int
    var isWarmup: Bool
    var isCompleted: Bool = false
    var completedAt: Date?
    /// What was done last time, shown as "Last: 135 × 8". Nil for sets added mid-workout.
    var previousWeight: Double?
    var previousReps: Int?
    var exercise: LoggedExercise?

    init(order: Int, weight: Double, reps: Int, targetReps: Int, isWarmup: Bool = false,
         previousWeight: Double? = nil, previousReps: Int? = nil) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.targetReps = targetReps
        self.isWarmup = isWarmup
        self.previousWeight = previousWeight
        self.previousReps = previousReps
    }

    var performance: SetPerformance {
        SetPerformance(weight: weight, reps: reps, targetReps: targetReps, isWarmup: isWarmup)
    }
}
