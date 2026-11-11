import SwiftUI
import SwiftData

/// The home tab: this week at a glance, estimated muscle recovery, and a timeline of
/// today's meals, workouts and weigh-ins.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @AppStorage(SettingsKey.calorieGoal) private var calorieGoal = 2000.0

    @Query(sort: \WorkoutPlan.createdAt) private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutLog.startDate, order: .reverse) private var logs: [WorkoutLog]
    @Query private var todaysFood: [FoodEntry]
    @Query private var todaysWeights: [WeightEntry]

    @State private var isAddingFood = false
    @State private var isLoggingWeight = false

    init() {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _todaysFood = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end }, sort: \FoodEntry.date)
        _todaysWeights = Query(filter: #Predicate<WeightEntry> { $0.date >= start && $0.date < end }, sort: \WeightEntry.date)
    }

    // MARK: Derived data

    private var todaysLogs: [WorkoutLog] {
        logs.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    /// Workouts scheduled for today that haven't been finished yet.
    private var plannedToday: [Workout] {
        plans.flatMap(\.sortedWorkouts).filter { workout in
            workout.weekdays.contains(Weekday.today)
                && !todaysLogs.contains { $0.workout === workout && $0.isFinished }
        }
    }

    private var hasActiveWorkout: Bool {
        logs.contains { !$0.isFinished }
    }

    private var caloriesEaten: Double {
        todaysFood.reduce(0) { $0 + $1.calories }
    }

    private var subtitle: String {
        var parts: [String] = []
        let done = todaysLogs.filter(\.isFinished)
        if let workout = plannedToday.first {
            parts.append("\(workout.name) planned")
        } else if let log = done.first {
            parts.append("\(log.workoutName) done")
        } else {
            parts.append("Rest day")
        }
        parts.append("\(caloriesEaten.formatted(.number.precision(.fractionLength(0)))) of \(calorieGoal.formatted(.number.precision(.fractionLength(0)))) kcal")
        return parts.joined(separator: " · ")
    }

    private var recovery: [Recovery.Status] {
        let sessions = logs.filter(\.isFinished).map { log in
            Recovery.Session(
                date: log.endDate ?? log.startDate,
                exerciseNames: log.exercises
                    .filter { exercise in exercise.sets.contains { $0.isCompleted && !$0.isWarmup } }
                    .map(\.name)
            )
        }
        return Recovery.statuses(for: sessions)
    }

    private var timeline: (entries: [TimelineEntry], logs: [String: WorkoutLog], workouts: [String: Workout]) {
        var items = DayTimeline.mealItems(from: todaysFood.map { food in
            DayTimeline.FoodInput(name: food.name, meal: food.meal.title, date: food.date, calories: food.calories, protein: food.protein)
        })
        var logsByID: [String: WorkoutLog] = [:]
        var workoutsByID: [String: Workout] = [:]

        for log in todaysLogs {
            let id = "log-\(log.persistentModelID.hashValue)"
            logsByID[id] = log
            let detail = log.isFinished
                ? "\(DayTimeline.durationText(log.duration)) · \(log.volume.formatted(.number.precision(.fractionLength(0)))) \(weightUnit)"
                : "In progress"
            items.append(TimelineItem(
                id: id, kind: log.isFinished ? .workout : .inProgress,
                start: log.startDate, end: log.endDate,
                title: log.workoutName, detail: detail
            ))
        }
        for entry in todaysWeights {
            items.append(TimelineItem(
                id: "weight-\(entry.persistentModelID.hashValue)", kind: .weighIn,
                start: entry.date, end: nil,
                title: "Weigh-in", detail: "\(entry.weight.shortFormatted) \(weightUnit)"
            ))
        }
        for workout in plannedToday {
            let id = "planned-\(workout.persistentModelID.hashValue)"
            workoutsByID[id] = workout
            items.append(TimelineItem(
                id: id, kind: .planned, start: nil, end: nil,
                title: workout.name,
                detail: "Planned · \(workout.exercises.count) \(workout.exercises.count == 1 ? "exercise" : "exercises")"
            ))
        }
        return (DayTimeline.entries(for: items), logsByID, workoutsByID)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Date.now, format: .dateTime.weekday(.wide))
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.horizontal, 4)

                    WeekStrip(plans: plans, logs: logs)
                        .appCard()
                    RecoveryCard(statuses: recovery)
                        .appCard()
                    TimelineCard(
                        timeline: timeline,
                        onStartPlanned: start
                    )
                    .appCard()
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background { AppBackground().ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add", systemImage: "plus") {
                        Button("Log Food", systemImage: "fork.knife") {
                            isAddingFood = true
                        }
                        Button("Log Weight", systemImage: "scalemass") {
                            isLoggingWeight = true
                        }
                        if let workout = plannedToday.first {
                            Button("Start \(workout.name)", systemImage: "play.fill") {
                                start(workout)
                            }
                            .disabled(hasActiveWorkout || workout.exercises.isEmpty)
                        }
                    }
                }
            }
            .navigationDestination(for: WorkoutLog.self) { log in
                LogDetailView(log: log)
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseEditorView(exercise: exercise)
            }
            .navigationDestination(for: ExerciseRoute.self) { route in
                ExerciseProgressView(name: route.name)
            }
            .sheet(isPresented: $isAddingFood) {
                FoodEntryForm(entry: nil, day: .now)
            }
            .sheet(isPresented: $isLoggingWeight) {
                AddWeightView(initialWeight: latestWeight)
            }
        }
    }

    private var latestWeight: Double {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? modelContext.fetch(descriptor).first?.weight) ?? 0
    }

    private func start(_ workout: Workout) {
        guard !hasActiveWorkout, !workout.exercises.isEmpty else { return }
        Task {
            await RestTimer.requestNotificationPermission()
        }
        // ContentView presents the live workout as soon as the in-progress log appears.
        WorkoutSession.start(workout, in: modelContext)
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let plans: [WorkoutPlan]
    let logs: [WorkoutLog]

    private struct Day: Identifiable {
        let date: Date
        let progress: Double
        let isToday: Bool
        var id: Date { date }
    }

    /// For each day: finished workouts over scheduled ones (or full if trained on an unscheduled day).
    private var days: [Day] {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? calendar.startOfDay(for: .now)
        let workouts = plans.flatMap(\.workouts)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let weekday = calendar.component(.weekday, from: date)
            let planned = workouts.filter { $0.weekdays.contains(weekday) }.count
            let done = logs.filter { $0.isFinished && calendar.isDate($0.startDate, inSameDayAs: date) }.count
            let progress: Double = planned > 0 ? min(Double(done) / Double(planned), 1) : (done > 0 ? 1 : 0)
            return Day(date: date, progress: progress, isToday: calendar.isDateInToday(date))
        }
    }

    var body: some View {
        HStack {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(.caption.weight(day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Theme.ink : Theme.secondary)
                    ProgressRing(progress: day.progress)
                        .frame(width: 30, height: 30)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                .accessibilityValue(day.progress >= 1 ? "Trained" : (day.progress > 0 ? "Partly done" : "No workout"))
            }
        }
    }
}

