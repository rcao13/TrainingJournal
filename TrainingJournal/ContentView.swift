import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(RestTimer.self) private var restTimer
    @Query(filter: #Predicate<WorkoutLog> { $0.endDate == nil }, sort: \WorkoutLog.startDate)
    private var activeLogs: [WorkoutLog]

    /// The live workout currently shown full screen.
    @State private var presentedLog: WorkoutLog?
    /// A session the user discarded; deleted once the cover finishes dismissing.
    @State private var logToDiscard: WorkoutLog?

    var body: some View {
        TabView {
            Tab("Workouts", systemImage: "dumbbell.fill") {
                WorkoutsView()
            }
            Tab("History", systemImage: "chart.line.uptrend.xyaxis") {
                HistoryView()
            }
            Tab("Nutrition", systemImage: "fork.knife") {
                NutritionView()
            }
            Tab("Weight", systemImage: "scalemass.fill") {
                WeightView()
            }
        }
        .tabViewBottomAccessory(isEnabled: activeLogs.first != nil) {
            if let log = activeLogs.first {
                ActiveWorkoutAccessory(log: log) {
                    presentedLog = log
                }
            }
        }
        .fullScreenCover(item: $presentedLog, onDismiss: deleteDiscardedLog) { log in
            ActiveWorkoutView(log: log) {
                logToDiscard = log
                presentedLog = nil
            }
        }
        // Opens the live workout when one starts, and resumes it after a relaunch.
        .onChange(of: activeLogs.first?.persistentModelID, initial: true) { _, newID in
            if newID != nil, let log = activeLogs.first {
                presentedLog = log
            } else if presentedLog == nil {
                // No workout in progress, so a leftover rest timer is stale.
                restTimer.stop()
            }
        }
    }

    private func deleteDiscardedLog() {
        if let logToDiscard {
            WorkoutSession.cancel(logToDiscard)
            self.logToDiscard = nil
        }
    }
}

/// The "workout in progress" bar above the tab bar. Tapping it reopens the session.
private struct ActiveWorkoutAccessory: View {
    @Environment(RestTimer.self) private var restTimer
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let log: WorkoutLog
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(log.workoutName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if placement != .inline {
                        Text(log.startDate, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if let rest = restTimer.state {
                    Label {
                        Text(rest.startDate, style: .timer)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "timer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                }
                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume \(log.workoutName)")
    }
}

#Preview {
    ContentView()
        .environment(RestTimer())
        .modelContainer(for: [WorkoutPlan.self, WorkoutLog.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
