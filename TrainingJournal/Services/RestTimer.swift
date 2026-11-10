import ActivityKit
import Foundation
import Observation
import UserNotifications

/// A count-up rest timer with a goal. When the goal is reached it fires a haptic
/// (via `goalReachedCount`) and a local notification, but keeps counting so you can
/// see how long you've actually rested. Mirrors itself to a Live Activity.
@Observable
final class RestTimer {
    struct State: Codable, Equatable {
        var workoutName: String
        var exerciseName: String
        var setLabel: String
        var startDate: Date
        var goalDate: Date

        var goalSeconds: Int {
            Int(goalDate.timeIntervalSince(startDate).rounded())
        }
    }

    private(set) var state: State? {
        didSet { persist() }
    }

    /// Increments each time a rest goal is reached; views use it to trigger haptics.
    private(set) var goalReachedCount = 0

    @ObservationIgnored private var alarmTask: Task<Void, Never>?
    @ObservationIgnored private var activity: Activity<RestTimerAttributes>?

    private static let storageKey = "restTimerState"
    private static let notificationID = "rest-timer-goal"
    private static let minimumGoal = 5

    init() {
        // Restore a rest that was running when the app was closed.
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        }
        activity = Activity<RestTimerAttributes>.activities.first
        scheduleAlarm()
    }

    var isRunning: Bool { state != nil }

    func start(workoutName: String, exerciseName: String, setLabel: String, goalSeconds: Int) {
        let now = Date.now
        state = State(
            workoutName: workoutName,
            exerciseName: exerciseName,
            setLabel: setLabel,
            startDate: now,
            goalDate: now.addingTimeInterval(TimeInterval(max(goalSeconds, Self.minimumGoal)))
        )
        refresh()
    }

    /// Moves the goal by `seconds` (e.g. ±15) without restarting the count.
    func adjustGoal(by seconds: Int) {
        guard let state else { return }
        setGoal(seconds: state.goalSeconds + seconds)
    }

    func setGoal(seconds: Int) {
        guard var current = state else { return }
        current.goalDate = current.startDate.addingTimeInterval(TimeInterval(max(seconds, Self.minimumGoal)))
        state = current
        refresh()
    }

    func stop() {
        state = nil
        alarmTask?.cancel()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        endActivities()
    }

    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    // MARK: - Private

    private func refresh() {
        scheduleAlarm()
        scheduleNotification()
        updateActivity()
    }

    /// Sleeps until the goal, then signals the in-app haptic.
    private func scheduleAlarm() {
        alarmTask?.cancel()
        guard let goal = state?.goalDate, goal > .now else { return }
        alarmTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(goal.timeIntervalSinceNow))
            guard !Task.isCancelled else { return }
            self?.goalReachedCount += 1
            // Re-send the content so the Live Activity re-renders in its "goal reached" state.
            // This runs whenever the app gets time (foreground, or on resume); the stale date
            // covers the case where the system re-renders on its own.
            self?.updateActivity()
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard let state, state.goalDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "\(state.goalSeconds.restFormatted) is up. Time for your next set of \(state.exerciseName)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: state.goalDate.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        Task {
            try? await center.add(request)
        }
    }

    private func updateActivity() {
        guard let state else { return }
        let content = ActivityContent(
            state: RestTimerAttributes.ContentState(
                exerciseName: state.exerciseName,
                setLabel: state.setLabel,
                startDate: state.startDate,
                goalDate: state.goalDate
            ),
            // The system re-renders the activity when it goes stale, which is how the
            // Lock Screen switches to "Rest goal reached" while the app is suspended.
            staleDate: state.goalDate
        )

        if let activity, activity.activityState == .active {
            Task {
                await activity.update(content)
            }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            activity = try? Activity.request(
                attributes: RestTimerAttributes(workoutName: state.workoutName),
                content: content
            )
        }
    }

    private func endActivities() {
        activity = nil
        for activity in Activity<RestTimerAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func persist() {
        if let state, let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
    }
}

/// Shows rest notifications as banners with sound even while the app is open.
nonisolated final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
