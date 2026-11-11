import SwiftUI

/// The rest card pinned above the Complete Set button. Counts up from the last completed set,
/// fills a ring toward the goal, and switches to the "ready" colour once the goal is reached.
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var restTimer

    /// Called after the goal changes so the exercise can remember the new rest length.
    var onGoalChanged: (_ exerciseName: String, _ seconds: Int) -> Void = { _, _ in }

    var body: some View {
        if let state = restTimer.state {
            TimelineView(.periodic(from: state.startDate, by: 1)) { context in
                let elapsed = max(0, context.date.timeIntervalSince(state.startDate))
                let goal = Double(state.goalSeconds)
                let isDone = elapsed >= goal
                let tint: Color = isDone ? Theme.ready : .accentColor

                HStack(spacing: 14) {
                    ProgressRing(progress: elapsed / max(goal, 1), color: tint, lineWidth: 5)
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 0) {
                        // Kept short so it never truncates beside the buttons.
                        Text(isDone ? "Ready" : "Resting")
                            .font(.footnote.weight(isDone ? .semibold : .regular))
                            .foregroundStyle(isDone ? tint : Theme.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(elapsed.workoutDurationFormatted)
                                .font(.numeral(32))
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())
                            Text("of \(state.goalSeconds.restFormatted)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.secondary)
                        }
                    }

                    Spacer(minLength: 4)

                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Button("−15") { adjust(by: -15, state: state) }
                                .accessibilityLabel("Shorten rest by 15 seconds")
                            Button("+15") { adjust(by: 15, state: state) }
                                .accessibilityLabel("Lengthen rest by 15 seconds")
                        }
                        Button("Skip") { restTimer.stop() }
                    }
                    .buttonStyle(PillButtonStyle())
                }
                .appCard(padding: 14)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Rest timer for \(state.exerciseName)")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func adjust(by delta: Int, state: RestTimer.State) {
        restTimer.adjustGoal(by: delta)
        if let newGoal = restTimer.state?.goalSeconds {
            onGoalChanged(state.exerciseName, newGoal)
        }
    }
}
