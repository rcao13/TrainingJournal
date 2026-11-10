import ActivityKit
import Foundation

/// Live Activity data for the rest timer.
/// Keep this identical to the copy in the RestTimerWidget target.
nonisolated struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setLabel: String
        /// When the rest began; the timer counts up from here.
        var startDate: Date
        /// When the rest goal is reached.
        var goalDate: Date
    }

    var workoutName: String
}
