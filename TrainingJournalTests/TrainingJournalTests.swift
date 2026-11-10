import Foundation
import SwiftData
import Testing
@testable import TrainingJournal

struct TrainingMathTests {
    @Test func estimated1RMUsesEpley() {
        #expect(TrainingMath.estimated1RM(weight: 100, reps: 10) == 100 * (1 + 10.0 / 30))
        #expect(TrainingMath.estimated1RM(weight: 225, reps: 1) == 225)
        #expect(TrainingMath.estimated1RM(weight: 135, reps: 0) == 0)
    }

    @Test func suggestsMoreWeightWhenAllTargetsHit() {
        let sets = [
            SetPerformance(weight: 135, reps: 8, targetReps: 8),
            SetPerformance(weight: 135, reps: 9, targetReps: 8),
        ]
        #expect(TrainingMath.suggestedWeight(lastSets: sets, increment: 5) == 140)
    }

    @Test func noSuggestionWhenOneRepShort() {
        let sets = [
            SetPerformance(weight: 135, reps: 8, targetReps: 8),
            SetPerformance(weight: 135, reps: 7, targetReps: 8),
        ]
        #expect(TrainingMath.suggestedWeight(lastSets: sets, increment: 5) == nil)
    }

    @Test func warmupsAreIgnoredForSuggestions() {
        let sets = [
            SetPerformance(weight: 95, reps: 3, targetReps: 10, isWarmup: true),
            SetPerformance(weight: 135, reps: 10, targetReps: 10),
        ]
        #expect(TrainingMath.suggestedWeight(lastSets: sets, increment: 2.5) == 137.5)
        #expect(TrainingMath.suggestedWeight(lastSets: [sets[0]], increment: 5) == nil)
    }

    @Test func personalRecordsIgnoreWarmups() {
        let records = PersonalRecords([
            SetPerformance(weight: 300, reps: 1, targetReps: 1, isWarmup: true),
            SetPerformance(weight: 200, reps: 5, targetReps: 5),
        ])
        #expect(records.heaviestWeight == 200)
        #expect(records.bestEstimated1RM == TrainingMath.estimated1RM(weight: 200, reps: 5))
    }

    @Test func recordHitsCompareAgainstHistory() {
        let history = [SetPerformance(weight: 200, reps: 5, targetReps: 5)]
        let heavier = [SetPerformance(weight: 205, reps: 3, targetReps: 5)]
        let hits = RecordHit.hits(exerciseName: "Squat", current: heavier, history: history)
        #expect(hits.map(\.kind) == [.heaviestWeight])

        let moreReps = [SetPerformance(weight: 200, reps: 8, targetReps: 5)]
        #expect(RecordHit.hits(exerciseName: "Squat", current: moreReps, history: history).map(\.kind) == [.estimated1RM])

        // The first session ever isn't a "record".
        #expect(RecordHit.hits(exerciseName: "Squat", current: heavier, history: []).isEmpty)
    }

    @Test func setLabelsNumberWorkingSetsOnly() {
        #expect(setLabels(isWarmup: [true, false, false, true, false]) == ["W", "1", "2", "W", "3"])
    }
}

@MainActor
struct WorkoutSessionTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutPlan.self, WorkoutLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeWorkout(in context: ModelContext) -> Workout {
        let plan = WorkoutPlan(name: "PPL")
        context.insert(plan)
        let workout = Workout(name: "Push", order: 0)
        plan.workouts.append(workout)
        let bench = Exercise(name: "Bench Press", order: 0, restSeconds: 120)
        workout.exercises.append(bench)
        bench.sets = (0..<3).map { ExerciseSet(order: $0, weight: 135, reps: 8, targetReps: 8) }
        return workout
    }

    @Test func startPrefillsFromPlan() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let log = WorkoutSession.start(workout, in: context)

        #expect(log.endDate == nil)
        let bench = try #require(log.sortedExercises.first)
        #expect(bench.restSeconds == 120)
        #expect(bench.sortedSets.map(\.weight) == [135, 135, 135])
        // Never performed yet, so there's no "Last: …" to show.
        #expect(bench.sortedSets.allSatisfy { $0.previousWeight == nil })

        bench.sets.forEach { $0.isCompleted = true }
        WorkoutSession.finish(log)

        let next = WorkoutSession.start(workout, in: context)
        let nextBench = try #require(next.sortedExercises.first)
        #expect(nextBench.sortedSets.allSatisfy { $0.previousWeight == 135 && $0.previousReps == 8 })
    }

    @Test func finishCopiesAddedAndRemovedSetsBackToPlan() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let log = WorkoutSession.start(workout, in: context)
        let bench = try #require(log.sortedExercises.first)

        // Drop the last planned set, add two new heavier ones, mark one as warm-up.
        let removed = try #require(bench.sortedSets.last)
        bench.sets.removeAll { $0 === removed }
        context.delete(removed)
        bench.sets.append(LoggedSet(order: 5, weight: 145, reps: 6, targetReps: 8))
        bench.sets.append(LoggedSet(order: 6, weight: 150, reps: 5, targetReps: 8))
        bench.sortedSets.first?.isWarmup = true
        bench.restSeconds = 150
        for set in bench.sets { set.isCompleted = true }

        WorkoutSession.finish(log)

        let planned = try #require(workout.sortedExercises.first)
        #expect(planned.sortedSets.count == 4)
        #expect(planned.sortedSets.map(\.weight) == [135, 135, 145, 150])
        #expect(planned.sortedSets.map(\.reps) == [8, 8, 6, 5])
        #expect(planned.sortedSets.first?.isWarmup == true)
        #expect(planned.restSeconds == 150)
        #expect(workout.lastCompleted != nil)
        #expect(log.isFinished)
    }

    @Test func finishDropsUncheckedSetsFromLog() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let log = WorkoutSession.start(workout, in: context)
        let bench = try #require(log.sortedExercises.first)
        bench.sortedSets.first?.isCompleted = true

        WorkoutSession.finish(log)

        #expect(log.completedSets.count == 1)
        #expect(log.sortedExercises.first?.sets.count == 1)
        // The plan keeps all three sets even though only one was checked off.
        #expect(workout.sortedExercises.first?.sets.count == 3)
    }

    @Test func newRecordsComparesWithEarlierLogs() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)

        let first = WorkoutSession.start(workout, in: context)
        first.startDate = .now.addingTimeInterval(-86_400)
        first.exercises.flatMap(\.sets).forEach { $0.isCompleted = true }
        WorkoutSession.finish(first)

        let second = WorkoutSession.start(workout, in: context)
        let set = try #require(second.sortedExercises.first?.sortedSets.first)
        set.weight = 155
        set.isCompleted = true

        let records = WorkoutSession.newRecords(in: second, comparedTo: [first, second])
        #expect(records.contains { $0.kind == .heaviestWeight && $0.value == 155 })
    }
}
