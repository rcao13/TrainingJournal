import SwiftUI
import SwiftData

/// Shows the workouts in a plan and lets the user add, reorder, and delete them.
struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: WorkoutPlan

    @State private var isAddingWorkout = false
    @State private var newWorkoutName = ""
    /// The name can only be changed while editing, so it isn't renamed by a stray tap.
    @State private var editMode: EditMode = .inactive
    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { editMode.isEditing }

    var body: some View {
        List {
            if isEditing {
                Section("Plan Name") {
                    TextField("Plan name", text: $plan.name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                }
            }

            Section("Workouts") {
                ForEach(plan.sortedWorkouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutRow(workout: workout)
                    }
                }
                .onDelete(perform: deleteWorkouts)
                .onMove(perform: moveWorkouts)

                Button("Add Workout", systemImage: "plus") {
                    isAddingWorkout = true
                }
            }
        }
        .environment(\.editMode, $editMode)
        .themedBackground()
        .navigationTitle(plan.name)
        .toolbar {
            Button(isEditing ? "Done" : "Edit") {
                toggleEditing()
            }
            .fontWeight(isEditing ? .semibold : .regular)
        }
        .alert("New Workout", isPresented: $isAddingWorkout) {
            TextField("e.g. Push Day", text: $newWorkoutName)
            Button("Cancel", role: .cancel) {
                newWorkoutName = ""
            }
            Button("Add") {
                addWorkout()
            }
        }
    }

    private func toggleEditing() {
        if isEditing {
            isNameFocused = false
            // Don't leave a plan without a name.
            if plan.name.trimmingCharacters(in: .whitespaces).isEmpty {
                plan.name = "New Plan"
            }
        }
        withAnimation {
            editMode = isEditing ? .inactive : .active
        }
    }

    private func addWorkout() {
        let name = newWorkoutName.trimmingCharacters(in: .whitespaces)
        let nextOrder = (plan.workouts.map(\.order).max() ?? -1) + 1
        let workout = Workout(name: name.isEmpty ? "New Workout" : name, order: nextOrder)
        plan.workouts.append(workout)
        newWorkoutName = ""
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        let sorted = plan.sortedWorkouts
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }

    private func moveWorkouts(from source: IndexSet, to destination: Int) {
        var sorted = plan.sortedWorkouts
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, workout) in sorted.enumerated() {
            workout.order = index
        }
    }
}
