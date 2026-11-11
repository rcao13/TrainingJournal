import SwiftUI

/// App settings: daily nutrition goals, units, and training defaults.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.calorieGoal) private var calorieGoal = 2000.0
    @AppStorage(SettingsKey.proteinGoal) private var proteinGoal = 150.0
    @AppStorage(SettingsKey.carbsGoal) private var carbsGoal = 200.0
    @AppStorage(SettingsKey.fatGoal) private var fatGoal = 65.0
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @AppStorage(SettingsKey.weightIncrement) private var weightIncrement = 5.0
    @AppStorage(SettingsKey.defaultRestSeconds) private var defaultRestSeconds = 90

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

                Section {
                    RestPicker(title: "Default rest", seconds: $defaultRestSeconds)
                    NumberFieldRow(title: "Weight increase", value: $weightIncrement, unit: weightUnit)
                } header: {
                    Text("Training")
                } footer: {
                    Text("Default rest applies to custom exercises. When you hit every target rep, the next workout suggests adding the weight increase.")
                }
            }
            .onChange(of: weightUnit) { _, newUnit in
                // Switch to a sensible step for the new unit.
                weightIncrement = newUnit == "kg" ? 2.5 : 5
            }
            .themedBackground()
            .navigationTitle("Settings")
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
