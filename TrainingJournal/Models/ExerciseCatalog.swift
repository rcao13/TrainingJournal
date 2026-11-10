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
        /// Suggested default rest; compound lifts get longer rests.
        var restSeconds: Int

        var id: String { name }
    }

    static let entries: [Entry] = [
        // Chest
        Entry(name: "Bench Press", muscle: .chest, restSeconds: 150),
        Entry(name: "Incline Bench Press", muscle: .chest, restSeconds: 120),
        Entry(name: "Dumbbell Bench Press", muscle: .chest, restSeconds: 120),
        Entry(name: "Incline Dumbbell Press", muscle: .chest, restSeconds: 120),
        Entry(name: "Chest Fly", muscle: .chest, restSeconds: 60),
        Entry(name: "Cable Crossover", muscle: .chest, restSeconds: 60),
        Entry(name: "Dip", muscle: .chest, restSeconds: 90),
        Entry(name: "Push-Up", muscle: .chest, restSeconds: 60),
        // Back
        Entry(name: "Deadlift", muscle: .back, restSeconds: 180),
        Entry(name: "Barbell Row", muscle: .back, restSeconds: 120),
        Entry(name: "Dumbbell Row", muscle: .back, restSeconds: 90),
        Entry(name: "Pull-Up", muscle: .back, restSeconds: 120),
        Entry(name: "Chin-Up", muscle: .back, restSeconds: 120),
        Entry(name: "Lat Pulldown", muscle: .back, restSeconds: 90),
        Entry(name: "Seated Cable Row", muscle: .back, restSeconds: 90),
        Entry(name: "Face Pull", muscle: .back, restSeconds: 60),
        // Shoulders
        Entry(name: "Overhead Press", muscle: .shoulders, restSeconds: 150),
        Entry(name: "Dumbbell Shoulder Press", muscle: .shoulders, restSeconds: 120),
        Entry(name: "Lateral Raise", muscle: .shoulders, restSeconds: 60),
        Entry(name: "Rear Delt Fly", muscle: .shoulders, restSeconds: 60),
        Entry(name: "Shrug", muscle: .shoulders, restSeconds: 60),
        // Arms
        Entry(name: "Barbell Curl", muscle: .arms, restSeconds: 60),
        Entry(name: "Dumbbell Curl", muscle: .arms, restSeconds: 60),
        Entry(name: "Hammer Curl", muscle: .arms, restSeconds: 60),
        Entry(name: "Preacher Curl", muscle: .arms, restSeconds: 60),
        Entry(name: "Tricep Pushdown", muscle: .arms, restSeconds: 60),
        Entry(name: "Skull Crusher", muscle: .arms, restSeconds: 60),
        Entry(name: "Overhead Tricep Extension", muscle: .arms, restSeconds: 60),
        Entry(name: "Close-Grip Bench Press", muscle: .arms, restSeconds: 120),
        // Legs
        Entry(name: "Back Squat", muscle: .legs, restSeconds: 180),
        Entry(name: "Front Squat", muscle: .legs, restSeconds: 150),
        Entry(name: "Romanian Deadlift", muscle: .legs, restSeconds: 120),
        Entry(name: "Leg Press", muscle: .legs, restSeconds: 120),
        Entry(name: "Bulgarian Split Squat", muscle: .legs, restSeconds: 90),
        Entry(name: "Walking Lunge", muscle: .legs, restSeconds: 90),
        Entry(name: "Leg Extension", muscle: .legs, restSeconds: 60),
        Entry(name: "Leg Curl", muscle: .legs, restSeconds: 60),
        Entry(name: "Hip Thrust", muscle: .legs, restSeconds: 90),
        Entry(name: "Calf Raise", muscle: .legs, restSeconds: 60),
        // Core
        Entry(name: "Plank", muscle: .core, restSeconds: 60),
        Entry(name: "Hanging Leg Raise", muscle: .core, restSeconds: 60),
        Entry(name: "Cable Crunch", muscle: .core, restSeconds: 60),
        Entry(name: "Ab Wheel Rollout", muscle: .core, restSeconds: 60),
    ]
}
