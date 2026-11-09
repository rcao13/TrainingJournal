import SwiftUI
import SwiftData

/// A live workout session. Every set starts pre-filled with the weight and reps
/// from last time; tapping Finish saves the new values for next time.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    let workout: Workout

    /// In-progress edits keyed by set, so Cancel can discard them.
    @State private var drafts: [PersistentIdentifier: SetDraft] = [:]
    @State private var startDate = Date.now

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label {
                            Text(startDate, style: .timer)
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "stopwatch")
                        }
                        Spacer()
                        Text("\(completedCount)/\(totalCount) sets")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(workout.sortedExercises) { exercise in
                    Section(exercise.name) {
                        ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                            ActiveSetRow(
                                number: index + 1,
                                previous: set,
                                draft: binding(for: set),
                                weightUnit: weightUnit
                            )
                        }
                    }
                }
            }
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        finish()
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var allSets: [ExerciseSet] {
        workout.sortedExercises.flatMap(\.sortedSets)
    }

    private var totalCount: Int { allSets.count }

    private var completedCount: Int {
        drafts.values.filter(\.isDone).count
    }

    private func binding(for set: ExerciseSet) -> Binding<SetDraft> {
        Binding {
            drafts[set.persistentModelID] ?? SetDraft(weight: set.weight, reps: set.reps)
        } set: { newValue in
            drafts[set.persistentModelID] = newValue
        }
    }

    private func finish() {
        // Write the session's values back so they pre-fill next time.
        for set in allSets {
            if let draft = drafts[set.persistentModelID] {
                set.weight = draft.weight
                set.reps = draft.reps
            }
        }
        workout.lastCompleted = .now
        dismiss()
    }
}

struct SetDraft {
    var weight: Double
    var reps: Int
    var isDone = false
}

private struct ActiveSetRow: View {
    let number: Int
    let previous: ExerciseSet
    @Binding var draft: SetDraft
    let weightUnit: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading) {
                Text("Set \(number)")
                    .font(.subheadline.bold())
                Text("Last: \(previous.weight.shortFormatted) × \(previous.reps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 84, alignment: .leading)

            TextField("Weight", value: $draft.weight, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            Text(weightUnit)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Reps", value: $draft.reps, format: .number)
                .numberKeyboard()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 56)

            Button {
                draft.isDone.toggle()
            } label: {
                Image(systemName: draft.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(draft.isDone ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(draft.isDone ? "Mark set \(number) not done" : "Mark set \(number) done")
        }
    }
}
