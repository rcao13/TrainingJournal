import SwiftUI
import SwiftData

/// Navigation value for an exercise's progress screen (exercises are matched by name).
struct ExerciseRoute: Hashable {
    let name: String
}

/// Root of the History tab: finished workouts by month, and per-exercise progress.
struct HistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case workouts = "Workouts"
        case exercises = "Exercises"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Query(filter: #Predicate<WorkoutLog> { $0.endDate != nil }, sort: \WorkoutLog.startDate, order: .reverse)
    private var logs: [WorkoutLog]

    @State private var mode = Mode.workouts

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if logs.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts Yet", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Finished workouts show up here, along with your progress and personal records.")
                    }
                } else if mode == .workouts {
                    workoutSections
                } else {
                    exerciseSection
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutLog.self) { log in
                LogDetailView(log: log)
            }
            .navigationDestination(for: ExerciseRoute.self) { route in
                ExerciseProgressView(name: route.name)
            }
        }
    }

    // MARK: Workouts

    private var monthGroups: [(month: Date, logs: [WorkoutLog])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) { log in
            calendar.dateInterval(of: .month, for: log.startDate)?.start ?? log.startDate
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    @ViewBuilder
    private var workoutSections: some View {
        ForEach(monthGroups, id: \.month) { group in
            Section(group.month.formatted(.dateTime.month(.wide).year())) {
                ForEach(group.logs) { log in
                    NavigationLink(value: log) {
                        LogRow(log: log, weightUnit: weightUnit)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(group.logs[index])
                    }
                }
            }
        }
    }

    // MARK: Exercises

    private struct ExerciseSummary: Identifiable {
        var name: String
        var performances: [SetPerformance] = []
        var sessionCount = 0
        var lastDate: Date

        var id: String { name.lowercased() }
        var records: PersonalRecords { PersonalRecords(performances) }
    }

    private var exerciseSummaries: [ExerciseSummary] {
        var byName: [String: ExerciseSummary] = [:]
        for log in logs {
            for exercise in log.exercises {
                let key = exercise.name.lowercased()
                // Logs are newest first, so the first spelling seen is the most recent one.
                var summary = byName[key] ?? ExerciseSummary(name: exercise.name, lastDate: log.startDate)
                summary.performances += exercise.performances
                summary.sessionCount += 1
                byName[key] = summary
            }
        }
        return byName.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var exerciseSection: some View {
        Section {
            ForEach(exerciseSummaries) { summary in
                NavigationLink(value: ExerciseRoute(name: summary.name)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.name)
                                .font(.headline)
                            Text("^[\(summary.sessionCount) session](inflect: true) · last \(summary.lastDate.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(summary.records.bestEstimated1RM.shortFormatted) \(weightUnit)")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("best e1RM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct LogRow: View {
    let log: WorkoutLog
    let weightUnit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.workoutName)
                    .font(.headline)
                Spacer()
                Text(log.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label(log.duration.workoutDurationFormatted, systemImage: "stopwatch")
                Label("\(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)", systemImage: "scalemass")
                Label("\(log.completedSets.count)", systemImage: "checkmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// A finished workout's details.
struct LogDetailView: View {
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Bindable var log: WorkoutLog

    var body: some View {
        List {
            Section {
                HStack {
                    StatTile(title: "Duration", value: log.duration.workoutDurationFormatted, systemImage: "stopwatch")
                    StatTile(title: "Volume", value: "\(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)", systemImage: "scalemass")
                    StatTile(title: "Sets", value: "\(log.completedSets.count)", systemImage: "checkmark.circle")
                }
            } footer: {
                Text(log.startDate.formatted(date: .complete, time: .shortened))
            }

            Section("Notes") {
                TextField("Add notes", text: $log.notes, axis: .vertical)
                    .lineLimit(1...6)
            }

            Section("Exercises") {
                ForEach(log.sortedExercises) { exercise in
                    NavigationLink(value: ExerciseRoute(name: exercise.name)) {
                        LoggedExerciseRow(exercise: exercise, weightUnit: weightUnit)
                    }
                }
            }
        }
        .navigationTitle(log.workoutName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkoutPlan.self, WorkoutLog.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
