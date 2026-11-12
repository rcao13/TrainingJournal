import SwiftUI
import SwiftData

/// The live workout screen. Edits go straight into the in-progress `WorkoutLog`,
/// so closing the app mid-workout loses nothing.
///
/// The first unchecked set of the workout is the "current set": it gets the large panel,
/// and the Complete Set button at the bottom checks it off.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(RestTimer.self) private var restTimer
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @AppStorage(SettingsKey.weightIncrement) private var weightIncrement = 5.0
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRestSeconds = RestDefaults.fallbackSeconds

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

    /// The first unchecked set, in workout order.
    private var current: (exercise: LoggedExercise, set: LoggedSet)? {
        for exercise in log.sortedExercises {
            if let set = exercise.sortedSets.first(where: { !$0.isCompleted }) {
                return (exercise, set)
            }
        }
        return nil
    }

    // MARK: - Workout list

    private var workoutList: some View {
        List {
            Section {
                SessionHeader(log: log, current: current?.exercise, weightUnit: weightUnit)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            ForEach(log.sortedExercises) { exercise in
                ExerciseSessionSection(
                    exercise: exercise,
                    currentSetID: current?.set.persistentModelID,
                    weightUnit: weightUnit,
                    weightIncrement: weightIncrement,
                    defaultRestSeconds: defaultRestSeconds,
                    suggestion: suggestion(for: exercise),
                    onToggle: { set in toggle(set, in: exercise) },
                    onRestChanged: { seconds in restChanged(for: exercise, to: seconds) }
                )
            }

            Section {
                Button("Add Exercise", systemImage: "plus") {
                    isAddingExercise = true
                }
                .themedRow()
                TextField("Workout notes", text: $log.notes, axis: .vertical)
                    .lineLimit(1...4)
                    .themedRow()
            }
        }
        .themedBackground()
        // A firmer edge under the top buttons so scrolled content doesn't tangle with them.
        .scrollEdgeEffectStyle(.hard, for: .top)
        .listSectionSpacing(14)
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: restTimer.isRunning)
        // A safe-area bar (not a plain inset) so the list blurs as it scrolls under
        // the rest card and button instead of showing through between them.
        .safeAreaBar(edge: .bottom) {
            bottomBar
        }
        .navigationTitle("")
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
            ExercisePickerView { name, muscle in
                addExercise(named: name, muscle: muscle)
            }
        }
    }

    /// Rest card plus the main action, pinned above the home indicator.
    private var bottomBar: some View {
        VStack(spacing: 10) {
            RestTimerBar { exerciseName, seconds in
                // Adjusting a running rest counts as choosing a custom rest for that exercise.
                if let exercise = log.exercises.first(where: { $0.name == exerciseName }) {
                    exercise.restSeconds = seconds
                    exercise.isRestCustom = true
                }
            }
            if let current {
                Button("Complete Set") {
                    toggle(current.set, in: current.exercise)
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Finish Workout") {
                    isConfirmingFinish = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 4)
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
        withAnimation(.snappy) {
            set.isCompleted.toggle()
            set.completedAt = set.isCompleted ? .now : nil
        }
        guard set.isCompleted else { return }
        setCompletedCount += 1

        // Don't start a rest after the very last set of the workout.
        let remaining = log.exercises.flatMap(\.sets).contains { !$0.isCompleted }
        guard remaining else {
            restTimer.stop()
            return
        }

        let working = exercise.sortedSets.filter { !$0.isWarmup }
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
            goalSeconds: exercise.effectiveRest(default: defaultRestSeconds)
        )
    }

    private func restChanged(for exercise: LoggedExercise, to seconds: Int) {
        // `seconds` is already the effective rest (custom or default).
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

    private func addExercise(named name: String, muscle: ExerciseCatalog.Muscle?) {
        let nextOrder = (log.exercises.map(\.order).max() ?? -1) + 1
        let exercise = LoggedExercise(
            name: name, order: nextOrder, restSeconds: defaultRestSeconds,
            muscleRawValue: ExerciseCatalog.storedValue(for: muscle)
        )
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
    let current: LoggedExercise?
    let weightUnit: String

    private var progressText: String {
        let exercises = log.sortedExercises
        guard let current, let index = exercises.firstIndex(where: { $0 === current }) else {
            return exercises.isEmpty ? "No exercises yet" : "All sets done"
        }
        return "Exercise \(index + 1) of \(exercises.count)"
    }

    private var bestEstimate: String {
        guard let current else { return "—" }
        let best = PersonalRecords(current.performances).bestEstimated1RM
        return best > 0 ? "\(best.shortFormatted) \(weightUnit)" : "—"
    }

    var body: some View {
        let allSets = log.exercises.flatMap(\.sets)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.workoutName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(progressText)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(log.startDate, style: .timer)
                        .font(.numeral(20))
                        .foregroundStyle(Theme.ink)
                    Text("elapsed")
                        .font(.caption)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.top, 8)
            }
            HStack(spacing: 10) {
                StatTile(title: "Volume", value: "\(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)")
                    .appCard(padding: 12)
                StatTile(title: "Sets", value: "\(allSets.filter(\.isCompleted).count) of \(allSets.count)")
                    .appCard(padding: 12)
                StatTile(title: "Est. 1RM", value: bestEstimate)
                    .appCard(padding: 12)
            }
        }
    }
}

