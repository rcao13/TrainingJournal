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
        let bench = Exercise(name: "Bench Press", order: 0, restOverride: 120)
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
        #expect(bench.isRestCustom)
        #expect(bench.sortedSets.map(\.weight) == [135, 135, 135])
        // Never performed yet, so there's no "Last: …" to show.
        #expect(bench.sortedSets.allSatisfy { $0.previousWeight == nil })

        bench.sets.forEach { $0.isCompleted = true }
        WorkoutSession.finish(log)

        let next = WorkoutSession.start(workout, in: context)
        let nextBench = try #require(next.sortedExercises.first)
        #expect(nextBench.sortedSets.allSatisfy { $0.previousWeight == 135 && $0.previousReps == 8 })
    }

    @Test func emptyPlannedWeightsInheritThePreviousSet() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let bench = try #require(workout.sortedExercises.first)
        bench.sortedSets[1].weight = 0
        bench.sortedSets[2].weight = 0

        let log = WorkoutSession.start(workout, in: context)
        #expect(log.sortedExercises.first?.sortedSets.map(\.weight) == [135, 135, 135])
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
        bench.isRestCustom = true
        for set in bench.sets { set.isCompleted = true }

        WorkoutSession.finish(log)

        let planned = try #require(workout.sortedExercises.first)
        #expect(planned.sortedSets.count == 4)
        #expect(planned.sortedSets.map(\.weight) == [135, 135, 145, 150])
        #expect(planned.sortedSets.map(\.reps) == [8, 8, 6, 5])
        #expect(planned.sortedSets.first?.isWarmup == true)
        #expect(planned.restOverride == 150)
        #expect(workout.lastCompleted != nil)
        #expect(log.isFinished)
    }

    @Test func restsFollowTheDefaultUnlessCustomised() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let squat = Exercise(name: "Back Squat", order: 1)
        squat.sets = [ExerciseSet(order: 0, weight: 225, reps: 5, targetReps: 5)]
        workout.exercises.append(squat)

        let log = WorkoutSession.start(workout, in: context, defaultRest: 75)
        let loggedSquat = try #require(log.sortedExercises.last)
        let loggedBench = try #require(log.sortedExercises.first)
        #expect(loggedSquat.effectiveRest(default: 75) == 75)
        #expect(!loggedSquat.isRestCustom)
        // A later change to the default applies to exercises without a custom rest...
        #expect(loggedSquat.effectiveRest(default: 120) == 120)
        // ...but not to ones the user customised.
        #expect(loggedBench.effectiveRest(default: 120) == 120)
        #expect(loggedBench.effectiveRest(default: 30) == 120)

        log.exercises.flatMap(\.sets).forEach { $0.isCompleted = true }
        WorkoutSession.finish(log)
        // Finishing doesn't turn a default rest into a custom one.
        #expect(squat.restOverride == nil)
        #expect(workout.sortedExercises.first?.restOverride == 120)
    }

    @Test func resettingToDefaultClearsTheCustomRest() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let log = WorkoutSession.start(workout, in: context, defaultRest: 90)
        let bench = try #require(log.sortedExercises.first)
        bench.isRestCustom = false
        bench.restSeconds = 90
        bench.sets.forEach { $0.isCompleted = true }
        WorkoutSession.finish(log)
        #expect(workout.sortedExercises.first?.restOverride == nil)
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

