import SwiftUI
import SwiftData

/// The live workout screen. Edits go straight into the in-progress `WorkoutLog`,
/// so closing the app mid-workout loses nothing.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimer.self) private var restTimer
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @AppStorage(SettingsKey.weightIncrement) private var weightIncrement = 5.0

    @Query(filter: #Predicate<WorkoutLog> { $0.endDate != nil }, sort: \WorkoutLog.startDate, order: .reverse)
    private var finishedLogs: [WorkoutLog]

    @Bindable var log: WorkoutLog
    /// Asks the presenter to close this screen and delete the session.
    let onDiscard: () -> Void

    @State private var isConfirmingFinish = false
    @State private var isConfirmingDiscard = false
    @State private var isAddingExercise = false
    /// Non-nil once the workout is finished; shows the summary.
    @State private var summaryRecords: [RecordHit]?
    @State private var setCompletedCount = 0

    var body: some View {
        NavigationStack {
            if let summaryRecords {
                WorkoutSummaryView(log: log, records: summaryRecords, weightUnit: weightUnit) {
                    dismiss()
                }
            } else {
                workoutList
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: setCompletedCount)
        .sensoryFeedback(.success, trigger: restTimer.goalReachedCount)
    }

    // MARK: - Workout list

    private var workoutList: some View {
        List {
            Section {
                SessionHeader(log: log, weightUnit: weightUnit)
            }

            ForEach(log.sortedExercises) { exercise in
                ExerciseSessionSection(
                    exercise: exercise,
                    weightUnit: weightUnit,
                    suggestion: suggestion(for: exercise),
                    onToggle: { set in toggle(set, in: exercise) },
                    onRestChanged: { seconds in restChanged(for: exercise, to: seconds) }
                )
            }

            Section {
                Button("Add Exercise", systemImage: "plus") {
                    isAddingExercise = true
                }
                TextField("Workout notes", text: $log.notes, axis: .vertical)
                    .lineLimit(1...4)
            }
        }
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        // Leave room so the last rows can scroll clear of the rest timer bar.
        .contentMargins(.bottom, restTimer.isRunning ? 24 : 0, for: .scrollContent)
        .animation(.default, value: restTimer.isRunning)
        .safeAreaInset(edge: .bottom) {
            RestTimerBar { exerciseName, seconds in
                log.exercises.first { $0.name == exerciseName }?.restSeconds = seconds
            }
        }
        .navigationTitle(log.workoutName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Minimize", systemImage: "chevron.down") {
                    dismiss()
                }
            }
            // Dialogs are attached to their buttons so the popovers anchor there.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Discard Workout", systemImage: "trash", role: .destructive) {
                    isConfirmingDiscard = true
                }
                .confirmationDialog("Discard this workout?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                    Button("Discard Workout", role: .destructive) {
                        discard()
                    }
                } message: {
                    Text("Nothing from this session will be saved.")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") {
                    isConfirmingFinish = true
                }
                .buttonStyle(.borderedProminent)
                .confirmationDialog("Finish workout?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
                    if log.completedSets.isEmpty {
                        Button("Discard Workout", role: .destructive) {
                            discard()
                        }
                    } else {
                        Button("Finish Workout") {
                            finish()
                        }
                    }
                    Button("Keep Training", role: .cancel) {}
                } message: {
                    Text(finishMessage)
                }
            }
        }
        .keyboardDoneButton()
        .sheet(isPresented: $isAddingExercise) {
            ExercisePickerView { name, rest in
                addExercise(named: name, restSeconds: rest)
            }
        }
    }

    private var finishMessage: LocalizedStringKey {
        let remaining = log.exercises.flatMap(\.sets).filter { !$0.isCompleted }.count
        if log.completedSets.isEmpty {
            return "You haven't checked off any sets yet."
        }
        if remaining > 0 {
            return "^[\(remaining) set](inflect: true) not checked off will be left out of the log."
        }
        return "Nice work. Your numbers will pre-fill next time."
    }

    // MARK: - Actions

    private func toggle(_ set: LoggedSet, in exercise: LoggedExercise) {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? .now : nil
        guard set.isCompleted else { return }
        setCompletedCount += 1

        // Don't start a rest after the very last set of the workout.
        let remaining = log.exercises.flatMap(\.sets).contains { !$0.isCompleted }
        guard remaining else {
            restTimer.stop()
            return
        }

        let sets = exercise.sortedSets
        let working = sets.filter { !$0.isWarmup }
        let label: String
        if set.isWarmup {
            label = "Warm-up done"
        } else if let index = working.firstIndex(where: { $0 === set }) {
            label = "Set \(index + 1) of \(working.count) done"
        } else {
            label = "Set done"
        }
        restTimer.start(
            workoutName: log.workoutName,
            exerciseName: exercise.name,
            setLabel: label,
            goalSeconds: exercise.restSeconds
        )
    }

    private func restChanged(for exercise: LoggedExercise, to seconds: Int) {
        // Apply to the running rest if it belongs to this exercise.
        if restTimer.state?.exerciseName == exercise.name {
            restTimer.setGoal(seconds: seconds)
        }
    }

    /// Weight to suggest when every working set last time hit its target reps.
    private func suggestion(for exercise: LoggedExercise) -> Double? {
        guard let last = WorkoutSession.history(named: exercise.name, in: finishedLogs, excluding: log).first,
              let suggested = TrainingMath.suggestedWeight(lastSets: last.exercise.performances, increment: weightIncrement)
        else { return nil }
        // Only show it while some remaining working sets are still below the suggestion.
        let below = exercise.sets.contains { !$0.isWarmup && !$0.isCompleted && $0.weight < suggested }
        return below ? suggested : nil
    }

    private func addExercise(named name: String, restSeconds: Int) {
        let nextOrder = (log.exercises.map(\.order).max() ?? -1) + 1
        let exercise = LoggedExercise(name: name, order: nextOrder, restSeconds: restSeconds)
        log.exercises.append(exercise)
        // Pre-fill from the most recent time this exercise was logged, if any.
        let previous = WorkoutSession.history(named: name, in: finishedLogs, excluding: log).first?.exercise.sortedSets ?? []
        if previous.isEmpty {
            exercise.sets = (0..<3).map { LoggedSet(order: $0, weight: 0, reps: 10, targetReps: 10) }
        } else {
            exercise.sets = previous.enumerated().map { index, set in
                LoggedSet(order: index, weight: set.weight, reps: set.reps, targetReps: set.targetReps,
                          isWarmup: set.isWarmup, previousWeight: set.weight, previousReps: set.reps)
            }
        }
    }

    private func finish() {
        let records = WorkoutSession.newRecords(in: log, comparedTo: finishedLogs)
        restTimer.stop()
        WorkoutSession.finish(log)
        withAnimation {
            summaryRecords = records
        }
    }

    private func discard() {
        restTimer.stop()
        onDiscard()
    }
}

