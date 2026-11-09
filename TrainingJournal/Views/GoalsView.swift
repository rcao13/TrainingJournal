import SwiftUI

/// Daily nutrition goals and app-wide units.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.calorieGoal) private var calorieGoal = 2000.0
    @AppStorage(SettingsKey.proteinGoal) private var proteinGoal = 150.0
    @AppStorage(SettingsKey.carbsGoal) private var carbsGoal = 200.0
    @AppStorage(SettingsKey.fatGoal) private var fatGoal = 65.0
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Goals") {
                    NumberFieldRow(title: "Calories", value: $calorieGoal, unit: "kcal")
                    NumberFieldRow(title: "Protein", value: $proteinGoal, unit: "g")
                    NumberFieldRow(title: "Carbs", value: $carbsGoal, unit: "g")
                    NumberFieldRow(title: "Fat", value: $fatGoal, unit: "g")
                }

                Section("Units") {
                    Picker("Weight", selection: $weightUnit) {
                        Text("Pounds (lb)").tag("lb")
                        Text("Kilograms (kg)").tag("kg")
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GoalsView()
}
