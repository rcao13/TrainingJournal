import SwiftUI
import SwiftData

/// Root of the Nutrition tab: daily calories and macros, grouped by meal.
struct NutritionView: View {
    @State private var selectedDate = Date.now
    @State private var isAddingFood = false
    @State private var isEditingGoals = false

    var body: some View {
        NavigationStack {
            DayNutritionList(selectedDate: $selectedDate)
                .themedBackground()
                .navigationTitle("Nutrition")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Food", systemImage: "plus") {
                            isAddingFood = true
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Goals", systemImage: "target") {
                            isEditingGoals = true
                        }
                    }
                }
                .sheet(isPresented: $isAddingFood) {
                    FoodEntryForm(entry: nil, day: selectedDate)
                }
                .sheet(isPresented: $isEditingGoals) {
                    GoalsView()
                }
        }
    }
}

/// The list for a single day. Its query is rebuilt whenever the selected date changes.
private struct DayNutritionList: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedDate: Date
    @Query private var entries: [FoodEntry]

    @AppStorage(SettingsKey.calorieGoal) private var calorieGoal = 2000.0
    @AppStorage(SettingsKey.proteinGoal) private var proteinGoal = 150.0
    @AppStorage(SettingsKey.carbsGoal) private var carbsGoal = 200.0
    @AppStorage(SettingsKey.fatGoal) private var fatGoal = 65.0

    @State private var editingEntry: FoodEntry?

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate
        let start = Calendar.current.startOfDay(for: selectedDate.wrappedValue)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end },
            sort: \FoodEntry.date
        )
    }

    private var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }

    var body: some View {
        List {
            Section {
                DateStepper(date: $selectedDate)
            }

            Section("Summary") {
                CalorieSummary(eaten: totalCalories, goal: calorieGoal)
                // Each bar is labelled, so they share the accent rather than competing hues.
                MacroProgressRow(title: "Protein", value: totalProtein, goal: proteinGoal, color: .accentColor)
                MacroProgressRow(title: "Carbs", value: totalCarbs, goal: carbsGoal, color: .accentColor)
                MacroProgressRow(title: "Fat", value: totalFat, goal: fatGoal, color: .accentColor)
            }

            ForEach(Meal.allCases) { meal in
                let mealEntries = entries.filter { $0.meal == meal }
                Section {
                    ForEach(mealEntries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            FoodEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(mealEntries[index])
                        }
                    }
                } header: {
                    HStack {
                        Text(meal.title)
                        Spacer()
                        Text("\(mealEntries.reduce(0) { $0 + $1.calories }.formatted(.number.precision(.fractionLength(0)))) kcal")
                    }
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            FoodEntryForm(entry: entry, day: selectedDate)
        }
    }
}

/// Previous/next day buttons around a compact date picker.
private struct DateStepper: View {
    @Binding var date: Date

    var body: some View {
        HStack {
            Button("Previous Day", systemImage: "chevron.left") {
                shift(by: -1)
            }
            .labelStyle(.iconOnly)
            Spacer()
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .labelsHidden()
            if !Calendar.current.isDateInToday(date) {
                Button("Today") {
                    date = .now
                }
            }
            Spacer()
            Button("Next Day", systemImage: "chevron.right") {
                shift(by: 1)
            }
            .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
    }

    private func shift(by days: Int) {
        date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}

private struct CalorieSummary: View {
    let eaten: Double
    let goal: Double

    private var remaining: Double { goal - eaten }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading) {
                    Text(eaten.formatted(.number.precision(.fractionLength(0))))
                        .font(.numeral(40))
                    Text("kcal eaten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(abs(remaining).formatted(.number.precision(.fractionLength(0))))
                        .font(.numeral(24))
                        .foregroundStyle(remaining >= 0 ? Color.primary : Color.red)
                    Text(remaining >= 0 ? "remaining" : "over goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min(eaten, goal), total: max(goal, 1))
                .tint(remaining >= 0 ? Color.accentColor : .red)
        }
        .padding(.vertical, 4)
    }
}

private struct MacroProgressRow: View {
    let title: String
    let value: Double
    let goal: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.shortFormatted) / \(goal.shortFormatted) g")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)
            ProgressView(value: min(value, goal), total: max(goal, 1))
                .tint(color)
        }
    }
}

private struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                Text("P \(entry.protein.shortFormatted)g · C \(entry.carbs.shortFormatted)g · F \(entry.fat.shortFormatted)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                .monospacedDigit()
        }
        .contentShape(.rect)
    }
}

#Preview {
    NutritionView()
        .modelContainer(for: [WorkoutPlan.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
