import SwiftUI

/// Searchable list of common lifts. Typing a name that isn't listed offers to add it
/// as a custom exercise, choosing which muscle group it works.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called with the chosen name and its muscle group (nil if the user chose "Other").
    /// New exercises follow the default rest from Settings.
    let onPick: (_ name: String, _ muscle: ExerciseCatalog.Muscle?) -> Void

    @State private var searchText = ""

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var filteredEntries: [ExerciseCatalog.Entry] {
        guard !trimmedSearch.isEmpty else { return ExerciseCatalog.entries }
        return ExerciseCatalog.entries.filter { $0.name.localizedStandardContains(trimmedSearch) }
    }

    private var hasExactMatch: Bool {
        ExerciseCatalog.entries.contains { $0.name.localizedCaseInsensitiveCompare(trimmedSearch) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedSearch.isEmpty && !hasExactMatch {
                    customExerciseSection
                }

                ForEach(ExerciseCatalog.Muscle.allCases) { muscle in
                    let entries = filteredEntries.filter { $0.muscle == muscle }
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                Button {
                                    pick(entry.name, muscle: entry.muscle)
                                } label: {
                                    Text(entry.name)
                                        .foregroundStyle(Theme.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(.rect)
                                }
                            }
                        } header: {
                            HStack {
                                Text(muscle.rawValue)
                                Spacer()
                                Text("\(entries.count)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search or type a custom name"
            )
            .themedBackground()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }

    /// One row per muscle group so a custom exercise is added with the group it works.
    /// The group guessed from the name, if any, is marked as suggested.
    private var customExerciseSection: some View {
        let suggested = Recovery.muscle(for: trimmedSearch)
        return Section {
            ForEach(ExerciseCatalog.Muscle.allCases) { muscle in
                Button {
                    pick(trimmedSearch, muscle: muscle)
                } label: {
                    HStack {
                        Text(muscle.rawValue)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if muscle == suggested {
                            Text("Suggested")
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.tint)
                    }
                    .contentShape(.rect)
                }
            }
            Button {
                pick(trimmedSearch, muscle: nil)
            } label: {
                HStack {
                    Text("Other")
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.tint)
                }
                .contentShape(.rect)
            }
        } header: {
            Text("Add “\(trimmedSearch)” as")
                .textCase(nil)
        } footer: {
            Text("The muscle group is used for the recovery card on Today. You can change it later in the exercise.")
        }
    }

    private func pick(_ name: String, muscle: ExerciseCatalog.Muscle?) {
        onPick(name, muscle)
        dismiss()
    }
}

#Preview {
    ExercisePickerView { _, _ in }
}
