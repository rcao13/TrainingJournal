import SwiftUI
import SwiftData

/// Edits an exercise's name, rest goal, notes, and planned sets.
struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Bindable var exercise: Exercise

    var body: some View {
        let sets = exercise.sortedSets
        let labels = setLabels(isWarmup: sets.map(\.isWarmup))

        List {
            Section {
                TextField("Exercise name", text: $exercise.name)
                RestPicker(title: "Rest between sets", seconds: $exercise.restSeconds)
                TextField("Notes (seat height, grip…)", text: $exercise.notes, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    SetEditorRow(label: labels[index], set: set, weightUnit: weightUnit)
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                delete(set)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button(set.isWarmup ? "Working Set" : "Warm-up", systemImage: "flame") {
                                set.isWarmup.toggle()
                            }
                            .tint(.yellow)
                        }
                }

                Button("Add Set", systemImage: "plus") {
                    addSet()
                }
            } header: {
                HStack {
                    Text("Sets")
                    Spacer()
                    Text("Weight · Target reps")
                }
            } footer: {
                Text("Swipe right on a set to mark it as a warm-up. Weights update automatically after each workout.")
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }

    private func addSet() {
        // Copy the previous set's values, since consecutive sets are usually similar.
        let last = exercise.sortedSets.last
        exercise.sets.append(ExerciseSet(
            order: (last?.order ?? -1) + 1,
            weight: last?.weight ?? 0,
            reps: last?.targetReps ?? 10,
            targetReps: last?.targetReps ?? 10
        ))
    }

    private func delete(_ set: ExerciseSet) {
        exercise.sets.removeAll { $0 === set }
        modelContext.delete(set)
    }
}

private struct SetEditorRow: View {
    let label: String
    @Bindable var set: ExerciseSet
    let weightUnit: String

    var body: some View {
        HStack(spacing: 10) {
            SetBadge(label: label, isWarmup: set.isWarmup)
            Spacer()
            CompactNumberField(placeholder: "0", value: $set.weight)
                .frame(width: 90)
            Text(weightUnit)
                .foregroundStyle(.secondary)
            Text("×")
                .foregroundStyle(.secondary)
            CompactIntField(placeholder: "0", value: $set.targetReps)
                .frame(width: 60)
            Text("reps")
                .foregroundStyle(.secondary)
        }
        .onChange(of: set.targetReps) { _, newValue in
            // Changing the plan's target also resets the pre-filled reps for next time.
            set.reps = newValue
        }
    }
}
