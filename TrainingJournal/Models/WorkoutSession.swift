import Foundation
import SwiftData

/// Starting, finishing, and cancelling a live workout.
enum WorkoutSession {
    /// Creates an in-progress log pre-filled with the plan's last-used values.
    @discardableResult
    static func start(_ workout: Workout, in context: ModelContext) -> WorkoutLog {
        let log = WorkoutLog(workoutName: workout.name, workout: workout)
        context.insert(log)
        for exercise in workout.sortedExercises {
            let logged = LoggedExercise(
                name: exercise.name,
                order: exercise.order,
                restSeconds: exercise.restSeconds,
                notes: exercise.notes,
                template: exercise
            )
            log.exercises.append(logged)
            // Only show "Last: …" once the exercise has actually been performed.
            let hasBeenLogged = exercise.loggedExercises.contains { $0.log?.isFinished == true }
            // A planned set with no weight inherits the set before it, so a plan filled in
            // only for set 1 still starts every working set at that weight.
            var carriedWeight = 0.0
            for set in exercise.sortedSets {
                let weight = set.weight > 0 || set.isWarmup ? set.weight : carriedWeight
                if !set.isWarmup && weight > 0 { carriedWeight = weight }
                logged.sets.append(LoggedSet(
                    order: set.order,
                    weight: weight,
                    reps: set.reps,
                    targetReps: set.targetReps,
                    isWarmup: set.isWarmup,
                    previousWeight: hasBeenLogged ? set.weight : nil,
                    previousReps: hasBeenLogged ? set.reps : nil
                ))
            }
        }
        return log
    }

    /// Ends the session: copies the results into the plan so they pre-fill next time,
    /// then drops sets that were never completed so the log reflects what was actually done.
    static func finish(_ log: WorkoutLog, at date: Date = .now) {
        log.endDate = date
        log.workout?.lastCompleted = date

        for logged in log.exercises {
            if let template = logged.template {
                writeBack(logged, to: template)
            }
        }

        let context = log.modelContext
        for logged in log.exercises {
            let unfinished = logged.sets.filter { !$0.isCompleted }
            logged.sets.removeAll { !$0.isCompleted }
            unfinished.forEach { context?.delete($0) }
        }
        let empty = log.exercises.filter(\.sets.isEmpty)
        log.exercises.removeAll(where: \.sets.isEmpty)
        empty.forEach { context?.delete($0) }
    }

    /// Discards an in-progress session without touching the plan.
    static func cancel(_ log: WorkoutLog) {
        log.modelContext?.delete(log)
    }

    /// Makes the planned exercise match the session: same number of sets, and the
    /// weights, reps, warm-up flags, rest, and notes that were just used.
    static func writeBack(_ logged: LoggedExercise, to template: Exercise) {
        template.restSeconds = logged.restSeconds
        template.notes = logged.notes

        let loggedSets = logged.sortedSets
        var plannedSets = template.sortedSets

        // Remove planned sets that were deleted during the workout.
        while plannedSets.count > loggedSets.count, let extra = plannedSets.popLast() {
            template.sets.removeAll { $0 === extra }
            template.modelContext?.delete(extra)
        }

        for (index, loggedSet) in loggedSets.enumerated() {
            let planned: ExerciseSet
            if index < plannedSets.count {
                planned = plannedSets[index]
            } else {
                planned = ExerciseSet(order: index, targetReps: loggedSet.targetReps)
                template.sets.append(planned)
            }
            planned.order = index
            planned.weight = loggedSet.weight
            planned.reps = loggedSet.reps
            planned.targetReps = loggedSet.targetReps
            planned.isWarmup = loggedSet.isWarmup
        }
    }

    /// Completed sets for an exercise across finished logs, newest log first.
    static func history(named name: String, in logs: [WorkoutLog], excluding current: WorkoutLog? = nil) -> [(log: WorkoutLog, exercise: LoggedExercise)] {
        logs
            .filter { $0.isFinished && $0 !== current }
            .sorted { $0.startDate > $1.startDate }
            .compactMap { log in
                log.exercises.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
                    .map { (log, $0) }
            }
    }

    /// Personal records set in `log`, compared with every earlier finished log.
    static func newRecords(in log: WorkoutLog, comparedTo logs: [WorkoutLog]) -> [RecordHit] {
        log.sortedExercises.flatMap { exercise in
            let earlier = history(named: exercise.name, in: logs, excluding: log)
                .filter { $0.log.startDate < log.startDate }
                .flatMap { $0.exercise.performances }
            return RecordHit.hits(exerciseName: exercise.name, current: exercise.performances, history: earlier)
        }
    }
}
