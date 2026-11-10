import SwiftUI

/// The pinned rest timer shown during a workout. Counts up from the end of the last set,
/// fills a bar toward the goal, and turns green once the goal is reached.
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
                let tint: Color = isDone ? .green : .accentColor

                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isDone ? "Rest goal reached" : "Resting")
                                .font(.caption.bold())
                                .foregroundStyle(tint)
                            Text("\(state.exerciseName) · \(state.setLabel)")
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(elapsed.workoutDurationFormatted)
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                    }

                    ProgressView(value: min(elapsed, goal), total: max(goal, 1))
                        .tint(tint)

                    HStack {
                        Button("−15s") {
                            adjust(by: -15, state: state)
                        }
                        Text("Goal \(state.goalSeconds.restFormatted)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80)
                        Button("+15s") {
                            adjust(by: 15, state: state)
                        }
                        Spacer()
                        Button("Skip", systemImage: "forward.end.fill") {
                            restTimer.stop()
                        }
                        .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(.regularMaterial, in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(tint.opacity(0.4), lineWidth: 1)
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                .accessibilityElement(children: .contain)
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
