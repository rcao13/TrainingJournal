import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation of the rest timer.
/// The timer counts up from the start of the rest; the bar fills until the goal.
/// The app sets the activity's stale date to the goal, so the system re-renders it
/// then and these views switch to a mint "Rest goal reached" state.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            RestTimerLockScreenView(context: context)
                .activityBackgroundTint(RestColors.background)
                .activitySystemActionForegroundColor(restTint(for: context))
        } dynamicIsland: { context in
            let tint = restTint(for: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(isGoalReached(context) ? "Go" : "Rest",
                          systemImage: isGoalReached(context) ? "checkmark.circle.fill" : "timer")
                        .font(.headline)
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .timer)
                        .font(.title2.bold().monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(context.state.exerciseName)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("Goal \(goalText(context.state))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        RestProgressBar(state: context.state, tint: tint)
                    }
                }
            } compactLeading: {
                Image(systemName: isGoalReached(context) ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(isGoalReached(context) ? tint : .primary)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: isGoalReached(context) ? "checkmark.circle.fill" : "timer")
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }
}

private struct RestTimerLockScreenView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        let isDone = isGoalReached(context)
        let tint = restTint(for: context)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(isDone ? "Rest goal reached" : "Resting",
                          systemImage: isDone ? "checkmark.circle.fill" : "timer")
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                    Text(context.state.exerciseName)
                        .font(.headline)
                    Text(context.state.setLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.startDate, style: .timer)
                        .font(.system(size: 40, weight: .semibold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                    Text("Goal \(goalText(context.state))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            RestProgressBar(state: context.state, tint: tint)
            if !isDone {
                // Counts down to 0:00 on its own, so the goal is visible even if the
                // system doesn't re-render the activity when it's reached.
                HStack(spacing: 4) {
                    Text("Next set in")
                    // Timer text is last so its reserved width doesn't leave a gap mid-sentence.
                    Text(timerInterval: context.state.startDate...max(context.state.goalDate, context.state.startDate.addingTimeInterval(1)),
                         countsDown: true)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        // The card always uses the Midnight background, so render its text for dark.
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

/// Fills from the start of the rest to the goal, then stays full.
private struct RestProgressBar: View {
    let state: RestTimerAttributes.ContentState
    let tint: Color

    var body: some View {
        ProgressView(timerInterval: state.startDate...max(state.goalDate, state.startDate.addingTimeInterval(1)), countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(tint)
    }
}

/// True once the rest goal has passed. `isStale` covers the system re-render at the goal;
/// the date check covers renders that happen after it for any other reason.
private func isGoalReached(_ context: ActivityViewContext<RestTimerAttributes>) -> Bool {
    context.isStale || Date.now >= context.state.goalDate
}

private func restTint(for context: ActivityViewContext<RestTimerAttributes>) -> Color {
    isGoalReached(context) ? RestColors.ready : RestColors.accent
}

/// Midnight palette, matching the app's dark mode. The widget target can't see the
/// app's Theme, so the few colours it needs are repeated here.
private enum RestColors {
    static let accent = Color(red: 0x8D / 255, green: 0xA2 / 255, blue: 0xFF / 255)
    static let ready = Color(red: 0x5E / 255, green: 0xD3 / 255, blue: 0xA8 / 255)
    static let background = Color(red: 0x0E / 255, green: 0x10 / 255, blue: 0x14 / 255).opacity(0.92)
}

private func goalText(_ state: RestTimerAttributes.ContentState) -> String {
    let seconds = Int(state.goalDate.timeIntervalSince(state.startDate).rounded())
    return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
}

#Preview("Resting", as: .content, using: RestTimerAttributes(workoutName: "Push Day")) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(
        exerciseName: "Bench Press",
        setLabel: "Set 2 of 4 done",
        startDate: .now,
        goalDate: .now.addingTimeInterval(120)
    )
    RestTimerAttributes.ContentState(
        exerciseName: "Bench Press",
        setLabel: "Set 2 of 4 done",
        startDate: .now.addingTimeInterval(-150),
        goalDate: .now.addingTimeInterval(-30)
    )
}
