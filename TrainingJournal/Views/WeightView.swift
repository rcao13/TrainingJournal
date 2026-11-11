import SwiftUI
import SwiftData

/// Root of the Weight tab: a log of body-weight measurements.
struct WeightView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]

    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                if let latest = entries.first {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current")
                                .font(.caption)
                                .foregroundStyle(Theme.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(latest.weight.shortFormatted)
                                    .font(.numeral(48))
                                    .foregroundStyle(Theme.ink)
                                Text(weightUnit)
                                    .font(.title3)
                                    .foregroundStyle(Theme.secondary)
                            }
                            if let first = entries.last, entries.count > 1 {
                                Text("\(changeText(latest.weight - first.weight)) since \(first.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .themedRow()
                }

                Section("History") {
                    if entries.isEmpty {
                        ContentUnavailableView {
                            Label("No Weigh-ins Yet", systemImage: "scalemass")
                        } description: {
                            Text("Log your weight to track the trend over time.")
                        } actions: {
                            Button("Log Weight") {
                                isAdding = true
                            }
                            .buttonStyle(PillButtonStyle())
                        }
                    }
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month().day().year())
                            Spacer()
                            // Entries are newest-first, so the previous weigh-in is the next element.
                            if index + 1 < entries.count {
                                Text(changeText(entry.weight - entries[index + 1].weight))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(entry.weight.shortFormatted) \(weightUnit)")
                                .monospacedDigit()
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .themedRow()
            }
            .themedBackground()
            .navigationTitle("Weight")
            .toolbar {
                Button("Log Weight", systemImage: "plus") {
                    isAdding = true
                }
            }
            .sheet(isPresented: $isAdding) {
                AddWeightView(initialWeight: entries.first?.weight ?? 0)
            }
        }
    }

    private func changeText(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "±")
        return "\(sign)\(abs(delta).shortFormatted) \(weightUnit)"
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

/// Sheet for logging a weigh-in. Also opened from the Today tab.
struct AddWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"

    let initialWeight: Double

    @State private var weight = 0.0
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                NumberFieldRow(title: "Weight", value: $weight, unit: weightUnit)
                DatePicker("Date", selection: $date, in: ...Date.now)
            }
            .themedBackground()
            .navigationTitle("Log Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(WeightEntry(weight: weight, date: date))
                        dismiss()
                    }
                    .disabled(weight <= 0)
                }
            }
            .onAppear {
                weight = initialWeight
            }
        }
    }
}

#Preview {
    WeightView()
        .modelContainer(for: [WorkoutPlan.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
