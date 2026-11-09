import SwiftUI
import SwiftData

/// Shows the workouts in a plan and lets the user add, reorder, and delete them.
struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: WorkoutPlan

    @State private var isAddingWorkout = false
    @State private var newWorkoutName = ""

    var body: some View {
        List {
            Section("Plan Name") {
                TextField("Plan name", text: $plan.name)
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
        .navigationTitle(plan.name)
        #if os(iOS) || os(visionOS)
        .toolbar {
            EditButton()
        }
        #endif
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
