import Foundation

/// A built-in list of common lifts for the exercise picker.
nonisolated enum ExerciseCatalog {
    enum Muscle: String, CaseIterable, Identifiable, Sendable {
        case chest = "Chest"
        case back = "Back"
        case shoulders = "Shoulders"
        case arms = "Arms"
        case legs = "Legs"
        case core = "Core"

        var id: String { rawValue }
    }

    struct Entry: Identifiable, Hashable, Sendable {
        var name: String
        var muscle: Muscle

        var id: String { name }
    }

    static let entries: [Entry] =
        chest + back + shoulders + arms + legs + core

    /// Stored when the user explicitly picks "Other", so the name isn't used to guess a group.
    static let otherStoredValue = "Other"

    /// Converts a muscle choice to what's stored on an exercise (nil choice = explicit "Other").
    static func storedValue(for muscle: Muscle?) -> String {
        muscle?.rawValue ?? otherStoredValue
    }

    /// Reads a stored muscle group. Nothing stored (older exercises) falls back to the name.
    static func muscle(fromStored stored: String?, name: String) -> Muscle? {
        guard let stored else { return Recovery.muscle(for: name) }
        return Muscle(rawValue: stored)
    }

    // Existing names are kept as-is so exercises already in plans still match exactly.

    private static let chest: [Entry] = [
        Entry(name: "Bench Press", muscle: .chest),
        Entry(name: "Incline Bench Press", muscle: .chest),
        Entry(name: "Decline Bench Press", muscle: .chest),
        Entry(name: "Dumbbell Bench Press", muscle: .chest),
        Entry(name: "Incline Dumbbell Press", muscle: .chest),
        Entry(name: "Decline Dumbbell Press", muscle: .chest),
        Entry(name: "Smith Machine Bench Press", muscle: .chest),
        Entry(name: "Machine Chest Press", muscle: .chest),
        Entry(name: "Chest Fly", muscle: .chest),
        Entry(name: "Incline Dumbbell Fly", muscle: .chest),
        Entry(name: "Cable Crossover", muscle: .chest),
        Entry(name: "Low-to-High Cable Fly", muscle: .chest),
        Entry(name: "Pec Deck", muscle: .chest),
        Entry(name: "Dip", muscle: .chest),
        Entry(name: "Push-Up", muscle: .chest),
        Entry(name: "Incline Push-Up", muscle: .chest),
        Entry(name: "Deficit Push-Up", muscle: .chest),
    ]

    private static let back: [Entry] = [
        Entry(name: "Deadlift", muscle: .back),
        Entry(name: "Rack Pull", muscle: .back),
        Entry(name: "Barbell Row", muscle: .back),
        Entry(name: "Pendlay Row", muscle: .back),
        Entry(name: "Dumbbell Row", muscle: .back),
        Entry(name: "T-Bar Row", muscle: .back),
        Entry(name: "Chest-Supported Row", muscle: .back),
        Entry(name: "Seated Cable Row", muscle: .back),
        Entry(name: "Machine Row", muscle: .back),
        Entry(name: "Inverted Row", muscle: .back),
        Entry(name: "Pull-Up", muscle: .back),
        Entry(name: "Chin-Up", muscle: .back),
        Entry(name: "Neutral-Grip Pull-Up", muscle: .back),
        Entry(name: "Assisted Pull-Up", muscle: .back),
        Entry(name: "Lat Pulldown", muscle: .back),
        Entry(name: "Close-Grip Lat Pulldown", muscle: .back),
        Entry(name: "Straight-Arm Pulldown", muscle: .back),
        Entry(name: "Dumbbell Pullover", muscle: .back),
        Entry(name: "Back Extension", muscle: .back),
    ]

    private static let shoulders: [Entry] = [
        Entry(name: "Overhead Press", muscle: .shoulders),
        Entry(name: "Push Press", muscle: .shoulders),
        Entry(name: "Dumbbell Shoulder Press", muscle: .shoulders),
        Entry(name: "Arnold Press", muscle: .shoulders),
        Entry(name: "Machine Shoulder Press", muscle: .shoulders),
        Entry(name: "Landmine Press", muscle: .shoulders),
        Entry(name: "Lateral Raise", muscle: .shoulders),
        Entry(name: "Cable Lateral Raise", muscle: .shoulders),
        Entry(name: "Machine Lateral Raise", muscle: .shoulders),
        Entry(name: "Front Raise", muscle: .shoulders),
        Entry(name: "Rear Delt Fly", muscle: .shoulders),
        Entry(name: "Reverse Pec Deck", muscle: .shoulders),
        Entry(name: "Face Pull", muscle: .shoulders),
        Entry(name: "Upright Row", muscle: .shoulders),
        Entry(name: "Shrug", muscle: .shoulders),
        Entry(name: "Dumbbell Shrug", muscle: .shoulders),
    ]

    private static let arms: [Entry] = [
        Entry(name: "Barbell Curl", muscle: .arms),
        Entry(name: "EZ-Bar Curl", muscle: .arms),
        Entry(name: "Dumbbell Curl", muscle: .arms),
        Entry(name: "Hammer Curl", muscle: .arms),
        Entry(name: "Incline Dumbbell Curl", muscle: .arms),
        Entry(name: "Preacher Curl", muscle: .arms),
        Entry(name: "Concentration Curl", muscle: .arms),
        Entry(name: "Cable Curl", muscle: .arms),
        Entry(name: "Spider Curl", muscle: .arms),
        Entry(name: "Reverse Curl", muscle: .arms),
        Entry(name: "Wrist Curl", muscle: .arms),
        Entry(name: "Tricep Pushdown", muscle: .arms),
        Entry(name: "Rope Pushdown", muscle: .arms),
        Entry(name: "Skull Crusher", muscle: .arms),
        Entry(name: "Overhead Tricep Extension", muscle: .arms),
        Entry(name: "Tricep Kickback", muscle: .arms),
        Entry(name: "Bench Dip", muscle: .arms),
        Entry(name: "Close-Grip Bench Press", muscle: .arms),
        Entry(name: "Diamond Push-Up", muscle: .arms),
    ]

    private static let legs: [Entry] = [
        Entry(name: "Back Squat", muscle: .legs),
        Entry(name: "Front Squat", muscle: .legs),
        Entry(name: "Goblet Squat", muscle: .legs),
        Entry(name: "Hack Squat", muscle: .legs),
        Entry(name: "Smith Machine Squat", muscle: .legs),
        Entry(name: "Leg Press", muscle: .legs),
        Entry(name: "Bulgarian Split Squat", muscle: .legs),
        Entry(name: "Walking Lunge", muscle: .legs),
        Entry(name: "Reverse Lunge", muscle: .legs),
        Entry(name: "Step-Up", muscle: .legs),
        Entry(name: "Romanian Deadlift", muscle: .legs),
        Entry(name: "Stiff-Leg Deadlift", muscle: .legs),
        Entry(name: "Sumo Deadlift", muscle: .legs),
        Entry(name: "Good Morning", muscle: .legs),
        Entry(name: "Leg Extension", muscle: .legs),
        Entry(name: "Leg Curl", muscle: .legs),
        Entry(name: "Seated Leg Curl", muscle: .legs),
        Entry(name: "Nordic Curl", muscle: .legs),
        Entry(name: "Hip Thrust", muscle: .legs),
        Entry(name: "Glute Bridge", muscle: .legs),
        Entry(name: "Cable Glute Kickback", muscle: .legs),
        Entry(name: "Hip Abduction", muscle: .legs),
        Entry(name: "Hip Adduction", muscle: .legs),
        Entry(name: "Calf Raise", muscle: .legs),
        Entry(name: "Seated Calf Raise", muscle: .legs),
    ]

    private static let core: [Entry] = [
        Entry(name: "Plank", muscle: .core),
        Entry(name: "Side Plank", muscle: .core),
        Entry(name: "Hanging Leg Raise", muscle: .core),
        Entry(name: "Hanging Knee Raise", muscle: .core),
        Entry(name: "Toes to Bar", muscle: .core),
        Entry(name: "Cable Crunch", muscle: .core),
        Entry(name: "Crunch", muscle: .core),
        Entry(name: "Bicycle Crunch", muscle: .core),
        Entry(name: "Decline Sit-Up", muscle: .core),
        Entry(name: "Ab Wheel Rollout", muscle: .core),
        Entry(name: "Russian Twist", muscle: .core),
        Entry(name: "Dead Bug", muscle: .core),
        Entry(name: "Pallof Press", muscle: .core),
        Entry(name: "Mountain Climber", muscle: .core),
        Entry(name: "Farmer's Carry", muscle: .core),
    ]
}
