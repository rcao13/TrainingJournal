import SwiftUI

extension View {
    /// Shows a decimal number pad where the platform supports it.
    func decimalKeyboard() -> some View {
        #if os(iOS) || os(visionOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Shows an integer number pad where the platform supports it.
    func numberKeyboard() -> some View {
        #if os(iOS) || os(visionOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}

/// A labeled row with a trailing numeric text field.
struct NumberFieldRow: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .decimalKeyboard()
                .frame(maxWidth: 120)
            if !unit.isEmpty {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
