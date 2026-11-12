import Foundation
import SwiftUI
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
    /// How much weight the overload hint suggests adding (5 lb / 2.5 kg by default).
    static let weightIncrement = "weightIncrement"
    /// Rest between sets for every exercise that doesn't have its own, in seconds.
    static let defaultRestSeconds = "defaultRestSeconds"
    /// Raw value of `AppAppearance`.
    static let appearance = "appearance"
}

/// Light, dark, or follow the system setting.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Nil lets the app follow the system appearance.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Reads the default rest outside of SwiftUI views (views use `@AppStorage`).
enum RestDefaults {
    static let fallbackSeconds = 90

    static var seconds: Int {
        let stored = UserDefaults.standard.integer(forKey: SettingsKey.defaultRestSeconds)
        return stored > 0 ? stored : fallbackSeconds
    }
}

extension Double {
    /// Formats with up to one decimal place, e.g. "135" or "62.5".
    var shortFormatted: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}
