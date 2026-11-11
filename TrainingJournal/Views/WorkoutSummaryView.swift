import SwiftUI

/// Shown after finishing a workout: duration, volume, sets, and any new PRs.
struct WorkoutSummaryView: View {
    let log: WorkoutLog
    let records: [RecordHit]
    let weightUnit: String
    let onDone: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: records.isEmpty ? "checkmark.seal.fill" : "trophy.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(records.isEmpty ? Theme.ready : Color.accentColor)
                        .accentGlow(records.isEmpty ? Theme.ready : .accentColor)
                        .symbolEffect(.bounce, value: hasAppeared)
                    Text("Workout Complete")
                        .font(.title2.bold())
                    Text(log.workoutName)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                HStack {
                    StatTile(title: "Duration", value: DayTimeline.durationText(log.duration), systemImage: "stopwatch")
                    StatTile(title: "Volume", value: "\(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)", systemImage: "scalemass")
                    StatTile(title: "Sets", value: "\(log.completedSets.count)", systemImage: "checkmark.circle")
                }
            }

            if !records.isEmpty {
                Section("New Personal Records") {
                    ForEach(records) { record in
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(record.exerciseName)
                                    .font(.headline)
                                Text(record.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(record.value.shortFormatted) \(weightUnit)")
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
            }

            Section("Exercises") {
                ForEach(log.sortedExercises) { exercise in
                    LoggedExerciseRow(exercise: exercise, weightUnit: weightUnit)
                }
            }
        }
        .themedBackground()
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onDone)
            }
        }
        .onAppear {
            hasAppeared = true
        }
        .sensoryFeedback(.success, trigger: hasAppeared) { _, appeared in appeared && !records.isEmpty }
    }
}

/// An exercise's sets from a log, e.g. "135 × 8, 135 × 8, 135 × 7".
struct LoggedExerciseRow: View {
    let exercise: LoggedExercise
    let weightUnit: String

    var body: some View {
        let sets = exercise.sortedSets
        let labels = setLabels(isWarmup: sets.map(\.isWarmup))
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.name)
                .font(.headline)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack(spacing: 8) {
                    SetBadge(label: labels[index], isWarmup: set.isWarmup)
                        .scaleEffect(0.8)
                    Text("\(set.weight.shortFormatted) \(weightUnit) × \(set.reps)")
                        .monospacedDigit()
                    Spacer()
                    if !set.isWarmup && set.weight > 0 {
                        Text("e1RM \(TrainingMath.estimated1RM(weight: set.weight, reps: set.reps).shortFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
