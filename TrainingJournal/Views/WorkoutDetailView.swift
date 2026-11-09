import SwiftUI
import SwiftData

/// Edits a workout's name, scheduled weekdays, and exercises, and starts a session.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Bindable var workout: Workout

    @State private var isRunning = false
    @State private var isAddingExercise = false
    @State private var newExerciseName = ""

    var body: some View {
        List {
            Section {
                Button {
                    isRunning = true
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(workout.exercises.isEmpty)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if let lastCompleted = workout.lastCompleted {
                    Text("Last completed \(lastCompleted, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Name") {
                TextField("Workout name", text: $workout.name)
            }

            Section("Days") {
                WeekdayPicker(selection: $workout.weekdays)
            }

            Section("Exercises") {
                ForEach(workout.sortedExercises) { exercise in
                    NavigationLink(value: exercise) {
                        VStack(alignment: .leading) {
                            Text(exercise.name)
                            Text(setsSummary(for: exercise))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        .navigationTitle(workout.name)
        #if os(iOS) || os(visionOS)
        .toolbar {
            EditButton()
        }
        #endif
        .alert("New Exercise", isPresented: $isAddingExercise) {
            TextField("e.g. Bench Press", text: $newExerciseName)
            Button("Cancel", role: .cancel) {
                newExerciseName = ""
            }
            Button("Add") {
                addExercise()
            }
        }
        .sheet(isPresented: $isRunning) {
            ActiveWorkoutView(workout: workout)
        }
    }

    private func setsSummary(for exercise: Exercise) -> String {
        let sets = exercise.sortedSets
        guard !sets.isEmpty else { return "No sets" }
        return sets.map { "\($0.weight.shortFormatted)\(weightUnit) × \($0.reps)" }
            .joined(separator: ", ")
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        let nextOrder = (workout.exercises.map(\.order).max() ?? -1) + 1
        let exercise = Exercise(name: name.isEmpty ? "New Exercise" : name, order: nextOrder)
        // Start with three sets so the exercise is immediately usable.
        exercise.sets = (0..<3).map { ExerciseSet(order: $0) }
        workout.exercises.append(exercise)
        newExerciseName = ""
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = workout.sortedExercises
        for index in offsets {
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
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: .circle)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
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