// MARK: - Header

private struct SessionHeader: View {
    let log: WorkoutLog
    let weightUnit: String

    var body: some View {
        let allSets = log.exercises.flatMap(\.sets)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label("Elapsed", systemImage: "stopwatch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(log.startDate, style: .timer)
                    .font(.title3.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StatTile(title: "Sets", value: "\(allSets.filter(\.isCompleted).count)/\(allSets.count)", systemImage: "checkmark.circle")
            StatTile(title: "Volume", value: "\(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)", systemImage: "scalemass")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Exercise section

private struct ExerciseSessionSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: LoggedExercise
    let weightUnit: String
    let suggestion: Double?
    let onToggle: (LoggedSet) -> Void
    let onRestChanged: (Int) -> Void

    @State private var isEditingNotes = false

    var body: some View {
        let sets = exercise.sortedSets
        let labels = setLabels(isWarmup: sets.map(\.isWarmup))

        Section {
            if let suggestion {
                OverloadHint(weight: suggestion, weightUnit: weightUnit) {
                    applySuggestion(suggestion)
                }
            }

            if isEditingNotes || !exercise.notes.isEmpty {
                TextField("Notes (seat height, grip…)", text: $exercise.notes, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SessionSetRow(set: set, label: labels[index], weightUnit: weightUnit) {
                    onToggle(set)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(set)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button(set.isWarmup ? "Working Set" : "Warm-up", systemImage: "flame") {
                        set.isWarmup.toggle()
                    }
                    .tint(.yellow)
                }
            }

            Button("Add Set", systemImage: "plus.circle") {
                addSet()
            }
            .font(.subheadline)
        } header: {
            HStack {
                Text(exercise.name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Menu {
                    RestPicker(seconds: Binding(
                        get: { exercise.restSeconds },
                        set: { newValue in
                            exercise.restSeconds = newValue
                            onRestChanged(newValue)
                        }
                    ))
                    .pickerStyle(.inline)
                } label: {
                    Label(exercise.restSeconds.restFormatted, systemImage: "timer")
                        .font(.subheadline.monospacedDigit())
                }
                Button("Notes", systemImage: exercise.notes.isEmpty ? "note.text.badge.plus" : "note.text") {
                    isEditingNotes.toggle()
                }
                .labelStyle(.iconOnly)
            }
            .textCase(nil)
        }
    }

    private func addSet() {
        let last = exercise.sortedSets.last
        exercise.sets.append(LoggedSet(
            order: (last?.order ?? -1) + 1,
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 10,
            targetReps: last?.targetReps ?? 10
        ))
    }

    private func delete(_ set: LoggedSet) {
        exercise.sets.removeAll { $0 === set }
        modelContext.delete(set)
    }

    private func applySuggestion(_ weight: Double) {
        for set in exercise.sets where !set.isWarmup && !set.isCompleted && set.weight < weight {
            set.weight = weight
        }
    }
}

private struct OverloadHint: View {
    let weight: Double
    let weightUnit: String
    let onApply: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("You hit every rep last time")
                    .font(.subheadline.bold())
                Text("Try \(weight.shortFormatted) \(weightUnit) today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Apply", action: onApply)
                .buttonStyle(.bordered)
                .tint(.green)
                .controlSize(.small)
        }
    }
}

// MARK: - Set row

private struct SessionSetRow: View {
    @Bindable var set: LoggedSet
    let label: String
    let weightUnit: String
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SetBadge(label: label, isWarmup: set.isWarmup)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    CompactNumberField(placeholder: "0", value: $set.weight)
                        .frame(maxWidth: 90)
                    Text(weightUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("×")
                        .foregroundStyle(.secondary)
                    CompactIntField(placeholder: "0", value: $set.reps)
                        .frame(width: 56)
                }
                Group {
                    if let weight = set.previousWeight, let reps = set.previousReps {
                        Text("Last: \(weight.shortFormatted) × \(reps) · Goal \(set.targetReps) reps")
                    } else {
                        Text("Goal \(set.targetReps) reps")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onToggle) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 34))
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary.opacity(0.6))
                    .frame(width: 48, height: 48)
                    .contentShape(.rect)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set \(label) not done" : "Mark set \(label) done")
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.12) : Color(.secondarySystemGroupedBackground))
    }
}
