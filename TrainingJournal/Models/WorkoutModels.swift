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
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.order < $1.order }
    }
}

/// A single set. `weight` and `reps` always hold the most recently used values,
/// so they pre-fill the next time the workout is started.
@Model
final class ExerciseSet {
    var order: Int
    var weight: Double
    var reps: Int
    var exercise: Exercise?

    init(order: Int, weight: Double = 0, reps: Int = 10) {
        self.order = order
        self.weight = weight
        self.reps = reps
    }
}

/// Helpers for working with `Calendar` weekday numbers.
enum Weekday {
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
