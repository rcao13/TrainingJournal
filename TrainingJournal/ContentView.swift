import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Workouts", systemImage: "dumbbell.fill") {
                WorkoutsView()
            }
            Tab("Nutrition", systemImage: "fork.knife") {
                NutritionView()
            }
            Tab("Weight", systemImage: "scalemass.fill") {
                WeightView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutPlan.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
