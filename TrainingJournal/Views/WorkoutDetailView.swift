import SwiftUI
import SwiftData

/// Edits a workout's name, scheduled weekdays, and exercises, and starts a session.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Bindable var workout: Workout

    @Query(filter: #Predicate<WorkoutLog> { $0.endDate == nil })
    private var activeLogs: [WorkoutLog]

    @State private var isAddingExercise = false

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

            Section("Name") {
                TextField("Workout name", text: $workout.name)
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
                            Label(exercise.restSeconds.restFormatted, systemImage: "timer")
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
        .themedBackground()
        .navigationTitle(workout.name)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $isAddingExercise) {
            ExercisePickerView { name, rest in
                addExercise(named: name, restSeconds: rest)
            }
        }
    }

    private func start() {
        Task {
            await RestTimer.requestNotificationPermission()
        }
        // ContentView presents the live workout as soon as the in-progress log appears.
        WorkoutSession.start(workout, in: modelContext)
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

    private func addExercise(named name: String, restSeconds: Int) {
        let nextOrder = (workout.exercises.map(\.order).max() ?? -1) + 1
        let exercise = Exercise(name: name, order: nextOrder, restSeconds: restSeconds)
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
