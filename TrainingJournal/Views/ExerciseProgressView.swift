import Charts
import SwiftUI
import SwiftData

/// Progress for one exercise over time: a trend chart, personal records, and recent sessions.
struct ExerciseProgressView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case estimated1RM = "Est. 1RM"
        case heaviest = "Heaviest"
        case volume = "Volume"

        var id: String { rawValue }
    }

    private struct Point: Identifiable {
        var date: Date
        var value: Double
        var id: Date { date }
    }

    let name: String

    @AppStorage(SettingsKey.weightUnit) private var weightUnit = "lb"
    @Query(filter: #Predicate<WorkoutLog> { $0.endDate != nil }, sort: \WorkoutLog.startDate, order: .reverse)
    private var logs: [WorkoutLog]

    @State private var metric = Metric.estimated1RM
    @State private var selectedDate: Date?

    /// Newest first.
    private var sessions: [(log: WorkoutLog, exercise: LoggedExercise)] {
        WorkoutSession.history(named: name, in: logs)
    }

    private var points: [Point] {
        sessions.reversed().compactMap { session in
            let performances = session.exercise.performances
            let records = PersonalRecords(performances)
            let value: Double = switch metric {
            case .estimated1RM: records.bestEstimated1RM
            case .heaviest: records.heaviestWeight
            case .volume: performances.filter { !$0.isWarmup }.reduce(0) { $0 + $1.weight * Double($1.reps) }
            }
            return value > 0 ? Point(date: session.log.startDate, value: value) : nil
        }
    }

    /// The point nearest the finger while scrubbing the chart.
    private var selectedPoint: Point? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var allTimeRecords: PersonalRecords {
        PersonalRecords(sessions.flatMap { $0.exercise.performances })
    }

    var body: some View {
        List {
            Section {
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                if points.isEmpty {
                    ContentUnavailableView("No Data Yet", systemImage: "chart.xyaxis.line",
                                           description: Text("Finish a workout with this exercise to see your trend."))
                } else {
                    chart
                    if points.count == 1 {
                        Text("Log this exercise again to see a trend.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Personal Records") {
                HStack {
                    StatTile(title: "Heaviest", value: "\(allTimeRecords.heaviestWeight.shortFormatted) \(weightUnit)", systemImage: "trophy")
                    StatTile(title: "Best e1RM", value: "\(allTimeRecords.bestEstimated1RM.shortFormatted) \(weightUnit)", systemImage: "bolt")
                    StatTile(title: "Sessions", value: "\(sessions.count)", systemImage: "calendar")
                }
            }

            if !sessions.isEmpty {
                Section("Recent Sessions") {
                    ForEach(sessions.prefix(10), id: \.exercise.id) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.log.startDate, format: .dateTime.weekday(.wide).month().day().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            LoggedExerciseRow(exercise: session.exercise, weightUnit: weightUnit)
                        }
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: metric) {
            selectedDate = nil
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.rawValue, point.value)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metric.rawValue, point.value)
                )
                .symbolSize(64)
            }

            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text("\(selectedPoint.value.shortFormatted) \(weightUnit)")
                                .font(.subheadline.bold().monospacedDigit())
                            Text(selectedPoint.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    }
            }
        }
        .foregroundStyle(Color.accentColor)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 220)
        .padding(.top, 24)
        .accessibilityLabel("\(metric.rawValue) over time for \(name)")
    }
}
