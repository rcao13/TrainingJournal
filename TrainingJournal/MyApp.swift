import SwiftUI
import SwiftData
import UserNotifications

@main struct MyApp: App {
    @State private var restTimer = RestTimer()
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system

    /// Held strongly because the notification center only keeps a weak reference.
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(restTimer)
                // Apply the accent (navy in light, periwinkle in dark) app-wide.
                .tint(Color("AccentColor"))
                // Applies to the whole window, so sheets and the live workout follow it too.
                .preferredColorScheme(appearance.colorScheme)
        }
        // Related models (Workout, Exercise, ExerciseSet, LoggedExercise, LoggedSet)
        // are discovered through relationships.
        .modelContainer(for: [WorkoutPlan.self, WorkoutLog.self, FoodEntry.self, WeightEntry.self])
    }
}
