import SwiftUI

/// Searchable list of common lifts, plus a custom name option.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRestSeconds = 90

    /// Called with the chosen name and its suggested rest goal in seconds.
    let onPick: (String, Int) -> Void

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
                    Section {
                        Button {
                            pick(trimmedSearch, rest: defaultRestSeconds)
                        } label: {
                            Label("Add “\(trimmedSearch)”", systemImage: "plus.circle.fill")
                        }
                    }
                }

                ForEach(ExerciseCatalog.Muscle.allCases) { muscle in
                    let entries = filteredEntries.filter { $0.muscle == muscle }
                    if !entries.isEmpty {
                        Section(muscle.rawValue) {
                            ForEach(entries) { entry in
                                Button {
                                    pick(entry.name, rest: entry.restSeconds)
                                } label: {
                                    HStack {
                                        Text(entry.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Label(entry.restSeconds.restFormatted, systemImage: "timer")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(.rect)
                                }
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

    private func pick(_ name: String, rest: Int) {
        onPick(name, rest)
        dismiss()
    }
}

#Preview {
    ExercisePickerView { _, _ in }
}
