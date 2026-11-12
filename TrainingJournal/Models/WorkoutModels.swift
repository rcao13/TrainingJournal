import Foundation
import SwiftData

/// A training plan (e.g. "Push / Pull / Legs") that groups several workouts.
@Model
final class WorkoutPlan {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Workout.plan)
    var workouts: [Workout] = []

    init(name: String) {
        self.name = name
        self.createdAt = .now
    }

    /// SwiftData relationships are unordered, so workouts carry an explicit `order`.
    var sortedWorkouts: [Workout] {
        workouts.sorted { $0.order < $1.order }
    }
}

/// A workout (e.g. "Push Day") scheduled on one or more days of the week.
@Model
final class Workout {
    var name: String
    var order: Int
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    var weekdays: [Int]
    var lastCompleted: Date?
    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []

    /// Sessions started from this workout. Logs outlive the workout if it's deleted.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutLog.workout)
    var logs: [WorkoutLog] = []

    init(name: String, order: Int, weekdays: [Int] = []) {
        self.name = name
        self.order = order
        self.weekdays = weekdays
    }

    var sortedExercises: [Exercise] {
        exercises.sorted { $0.order < $1.order }
    }
}

/// An exercise inside a workout (e.g. "Bench Press").
@Model
final class Exercise {
    var name: String
    var order: Int
    /// Legacy per-exercise rest from before rests followed the Settings default. No longer read.
    var restSeconds: Int = 90
    /// A rest the user chose for this exercise, in seconds.
    /// Nil means it follows the default rest in Settings.
    var restOverride: Int?
    var notes: String = ""
    /// Raw value of `ExerciseCatalog.Muscle`, chosen in the picker or editor.
    /// Nil for exercises created before muscle groups existed; those fall back to name matching.
    var muscleRawValue: String?
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet] = []

    @Relationship(deleteRule: .nullify, inverse: \LoggedExercise.template)
    var loggedExercises: [LoggedExercise] = []

    init(name: String, order: Int, restOverride: Int? = nil) {
        self.name = name
        self.order = order
        self.restOverride = restOverride
    }

    /// The rest to use: the custom one if set, otherwise the default from Settings.
    func effectiveRest(default defaultSeconds: Int) -> Int {
        restOverride ?? defaultSeconds
    }

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.order < $1.order }
    }

    /// The chosen muscle group. Setting nil records an explicit "Other";
    /// exercises that never had one chosen are inferred from their name.
    var muscle: ExerciseCatalog.Muscle? {
        get { ExerciseCatalog.muscle(fromStored: muscleRawValue, name: name) }
        set { muscleRawValue = ExerciseCatalog.storedValue(for: newValue) }
    }
}

/// A planned set. `weight` and `reps` hold the most recently performed values,
/// so they pre-fill the next session; `targetReps` is the goal used for overload hints.
@Model
final class ExerciseSet {
    var order: Int
    var weight: Double
    var reps: Int
    var targetReps: Int = 10
    var isWarmup: Bool = false
    var exercise: Exercise?

    init(order: Int, weight: Double = 0, reps: Int = 10, targetReps: Int = 10, isWarmup: Bool = false) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.targetReps = targetReps
        self.isWarmup = isWarmup
    }
}

/// Helpers for working with `Calendar` weekday numbers.
nonisolated enum Weekday {
    static var today: Int {
        Calendar.current.component(.weekday, from: .now)
    }

    /// Weekday numbers ordered by the user's locale (e.g. Monday first).
    static var ordered: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func shortName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    static func veryShortName(_ weekday: Int) -> String {
        Calendar.current.veryShortWeekdaySymbols[weekday - 1]
    }

    /// e.g. "Mon, Wed, Fri" in locale order.
    static func summary(for weekdays: [Int]) -> String {
        let names = ordered.filter(weekdays.contains).map(shortName)
        return names.isEmpty ? "Not scheduled" : names.joined(separator: ", ")
    }
}

extension Int {
    /// Formats a number of seconds as "1:30".
    var restFormatted: String {
        Duration.seconds(self).formatted(.time(pattern: .minuteSecond))
    }
}