struct RecoveryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func mapsCatalogAndCustomNames() {
        #expect(Recovery.muscle(for: "Bench Press") == .chest)
        #expect(Recovery.muscle(for: "romanian deadlift") == .legs)
        #expect(Recovery.muscle(for: "Close-Grip Bench Press") == .arms)
        // Keyword fallbacks for names that aren't in the catalog.
        #expect(Recovery.muscle(for: "Seated Leg Curl") == .legs)
        #expect(Recovery.muscle(for: "Cable Lateral Raise") == .shoulders)
        #expect(Recovery.muscle(for: "Cable Y Raise") == .shoulders)
        #expect(Recovery.muscle(for: "Rope Tricep Extension") == .arms)
        #expect(Recovery.muscle(for: "T-Bar Row") == .back)
        #expect(Recovery.muscle(for: "Mystery Machine") == nil)
    }

    @Test func progressUsesTheMostRecentSession() {
        let sessions = [
            Recovery.Session(date: now.addingTimeInterval(-5 * 86_400), exerciseNames: ["Bench Press"]),
            Recovery.Session(date: now.addingTimeInterval(-36 * 3600), exerciseNames: ["Bench Press", "Back Squat"]),
        ]
        let statuses = Recovery.statuses(for: sessions, now: now)
        let chest = try? #require(statuses.first { $0.muscle == .chest })
        #expect(chest?.progress == 0.5) // 36 of 72 hours
        #expect(chest?.isReady == false)
        #expect(chest.map(Recovery.remainingText(for:)) == "~36 h")
        // Least recovered first.
        #expect(statuses.map(\.progress) == statuses.map(\.progress).sorted())
    }

    @Test func readyAfterTheWindowAndOldSessionsDrop() {
        let sessions = [
            Recovery.Session(date: now.addingTimeInterval(-3 * 86_400), exerciseNames: ["Plank"]),
            Recovery.Session(date: now.addingTimeInterval(-20 * 86_400), exerciseNames: ["Deadlift"]),
        ]
        let statuses = Recovery.statuses(for: sessions, now: now)
        #expect(statuses.map(\.muscle) == [.core])
        #expect(statuses.first?.isReady == true)
        #expect(Recovery.summary(for: statuses) == "All recovered")
    }

    @Test func chosenMuscleGroupsOverrideNameGuessing() {
        // Nothing stored (older exercises) falls back to the name.
        #expect(ExerciseCatalog.muscle(fromStored: nil, name: "Bench Press") == .chest)
        // An explicit choice wins, even if the name suggests something else.
        #expect(ExerciseCatalog.muscle(fromStored: "Legs", name: "Bench Press") == .legs)
        // An explicit "Other" stays unassigned instead of being guessed.
        #expect(ExerciseCatalog.muscle(fromStored: ExerciseCatalog.storedValue(for: nil), name: "Bench Press") == nil)

        let sessions = [Recovery.Session(date: now.addingTimeInterval(-3600), muscles: [.legs])]
        #expect(Recovery.statuses(for: sessions, now: now).map(\.muscle) == [.legs])
    }

    @Test func catalogNamesAreUnique() {
        let names = ExerciseCatalog.entries.map { $0.name.lowercased() }
        #expect(Set(names).count == names.count)
        for muscle in ExerciseCatalog.Muscle.allCases {
            #expect(ExerciseCatalog.entries.filter { $0.muscle == muscle }.count >= 15)
        }
    }

    @Test func summaryListsReadyMuscles() {
        let statuses = [
            Recovery.Status(muscle: .chest, lastTrained: now, progress: 0.3, remaining: 3600),
            Recovery.Status(muscle: .back, lastTrained: now, progress: 1, remaining: 0),
            Recovery.Status(muscle: .legs, lastTrained: now, progress: 1, remaining: 0),
        ]
        #expect(Recovery.summary(for: statuses) == "Back and legs ready")
        #expect(Recovery.summary(for: []) == "")
    }
}

struct DayTimelineTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ id: String, _ kind: TimelineItem.Kind, minutes: Double?, duration: Double? = nil) -> TimelineItem {
        let start = minutes.map { base.addingTimeInterval($0 * 60) }
        let end = start.flatMap { start in duration.map { start.addingTimeInterval($0 * 60) } }
        return TimelineItem(id: id, kind: kind, start: start, end: end, title: id, detail: "")
    }

    @Test func sortsByTimeAndPutsPlannedLast() {
        let entries = DayTimeline.entries(for: [
            item("planned", .planned, minutes: nil),
            item("lunch", .meal, minutes: 300),
            item("breakfast", .meal, minutes: 0),
        ], minimumGap: .infinity)
        #expect(entries.map(\.id) == ["breakfast", "lunch", "planned"])
    }

    @Test func gapsMeasureFromTheEndOfAWorkout() {
        let entries = DayTimeline.entries(for: [
            item("breakfast", .meal, minutes: 0),
            item("push", .workout, minutes: 280, duration: 52),
            item("lunch", .meal, minutes: 382),
        ])
        let gaps: [String] = entries.compactMap { entry in
            if case .gap(_, let text) = entry { return text }
            return nil
        }
        #expect(gaps == ["4h 40m before training", "50 min after training"])
    }

    @Test func shortGapsAreHidden() {
        let entries = DayTimeline.entries(for: [
            item("snack", .meal, minutes: 0),
            item("weigh", .weighIn, minutes: 10),
        ])
        #expect(entries.count == 2)
    }

    @Test func mealsAreGroupedWithTotals() {
        let items = DayTimeline.mealItems(from: [
            .init(name: "Banana", meal: "Breakfast", date: base.addingTimeInterval(600), calories: 300, protein: 20),
            .init(name: "Oats", meal: "Breakfast", date: base, calories: 220, protein: 12),
            .init(name: "Burrito", meal: "Lunch", date: base.addingTimeInterval(18_000), calories: 680, protein: 48),
        ])
        let breakfast = items.first { $0.title == "Breakfast" }
        #expect(items.count == 2)
        #expect(breakfast?.start == base)
        #expect(breakfast?.detail == "Oats, Banana · 520 kcal · 32 g protein")
        #expect(DayTimeline.foodList(["A", "B", "C", "D"]) == "A, B +2")
    }

    @Test func durationText() {
        #expect(DayTimeline.durationText(50 * 60) == "50 min")
        #expect(DayTimeline.durationText(2 * 3600) == "2h")
        #expect(DayTimeline.durationText(280 * 60) == "4h 40m")
    }
}
