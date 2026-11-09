import SwiftUI
import SwiftData

/// Adds a new food entry, or edits an existing one when `entry` is non-nil.
struct FoodEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    let entry: FoodEntry?
    /// The day being viewed; new entries are logged on this day.
    let day: Date

    @State private var name = ""
    @State private var meal = Meal.breakfast
    @State private var calories = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var hasLoaded = false

    /// Up to 10 recently logged foods with unique names, for quick re-entry.
    private var recentFoods: [FoodEntry] {
        var seen = Set<String>()
        return allEntries.filter { seen.insert($0.name.lowercased()).inserted }.prefix(10).map { $0 }
    }

    private var macroCalories: Double {
        protein * 4 + carbs * 4 + fat * 9
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food name", text: $name)
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases) { meal in
                            Text(meal.title).tag(meal)
                        }
                    }
                }

                Section {
                    NumberFieldRow(title: "Calories", value: $calories, unit: "kcal")
                    NumberFieldRow(title: "Protein", value: $protein, unit: "g")
                    NumberFieldRow(title: "Carbs", value: $carbs, unit: "g")
                    NumberFieldRow(title: "Fat", value: $fat, unit: "g")
                } footer: {
                    if macroCalories > 0 {
                        Button("Use \(macroCalories.formatted(.number.precision(.fractionLength(0)))) kcal from macros") {
                            calories = macroCalories.rounded()
                        }
                        .font(.footnote)
                    }
                }

                if entry == nil && !recentFoods.isEmpty {
                    Section("Recent Foods") {
                        ForEach(recentFoods) { food in
                            Button {
                                fill(from: food)
                            } label: {
                                HStack {
                                    Text(food.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(food.calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Add Food" : "Edit Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    private func loadInitialValues() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if let entry {
            fill(from: entry)
            meal = entry.meal
        } else {
            meal = Self.suggestedMeal()
        }
    }

    private func fill(from food: FoodEntry) {
        name = food.name
        calories = food.calories
        protein = food.protein
        carbs = food.carbs
        fat = food.fat
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let entry {
            entry.name = trimmedName
            entry.meal = meal
            entry.calories = calories
            entry.protein = protein
            entry.carbs = carbs
            entry.fat = fat
        } else {
            modelContext.insert(FoodEntry(
                name: trimmedName,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                date: Self.logDate(for: day),
                meal: meal
            ))
        }
        dismiss()
    }

    /// Uses the current time when logging today; otherwise noon on the chosen day.
    private static func logDate(for day: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return .now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    /// Picks a sensible default meal based on the time of day.
    private static func suggestedMeal() -> Meal {
        switch Calendar.current.component(.hour, from: .now) {
        case 4..<11: .breakfast
        case 11..<16: .lunch
        case 16..<22: .dinner
        default: .snack
        }
    }
}
