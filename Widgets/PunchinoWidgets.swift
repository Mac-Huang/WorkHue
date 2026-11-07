import SwiftUI
import WidgetKit
import AppIntents

struct PunchinoEntry: TimelineEntry {
    let date: Date
    let snapshot: TrackingSnapshot
    let display: PunchinoWidgetDisplay

    var activeSession: WorkSession? {
        snapshot.sessions.first { $0.end == nil && $0.deletedAt == nil }
    }

    var tint: Color { activeSession.map { Color(hex: $0.colorHex) } ?? snapshot.settings.tint }

    func total(_ component: Calendar.Component) -> TimeInterval {
        var calendar = Calendar.current
        calendar.firstWeekday = snapshot.settings.weekStartsMonday ? 2 : 1
        let interval = calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
        return TimeMath.total(sessions: snapshot.sessions.filter { $0.deletedAt == nil }, in: interval, now: date)
    }
}

enum PunchinoWidgetDisplay: String, AppEnum {
    case status
    case totals

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Display")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .status: "Work Status",
        .totals: "Time Totals"
    ]
}

struct PunchinoWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Punchino"
    static var description = IntentDescription("Show your work status or your time totals.")

    @Parameter(title: "Display", default: .status)
    var display: PunchinoWidgetDisplay
}

struct PunchinoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PunchinoEntry {
        PunchinoEntry(date: .now, snapshot: .empty, display: .status)
    }

    func snapshot(for configuration: PunchinoWidgetConfiguration, in context: Context) async -> PunchinoEntry {
        PunchinoEntry(date: .now, snapshot: readSnapshot(), display: configuration.display)
    }

    func timeline(for configuration: PunchinoWidgetConfiguration, in context: Context) async -> Timeline<PunchinoEntry> {
        let snapshot = readSnapshot()
        let date = Date()
        let entries = (0..<15).map { offset in
            PunchinoEntry(date: date.addingTimeInterval(Double(offset) * 60), snapshot: snapshot, display: configuration.display)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    func recommendations() -> [AppIntentRecommendation<PunchinoWidgetConfiguration>] {
        let status = PunchinoWidgetConfiguration()
        status.display = .status
        let totals = PunchinoWidgetConfiguration()
        totals.display = .totals
        return [
            AppIntentRecommendation(intent: status, description: "Work Status"),
            AppIntentRecommendation(intent: totals, description: "Time Totals")
        ]
    }

    private func readSnapshot() -> TrackingSnapshot {
        (try? SnapshotRepository.live.load()) ?? .empty
    }
}

struct PunchOutIntent: AppIntent {
    static var title: LocalizedStringResource = "Punch Out"
    static var description = IntentDescription("Stop the current work session.")
    static var openAppWhenRun = false
    static var isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = TimeStore(repository: .live, startServices: true)
        store.stop()
        if let message = store.errorMessage {
            throw PunchinoWidgetError.saveFailed(message)
        }
        await store.refresh()
        await store.finishPendingPairedSync()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

private enum PunchinoWidgetError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message): message
        }
    }
}

