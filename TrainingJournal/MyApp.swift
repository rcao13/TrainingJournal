import SwiftUI
import SwiftData
import UserNotifications

@main struct MyApp: App {
    @State private var restTimer = RestTimer()

    /// Held strongly because the notification center only keeps a weak reference.
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(restTimer)
                // Apply the orange accent from the asset catalog app-wide.
                .tint(Color("AccentColor"))
        }
        // Related models (Workout, Exercise, ExerciseSet, LoggedExercise, LoggedSet)
        // are discovered through relationships.
        .modelContainer(for: [WorkoutPlan.self, WorkoutLog.self, FoodEntry.self, WeightEntry.self])
    }
}
