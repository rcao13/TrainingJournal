import SwiftUI
import SwiftData

/// Edits an exercise's name and its sets (weight and reps).
struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Bindable var exercise: Exercise

    var body: some View {
        List {
            Section("Name") {
                TextField("Exercise name", text: $exercise.name)
            }

            Section {
                ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                    SetEditorRow(number: index + 1, set: set, weightUnit: weightUnit)
                }
                .onDelete(perform: deleteSets)

                Button("Add Set", systemImage: "plus") {
                    addSet()
                }
            } header: {
                Text("Sets")
            } footer: {
                Text("These values pre-fill the next time you start this workout.")
            }
        }
        .navigationTitle(exercise.name)
    }

    private func addSet() {
        // Copy the previous set's values, since consecutive sets are usually similar.
        let last = exercise.sortedSets.last
        let set = ExerciseSet(
            order: (last?.order ?? -1) + 1,
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 10
        )
        exercise.sets.append(set)
    }

    private func deleteSets(at offsets: IndexSet) {
        let sorted = exercise.sortedSets
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

private struct SetEditorRow: View {
    let number: Int
    @Bindable var set: ExerciseSet
    let weightUnit: String

    var body: some View {
        HStack {
            Text("Set \(number)")
                .font(.subheadline.bold())
                .frame(width: 56, alignment: .leading)
            TextField("Weight", value: $set.weight, format: .number)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            Text(weightUnit)
                .foregroundStyle(.secondary)
            TextField("Reps", value: $set.reps, format: .number)
                .numberKeyboard()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 64)
            Text("reps")
                .foregroundStyle(.secondary)
        }
    }
}
