import SwiftUI
import SwiftData

/// Edits a workout's name, scheduled weekdays, and exercises, and starts a session.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRestSeconds = RestDefaults.fallbackSeconds
    @Bindable var workout: Workout

    @Query(filter: #Predicate<WorkoutLog> { $0.endDate == nil })
    private var activeLogs: [WorkoutLog]

    @State private var isAddingExercise = false
    /// The name can only be changed while editing, so it isn't renamed by a stray tap.
    @State private var editMode: EditMode = .inactive
    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List {
            Section {
                Button {
                    start()
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(workout.exercises.isEmpty || !activeLogs.isEmpty)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                // Status sits under the button as plain text rather than in a card it would crowd.
                if !activeLogs.isEmpty {
                    Label("Finish your current workout before starting another.", systemImage: "info.circle")
                } else if let lastCompleted = workout.lastCompleted {
                    Label {
                        Text("Last done \(lastCompleted, format: .relative(presentation: .named))")
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }

            if isEditing {
                Section("Name") {
                    TextField("Workout name", text: $workout.name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                }
            }

            Section("Days") {
                WeekdayPicker(selection: $workout.weekdays)
            }

            Section("Exercises") {
                if workout.exercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises", systemImage: "dumbbell")
                    } description: {
                        Text("Add exercises to build this workout.")
                    }
                }

                ForEach(workout.sortedExercises) { exercise in
                    NavigationLink(value: exercise) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.headline)
                            Text(setsSummary(for: exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label(restText(for: exercise), systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button("Add Exercise", systemImage: "plus") {
                    isAddingExercise = true
                }
            }
        }
        .environment(\.editMode, $editMode)
        .themedBackground()
        .navigationTitle(workout.name)
        .toolbar {
            Button(isEditing ? "Done" : "Edit") {
                toggleEditing()
            }
            .fontWeight(isEditing ? .semibold : .regular)
        }
        .sheet(isPresented: $isAddingExercise) {
            ExercisePickerView { name, muscle in
                addExercise(named: name, muscle: muscle)
            }
        }
    }

    private func toggleEditing() {
        if isEditing {
            isNameFocused = false
            // Don't leave a workout without a name.
            if workout.name.trimmingCharacters(in: .whitespaces).isEmpty {
                workout.name = "New Workout"
            }
        }
        withAnimation {
            editMode = isEditing ? .inactive : .active
        }
    }

    private func start() {
        Task {
            await RestTimer.requestNotificationPermission()
        }
        // ContentView presents the live workout as soon as the in-progress log appears.
        WorkoutSession.start(workout, in: modelContext, defaultRest: defaultRestSeconds)
    }

    private func setsSummary(for exercise: Exercise) -> String {
        let sets = exercise.sortedSets
        guard !sets.isEmpty else { return "No sets" }
        let working = sets.filter { !$0.isWarmup }
        let warmups = sets.count - working.count
        var text = working.map { "\($0.weight.shortFormatted) \(weightUnit) × \($0.targetReps)" }
            .joined(separator: ", ")
        if warmups > 0 {
            text = "\(warmups)W · " + text
        }
        return text
    }

    /// "1:30" for the default rest, "2:30 · custom" for one the user set.
    private func restText(for exercise: Exercise) -> String {
        let rest = exercise.effectiveRest(default: defaultRestSeconds).restFormatted
        return exercise.restOverride == nil ? rest : "\(rest) · custom"
    }

    private func addExercise(named name: String, muscle: ExerciseCatalog.Muscle?) {
        let nextOrder = (workout.exercises.map(\.order).max() ?? -1) + 1
        let exercise = Exercise(name: name, order: nextOrder)
        exercise.muscle = muscle
        // Start with three sets so the exercise is immediately usable.
        exercise.sets = (0..<3).map { ExerciseSet(order: $0) }
        workout.exercises.append(exercise)
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = workout.sortedExercises
        for index in offsets {
            workout.exercises.removeAll { $0 === sorted[index] }
            modelContext.delete(sorted[index])
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = workout.sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in sorted.enumerated() {
            exercise.order = index
        }
    }
}

/// A row of toggleable day-of-week buttons.
struct WeekdayPicker: View {
    @Binding var selection: [Int]

    var body: some View {
        HStack {
            ForEach(Weekday.ordered, id: \.self) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        selection.removeAll { $0 == day }
                    } else {
                        selection.append(day)
                    }
                } label: {
                    Text(Weekday.veryShortName(day))
                        .font(.subheadline.bold())
                        .frame(width: 38, height: 38)
                        .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: isSelected)
                .accessibilityLabel(Weekday.shortName(day))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if day != Weekday.ordered.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
