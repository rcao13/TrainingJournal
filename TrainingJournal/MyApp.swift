import SwiftUI
import SwiftData

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Related models (Workout, Exercise, ExerciseSet) are discovered through relationships.
        .modelContainer(for: [WorkoutPlan.self, FoodEntry.self, WeightEntry.self])
    }
}