private struct PunchinoWidgetView: View {
    let entry: PunchinoEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    #if os(watchOS)
    @Environment(\.showsWidgetLabel) private var showsWidgetLabel
    #else
    private var showsWidgetLabel: Bool { false }
    #endif

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inlineView
            case .accessoryCircular:
                if entry.activeSession != nil {
                    Button(intent: PunchOutIntent()) { circularView }
                        .buttonStyle(.plain)
                } else {
                    circularView
                }
            case .accessoryRectangular:
                if entry.activeSession != nil && entry.display == .status {
                    Button(intent: PunchOutIntent()) { rectangularView }
                        .buttonStyle(.plain)
                } else {
                    rectangularView
                }
            default:
                homeScreenView
            }
        }
        .widgetURL(URL(string: entry.activeSession == nil ? "punchino://punch-in" : "punchino://punch-out"))
        .containerBackground(for: .widget) {
            #if os(watchOS)
            if family == .accessoryRectangular {
                LinearGradient(colors: [entry.tint.opacity(0.51), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay {
                        ContainerRelativeShape()
                            .stroke(
                                LinearGradient(stops: [
                                    .init(color: entry.tint, location: 0),
                                    .init(color: entry.tint.opacity(0.2), location: 0.25),
                                    .init(color: entry.tint.opacity(0.1), location: 0.75),
                                    .init(color: .clear, location: 1)
                                ], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 2
                            )
                    }
            } else {
                LinearGradient(colors: [entry.tint.opacity(0.38), .black], startPoint: .leading, endPoint: .trailing)
            }
            #else
            Color(.systemBackground)
            #endif
        }
        .accessibilityElement(children: .contain)
    }

    private var inlineView: some View {
        HStack(spacing: 3) {
            Image(systemName: entry.activeSession == nil ? "circle" : "circle.fill")
            if let active = entry.activeSession {
                Text(active.start, style: .relative)
            } else {
                Text("OUT")
            }
        }
        .accessibilityLabel(entry.activeSession == nil ? "Punched out. Choose a workload to punch in." : "Work session in progress")
    }

    private var circularView: some View {
        #if os(watchOS)
        circularContent
            .widgetLabel {
                if let active = entry.activeSession {
                    Text(active.start, style: .relative)
                } else {
                    Text("OUT")
                }
            }
        #else
        circularContent
        #endif
    }

    private var circularContent: some View {
        ZStack {
            if showsWidgetLabel {
                statusSymbol(color: entry.activeSession == nil ? .primary : entry.tint)
                    .font(.system(size: 16))
            } else {
                AccessoryWidgetBackground()
                if let active = entry.activeSession {
                    VStack(spacing: 0) {
                        statusSymbol(color: entry.tint)
                            .font(.system(size: 12))
                        Text(active.start, style: .relative)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Circle().stroke(lineWidth: 2).padding(8)
                    Text("OUT").font(.system(size: 10, weight: .medium))
                }
            }
        }
        .accessibilityLabel(entry.activeSession == nil ? "Punched out" : "Work session in progress")
    }

    private var rectangularView: some View {
        #if os(watchOS)
        let iconSize: CGFloat = 58
        let elapsedSize: CGFloat = 45
        let statusSize: CGFloat = 45
        let statusSpacing: CGFloat = entry.activeSession == nil ? 6.5 : 0
        #else
        let iconSize: CGFloat = 40
        let elapsedSize: CGFloat = 29
        let statusSize: CGFloat = 38
        let statusSpacing: CGFloat = 12
        #endif
        return Group {
            if entry.display == .totals {
                VStack(alignment: .leading, spacing: 2) {
                    compactTotal("Today", component: .day)
                    compactTotal("Week", component: .weekOfYear)
                    compactTotal("Month", component: .month)
                }
            } else {
                HStack(spacing: statusSpacing) {
                    statusSymbol(color: entry.activeSession == nil ? .white : entry.tint)
                        .font(.system(size: iconSize, weight: .regular))
                        .widgetAccentable()
                    if let active = entry.activeSession {
                        Text(active.start, style: .relative)
                            .font(.system(size: elapsedSize, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            #if os(watchOS)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                            #endif
                    } else {
                        Text("OUT")
                            .font(.system(size: statusSize, weight: .regular))
                            .minimumScaleFactor(0.6)
                    }
                    #if os(watchOS)
                    if entry.activeSession == nil { Spacer(minLength: 0) }
                    #else
                    Spacer(minLength: 0)
                    #endif
                }
            }
        }
    }

    private var widgetHasDarkSurface: Bool {
        #if os(watchOS)
        true
        #else
        colorScheme == .dark
        #endif
    }

    private var widgetContrastColor: Color { widgetHasDarkSurface ? .white : .black }

    private var activeSymbolNeedsOutline: Bool {
        guard let active = entry.activeSession else { return false }
        return WorkloadColorStyle.blendsIntoSurface(active.colorHex, onDarkSurface: widgetHasDarkSurface)
    }

    private var activeTextNeedsPrimaryInk: Bool {
        guard let active = entry.activeSession else { return false }
        return WorkloadColorStyle.textNeedsPrimaryInk(active.colorHex, onDarkSurface: widgetHasDarkSurface)
    }

    private func statusSymbol(color: Color) -> some View {
        Image(systemName: entry.activeSession == nil ? "circle" : "circle.fill")
            .foregroundStyle(color)
            .overlay {
                if activeSymbolNeedsOutline {
                    GeometryReader { geometry in
                        Circle()
                            .strokeBorder(widgetContrastColor.opacity(0.4), lineWidth: 1)
                            .padding(min(geometry.size.width, geometry.size.height) * 0.025)
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private func compactTotal(_ title: String, component: Calendar.Component) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text(TimeFormat.duration(entry.total(component)))
                .monospacedDigit()
                .foregroundStyle(activeTextNeedsPrimaryInk ? .primary : entry.tint)
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var isMedium: Bool {
        #if os(watchOS)
        false
        #else
        family == .systemMedium
        #endif
    }

    private var homeScreenView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Punchino").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                statusSymbol(color: entry.tint)
            }
            if entry.display == .totals {
                VStack(spacing: 7) {
                    compactTotal("Today", component: .day)
                    compactTotal("This Week", component: .weekOfYear)
                    compactTotal("This Month", component: .month)
                }
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 13) {
                    statusCircle
                        .frame(width: isMedium ? 68 : 46, height: isMedium ? 68 : 46)
                    if isMedium {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.activeSession?.workloadName ?? "Ready to work?")
                                .font(.headline)
                                .lineLimit(1)
                            if let active = entry.activeSession {
                                Text(active.start, style: .timer)
                                    .font(.system(.title2, design: .monospaced))
                            } else {
                                Text("Choose a workload to begin")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let active = entry.activeSession {
                        Text(active.start, style: .timer)
                            .font(.system(.headline, design: .monospaced))
                            .minimumScaleFactor(0.6)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today").font(.caption2).foregroundStyle(.secondary)
                        Text(TimeFormat.duration(entry.total(.day)))
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    }
                    Spacer(minLength: 3)
                    if entry.activeSession != nil {
                        Button(intent: PunchOutIntent()) {
                            Text("Punch Out").font(.caption.weight(.semibold))
                        }
                        .tint(entry.tint)
                        .buttonStyle(.bordered)
                        .overlay {
                            if activeSymbolNeedsOutline {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(widgetContrastColor.opacity(0.4), lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                        }
                        .foregroundStyle(activeTextNeedsPrimaryInk ? .primary : entry.tint)
                    } else {
                        Link(destination: URL(string: "punchino://punch-in")!) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .padding(9)
                                .background(entry.tint.opacity(0.15), in: Circle())
                        }
                        .foregroundStyle(entry.tint)
                        .accessibilityLabel("Choose workload and punch in")
                    }
                }
            }
        }
    }

    private var statusCircle: some View {
        ZStack {
            Circle().fill(entry.activeSession == nil ? Color.clear : entry.tint)
                .overlay {
                    if activeSymbolNeedsOutline {
                        Circle().strokeBorder(widgetContrastColor.opacity(0.4), lineWidth: 1)
                    }
                }
            Circle().stroke(entry.activeSession == nil ? Color.secondary.opacity(0.5) : entry.tint.opacity(0.2), lineWidth: 3)
                .padding(-3)
            Text(entry.activeSession == nil ? "OUT" : "IN")
                .font(.system(size: isMedium ? 22 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(entry.activeSession == nil ? Color.secondary : (WorkloadColorStyle.watchNeedsLightInk(entry.activeSession!.colorHex) ? .white : .black))
        }
        .widgetAccentable()
    }
}

struct PunchinoStatusWidget: Widget {
    let kind = "PunchinoStatusWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: PunchinoWidgetConfiguration.self, provider: PunchinoProvider()) { entry in
            PunchinoWidgetView(entry: entry)
        }
        .configurationDisplayName("Punchino")
        .description("See your work status and tracked time. Tap to choose a workload.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        #endif
    }
}

@main
struct PunchinoWidgets: WidgetBundle {
    var body: some Widget {
        PunchinoStatusWidget()
    }
}
