import Foundation
import SwiftData

enum Meal: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snacks"
        }
    }
}

/// A logged food item with calories and macronutrients (grams).
@Model
final class FoodEntry {
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var date: Date
    /// Raw value of `Meal`, stored as a string for simple persistence.
    var mealRawValue: String

    init(name: String, calories: Double, protein: Double, carbs: Double, fat: Double, date: Date, meal: Meal) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
        self.mealRawValue = meal.rawValue
    }

    var meal: Meal {
        get { Meal(rawValue: mealRawValue) ?? .snack }
        set { mealRawValue = newValue.rawValue }
    }
}

/// A body-weight measurement.
@Model
final class WeightEntry {
    var weight: Double
    var date: Date

    init(weight: Double, date: Date) {
        self.weight = weight
        self.date = date
    }
}

/// Keys and defaults for values kept in `@AppStorage`.
enum SettingsKey {
    static let weightUnit = "weightUnit"
    static let calorieGoal = "calorieGoal"
    static let proteinGoal = "proteinGoal"
    static let carbsGoal = "carbsGoal"
    static let fatGoal = "fatGoal"
}

extension Double {
    /// Formats with up to one decimal place, e.g. "135" or "62.5".
    var shortFormatted: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}