// MARK: - Recovery

private struct RecoveryCard: View {
    let statuses: [Recovery.Status]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recovery")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(Recovery.summary(for: statuses))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }

            if statuses.isEmpty {
                Text("Finish a workout to see how recovered each muscle group is.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            } else {
                ForEach(Array(statuses.enumerated()), id: \.element.id) { index, status in
                    if index > 0 {
                        Divider().opacity(0.5)
                    }
                    RecoveryRow(status: status)
                }
                Text("Estimated from time since each muscle was last trained.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}

private struct RecoveryRow: View {
    let status: Recovery.Status

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(status.muscle.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Text(Recovery.lastTrainedText(status.lastTrained))
                    .font(.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            Capsule()
                .fill(Theme.track)
                .frame(width: 110, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(status.isReady ? Theme.ready : Color.accentColor)
                        .frame(width: 110 * status.progress, height: 4)
                }
            Text(Recovery.remainingText(for: status))
                .font(.footnote.weight(status.isReady ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(status.isReady ? Theme.ink : Theme.secondary)
                .frame(width: 58, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.muscle.rawValue)
        .accessibilityValue("\(Recovery.remainingText(for: status)), last trained \(Recovery.lastTrainedText(status.lastTrained))")
    }
}

// MARK: - Timeline

private struct TimelineCard: View {
    let timeline: (entries: [TimelineEntry], logs: [String: WorkoutLog], workouts: [String: Workout])
    let onStartPlanned: (Workout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 10)

            if timeline.entries.isEmpty {
                Text("Nothing logged yet. Use + to add a meal or weigh-in.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary)
            }

            ForEach(timeline.entries) { entry in
                switch entry {
                case .item(let item):
                    row(for: item)
                case .gap(_, let text):
                    GapChip(text: text)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: TimelineItem) -> some View {
        if let log = timeline.logs[item.id], log.isFinished {
            NavigationLink(value: log) {
                TimelineRow(item: item)
            }
            .buttonStyle(.plain)
        } else if let workout = timeline.workouts[item.id] {
            NavigationLink(value: workout) {
                TimelineRow(item: item)
            }
            .buttonStyle(.plain)
        } else {
            TimelineRow(item: item)
        }
    }
}

private struct TimelineRow: View {
    let item: TimelineItem

    private var dotColor: Color {
        switch item.kind {
        case .workout, .inProgress, .planned: .accentColor
        case .meal, .weighIn: Theme.secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let start = item.start {
                    Text(start, format: .dateTime.hour().minute())
                } else {
                    Text("—")
                }
            }
            .font(.footnote.weight(.medium).monospacedDigit())
            .foregroundStyle(Theme.secondary)
            .frame(width: 48, alignment: .trailing)

            VStack(spacing: 0) {
                if item.kind == .planned {
                    Circle().stroke(dotColor, lineWidth: 1.5).frame(width: 9, height: 9).padding(.top, 4)
                } else {
                    Circle().fill(dotColor).frame(width: 9, height: 9).padding(.top, 4)
                        .accentGlow(item.kind == .meal || item.kind == .weighIn ? .clear : .accentColor)
                }
                if item.kind == .workout || item.kind == .inProgress {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(dotColor.opacity(0.3))
                        .frame(width: 4, height: 28)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
            if item.kind == .workout || item.kind == .planned {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondary.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}

private struct GapChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Spacer().frame(width: 48)
            Rectangle()
                .fill(Theme.track)
                .frame(width: 1.5, height: 24)
                .frame(width: 10)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.track, in: .capsule)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    TodayView()
        .environment(RestTimer())
        .modelContainer(for: [WorkoutPlan.self, WorkoutLog.self, FoodEntry.self, WeightEntry.self], inMemory: true)
}
