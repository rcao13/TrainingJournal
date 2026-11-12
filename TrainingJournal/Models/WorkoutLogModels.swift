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
    /// True when this exercise uses a rest the user chose rather than the Settings default.
    var isRestCustom: Bool = false
    var notes: String = ""
    /// Raw value of `ExerciseCatalog.Muscle`, copied from the plan when the session starts.
    var muscleRawValue: String?
    var log: WorkoutLog?
    /// The planned exercise this came from, used to write results back on finish.
    var template: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
    var sets: [LoggedSet] = []

    init(name: String, order: Int, restSeconds: Int, isRestCustom: Bool = false, notes: String = "",
         muscleRawValue: String? = nil, template: Exercise? = nil) {
        self.name = name
        self.order = order
        self.restSeconds = restSeconds
        self.isRestCustom = isRestCustom
        self.notes = notes
        self.muscleRawValue = muscleRawValue
        self.template = template
    }

    /// The rest to use now: the custom one, or the current Settings default.
    func effectiveRest(default defaultSeconds: Int) -> Int {
        isRestCustom ? restSeconds : defaultSeconds
    }

    /// The recorded muscle group (nil for "Other"), or one inferred from the name.
    var muscle: ExerciseCatalog.Muscle? {
        ExerciseCatalog.muscle(fromStored: muscleRawValue, name: name)
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
