import SwiftUI

extension View {
    /// Shows a decimal number pad.
    func decimalKeyboard() -> some View {
        keyboardType(.decimalPad)
    }

    /// Shows an integer number pad.
    func numberKeyboard() -> some View {
        keyboardType(.numberPad)
    }

    /// Adds a Done button above the keyboard, since number pads have no return key.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

/// A labeled row with a trailing numeric text field.
struct NumberFieldRow: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""

    /// Shows an empty field (with a "0" placeholder) instead of a literal 0,
    /// so typing doesn't append to a leftover zero.
    private var editableValue: Binding<Double?> {
        Binding(
            get: { value == 0 ? nil : value },
            set: { value = $0 ?? 0 }
        )
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: editableValue, format: .number, prompt: Text("0"))
                .multilineTextAlignment(.trailing)
                .decimalKeyboard()
                .frame(maxWidth: 120)
            if !unit.isEmpty {
                // Fixed width so values line up whatever the unit ("g" vs "kcal").
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
        }
    }
}

/// Picks a rest goal in 15-second steps from 0:15 to 10:00.
struct RestPicker: View {
    var title = "Rest"
    @Binding var seconds: Int

    private static let options = Array(stride(from: 15, through: 600, by: 15))

    var body: some View {
        Picker(selection: $seconds) {
            // Keep a non-standard stored value selectable.
            if !Self.options.contains(seconds) {
                Text(seconds.restFormatted).tag(seconds)
            }
            ForEach(Self.options, id: \.self) { option in
                Text(option.restFormatted).tag(option)
            }
        } label: {
            Label(title, systemImage: "timer")
        }
    }
}

/// Rest picker for one exercise. "Default" follows the rest in Settings (so it changes when
/// that does); any specific time makes the exercise's rest custom.
struct ExerciseRestPicker: View {
    var title = "Rest"
    /// Nil means "use the default".
    @Binding var override: Int?
    let defaultSeconds: Int

    private static let options = Array(stride(from: 15, through: 600, by: 15))

    var body: some View {
        Picker(selection: $override) {
            Text("Default (\(defaultSeconds.restFormatted))").tag(Int?.none)
            if let override, !Self.options.contains(override) {
                Text(override.restFormatted).tag(Optional(override))
            }
            ForEach(Self.options, id: \.self) { option in
                Text(option.restFormatted).tag(Optional(option))
            }
        } label: {
            Label(title, systemImage: "timer")
        }
    }
}

/// A large, easy-to-hit numeric field used for weight and reps during a workout.
struct CompactNumberField: View {
    let placeholder: String
    @Binding var value: Double

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
            .decimalKeyboard()
            .modifier(CompactFieldStyle())
    }
}

struct CompactIntField: View {
    let placeholder: String
    @Binding var value: Int

    var body: some View {
        TextField(placeholder, value: $value, format: .number)
            .numberKeyboard()
            .modifier(CompactFieldStyle())
    }
}

private struct CompactFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.numeral(20))
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Theme.track, in: .rect(cornerRadius: 12))
    }
}

/// A round badge showing a set's number, or "W" for warm-ups.
struct SetBadge: View {
    let label: String
    let isWarmup: Bool

    var body: some View {
        Text(label)
            .font(.subheadline.bold().monospacedDigit())
            .frame(width: 30, height: 30)
            .background(isWarmup ? Color.accentColor.opacity(0.14) : Theme.track, in: .circle)
            .foregroundStyle(isWarmup ? Color.accentColor : Theme.ink)
            .accessibilityLabel(isWarmup ? "Warm-up set" : "Set \(label)")
    }
}

/// Numbers working sets 1, 2, 3… and labels warm-ups "W".
func setLabels(isWarmup flags: [Bool]) -> [String] {
    var count = 0
    return flags.map { isWarmup in
        if isWarmup { return "W" }
        count += 1
        return "\(count)"
    }
}

/// A small stat used in headers and summaries.
struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(value)
                .font(.numeral(18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension TimeInterval {
    /// "45:12" or "1:05:12".
    var workoutDurationFormatted: String {
        let total = Int(self)
        let pattern: Duration.TimeFormatStyle.Pattern = total >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(total).formatted(.time(pattern: pattern))
    }
}