// MARK: - Exercise section

private struct ExerciseSessionSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: LoggedExercise
    let currentSetID: PersistentIdentifier?
    let weightUnit: String
    let weightIncrement: Double
    let defaultRestSeconds: Int
    let suggestion: Double?
    let onToggle: (LoggedSet) -> Void
    let onRestChanged: (Int) -> Void

    @State private var isEditingNotes = false

    var body: some View {
        let sets = exercise.sortedSets
        let labels = setLabels(isWarmup: sets.map(\.isWarmup))

        Section {
            header
                .themedRow()

            if let suggestion {
                OverloadHint(weight: suggestion, weightUnit: weightUnit) {
                    applySuggestion(suggestion)
                }
                .themedRow()
            }

            if isEditingNotes || !exercise.notes.isEmpty {
                TextField("Notes (seat height, grip…)", text: $exercise.notes, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...4)
                    .themedRow()
            }

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                setRow(set, label: labels[index])
                    .themedRow()
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(set)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button(set.isWarmup ? "Working Set" : "Warm-up", systemImage: "flame") {
                            set.isWarmup.toggle()
                        }
                        .tint(.accentColor)
                    }
            }

            Button("Add Set", systemImage: "plus.circle") {
                addSet()
            }
            .font(.subheadline)
            .themedRow()
        }
    }

    @ViewBuilder
    private func setRow(_ set: LoggedSet, label: String) -> some View {
        if set.persistentModelID == currentSetID {
            CurrentSetPanel(set: set, label: label, weightUnit: weightUnit, weightIncrement: weightIncrement)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        } else if set.isCompleted {
            DoneSetRow(set: set, label: label, weightUnit: weightUnit) {
                onToggle(set)
            }
        } else {
            UpcomingSetRow(set: set, label: label, weightUnit: weightUnit) {
                onToggle(set)
            }
        }
    }

    private var restText: String {
        exercise.effectiveRest(default: defaultRestSeconds).restFormatted
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(exercise.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Menu {
                ExerciseRestPicker(
                    override: Binding(
                        get: { exercise.isRestCustom ? exercise.restSeconds : nil },
                        set: { newValue in
                            exercise.isRestCustom = newValue != nil
                            exercise.restSeconds = newValue ?? defaultRestSeconds
                            onRestChanged(exercise.effectiveRest(default: defaultRestSeconds))
                        }
                    ),
                    defaultSeconds: defaultRestSeconds
                )
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(restText)
                }
                .font(.footnote.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.track, in: .capsule)
            }
            .accessibilityLabel("Rest \(restText)")
            Button("Notes", systemImage: exercise.notes.isEmpty ? "note.text.badge.plus" : "note.text") {
                isEditingNotes.toggle()
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(Theme.secondary)
            .buttonStyle(.borderless)
            .padding(.leading, 4)
        }
        .padding(.vertical, 2)
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
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("You hit every rep last time")
                    .font(.subheadline.weight(.semibold))
                Text("Try \(weight.shortFormatted) \(weightUnit) today.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button("Apply", action: onApply)
                .buttonStyle(PillButtonStyle())
        }
    }
}

