import SwiftUI
import SwiftData

/// Root of the Workouts tab: today's scheduled workouts and all plans.
struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]

    @State private var isAddingPlan = false
    @State private var newPlanName = ""

    private var todaysWorkouts: [Workout] {
        plans.flatMap(\.sortedWorkouts).filter { $0.weekdays.contains(Weekday.today) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Today · \(Weekday.shortName(Weekday.today))") {
                    if todaysWorkouts.isEmpty {
                        Text("Nothing scheduled today.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(todaysWorkouts) { workout in
                        NavigationLink(value: workout) {
                            WorkoutRow(workout: workout, showsPlan: true)
                        }
                    }
                }

                Section("Plans") {
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            VStack(alignment: .leading) {
                                Text(plan.name)
                                    .font(.headline)
                                Text("^[\(plan.workouts.count) workout](inflect: true)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlans)

                    if plans.isEmpty {
                        Button("Create your first plan", systemImage: "plus") {
                            isAddingPlan = true
                        }
                    }
                }
            }
            .navigationTitle("Workouts")
            .navigationDestination(for: WorkoutPlan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseEditorView(exercise: exercise)
            }
            .toolbar {
                Button("New Plan", systemImage: "plus") {
                    isAddingPlan = true
                }
            }
            .alert("New Plan", isPresented: $isAddingPlan) {
                TextField("Plan name", text: $newPlanName)
                Button("Cancel", role: .cancel) {
                    newPlanName = ""
                }
                Button("Create") {
                    addPlan()
                }
            }
        }
    }

    private func addPlan() {
        let name = newPlanName.trimmingCharacters(in: .whitespaces)
        modelContext.insert(WorkoutPlan(name: name.isEmpty ? "New Plan" : name))
        newPlanName = ""
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
    }
}

/// Compact summary of a workout used in lists.
struct WorkoutRow: View {
    let workout: Workout
    var showsPlan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.name)
                .font(.headline)
            if showsPlan, let plan = workout.plan {
                Text(plan.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label(Weekday.summary(for: workout.weekdays), systemImage: "calendar")
                Spacer()
                Text("^[\(workout.exercises.count) exercise](inflect: true)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutPlan.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