// MARK: - Set rows

/// The large panel for the set you're about to do.
private struct CurrentSetPanel: View {
    @Bindable var set: LoggedSet
    let label: String
    let weightUnit: String
    let weightIncrement: Double

    @ScaledMetric(relativeTo: .largeTitle) private var weightSize: CGFloat = 60
    @ScaledMetric(relativeTo: .title) private var repsSize: CGFloat = 42

    private var caption: String {
        let name = set.isWarmup ? "WARM-UP" : "SET \(label)"
        if let weight = set.previousWeight, let reps = set.previousReps {
            return "\(name)  ·  LAST TIME \(weight.shortFormatted) × \(reps)"
        }
        return "\(name)  ·  GOAL \(set.targetReps) REPS"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(caption)
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", value: $set.weight, format: .number)
                    .font(.numeral(min(weightSize, 84)))
                    .foregroundStyle(Theme.ink)
                    .decimalKeyboard()
                    .fixedSize()
                    .accessibilityLabel("Weight")
                Text(weightUnit)
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 8)
                TextField("0", value: $set.reps, format: .number)
                    .font(.numeral(min(repsSize, 64)))
                    .foregroundStyle(Theme.ink)
                    .numberKeyboard()
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .accessibilityLabel("Reps")
                Text("reps")
                    .font(.body)
                    .foregroundStyle(Theme.secondary)
            }

            HStack(spacing: 8) {
                Button("− \(weightIncrement.shortFormatted)") {
                    set.weight = max(0, set.weight - weightIncrement)
                }
                .accessibilityLabel("Decrease weight")
                Button("+ \(weightIncrement.shortFormatted)") {
                    set.weight += weightIncrement
                }
                .accessibilityLabel("Increase weight")
                Spacer()
                Button("− 1") {
                    set.reps = max(0, set.reps - 1)
                }
                .accessibilityLabel("One fewer rep")
                Button("+ 1") {
                    set.reps += 1
                }
                .accessibilityLabel("One more rep")
            }
            .buttonStyle(PillButtonStyle())
            .sensoryFeedback(.selection, trigger: set.weight)
            .sensoryFeedback(.selection, trigger: set.reps)
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 18))
    }
}

private struct DoneSetRow: View {
    let set: LoggedSet
    let label: String
    let weightUnit: String
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text(set.isWarmup ? "Warm-up" : "Set \(label)")
                .foregroundStyle(Theme.secondary)
                .frame(width: 72, alignment: .leading)
            Text("\(set.weight.shortFormatted) \(weightUnit) × \(set.reps)")
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Spacer()
            Button(action: onToggle) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.ready)
                    .frame(width: 44, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(set.isWarmup ? "warm-up" : "set \(label)") not done")
        }
    }
}

/// A set after the current one: editable, and can be checked off out of order.
private struct UpcomingSetRow: View {
    @Bindable var set: LoggedSet
    let label: String
    let weightUnit: String
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(set.isWarmup ? "Warm-up" : "Set \(label)")
                .foregroundStyle(Theme.secondary)
                .frame(width: 72, alignment: .leading)
            CompactNumberField(placeholder: "0", value: $set.weight)
                .frame(width: 78)
            Text(weightUnit)
                .font(.caption)
                .foregroundStyle(Theme.secondary)
            Text("×")
                .foregroundStyle(Theme.secondary)
            CompactIntField(placeholder: "0", value: $set.reps)
                .frame(width: 52)
            Spacer(minLength: 0)
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Theme.secondary.opacity(0.7))
                    .frame(width: 44, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(set.isWarmup ? "warm-up" : "set \(label)") done")
        }
    }
}
