import SwiftUI

struct DayDetailView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var editor: SessionEditorItem?
    @State private var confirmDelete = false
    private var calendar: Calendar { .current }
    init(initialDate: Date) { _date = State(initialValue: initialDate) }
    private var daySessions: [WorkSession] { TimeMath.sessions(on: date, from: store.sessions) }
    private var total: TimeInterval { TimeMath.total(sessions: store.sessions, in: calendar.dateInterval(of: .day, for: date)!) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Total Time", systemImage: "clock.fill").labelStyle(DetailLabelStyle(tint: store.settings.tint))
                        Spacer()
                        Text(TimeFormat.duration(total)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Sessions", systemImage: "list.bullet").labelStyle(DetailLabelStyle(tint: store.settings.tint))
                        Spacer()
                        Text(String(daySessions.count)).foregroundStyle(.secondary)
                    }
                }
                Section("Timeline") {
                    if daySessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 44))
                                .foregroundStyle(.gray)
                            Text("No Sessions").font(.system(size: 22, weight: .bold))
                            Text("No time logged for this day.")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 184)
                        .listRowInsets(EdgeInsets())
                    } else {
                        DayTimeline(sessions: daySessions, date: date, tint: store.settings.tint)
                            .frame(height: 68)
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }
                }
                .textCase(nil)
                Section("Sessions") {
                    ForEach(daySessions) { session in
                        Button { editor = SessionEditorItem(session: session, date: date) } label: {
                            SessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .swipeActions { Button("Delete", role: .destructive) { store.deleteSession(session) } }
                        .accessibilityIdentifier("sessionRow")
                    }
                    Button { editor = SessionEditorItem(session: nil, date: date) } label: {
                        HStack {
                            Text("Add Session Manually").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("addManualSession")
                    .buttonStyle(.plain)
                }
                .textCase(nil)
                Section {
                    Button("Delete All Sessions", role: .destructive) { confirmDelete = true }
                        .foregroundStyle(Color.red.opacity(daySessions.isEmpty ? 0.35 : 1))
                        .frame(maxWidth: .infinity)
                        .disabled(daySessions.isEmpty)
                        .accessibilityIdentifier("deleteAllSessions")
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 12) {
                        Button { changeDay(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Previous day")
                        Text(date.formatted(.dateTime.month(.abbreviated).day().year())).font(.headline).foregroundStyle(.primary)
                        Button { changeDay(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel("Next day")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(item: $editor) { item in SessionEditorView(session: item.session, date: item.date) }
            .confirmationDialog("Delete all sessions for this day?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete All Sessions", role: .destructive) { store.deleteSessions(on: date) }
            } message: { Text("This also removes these sessions from your synced devices.") }
        }
        .presentationDragIndicator(.visible)
    }
    private func changeDay(_ amount: Int) { if let next = calendar.date(byAdding: .day, value: amount, to: date) { date = next } }
}

private struct SessionEditorItem: Identifiable, Hashable {
    let id = UUID()
    let session: WorkSession?
    let date: Date
    static func == (lhs: SessionEditorItem, rhs: SessionEditorItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SessionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: WorkSession
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: session.colorHex))
                .overlay {
                    if WorkloadColorStyle.blendsIntoSurface(session.colorHex, onDarkSurface: colorScheme == .dark) {
                        RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                    }
                }
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(session.start.formatted(date: .omitted, time: .shortened))
                    Text("–").foregroundStyle(.tertiary)
                    Text(session.end.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Now")
                }
                .font(.system(size: 17, design: .monospaced))
                HStack(spacing: 7) {
                    Text(session.workloadName)
                        .foregroundStyle(WorkloadColorStyle.textNeedsPrimaryInk(session.colorHex, onDarkSurface: colorScheme == .dark) ? Color.primary : Color(hex: session.colorHex))
                    Label(SessionSourceDisplay.title(session.source), systemImage: SessionSourceDisplay.symbol(session.source))
                        .foregroundStyle(.tertiary)
                }.font(.system(size: 11))
            }
            Spacer(minLength: 2)
            Text(TimeFormat.duration(session.duration())).font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 48)
    }
}

private enum SessionSourceDisplay {
    static func title(_ source: String) -> String {
        switch source.lowercased() {
        case "watch", "apple watch", "applewatch": return "Watch"
        case "iphone": return "iPhone"
        case "siri": return "Siri"
        default: return source
        }
    }

    static func symbol(_ source: String) -> String {
        switch source.lowercased() {
        case "watch", "apple watch", "applewatch": return "applewatch"
        case "siri": return "waveform"
        default: return "iphone"
        }
    }
}

struct DetailLabelStyle: LabelStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 16) { configuration.icon.foregroundStyle(tint).frame(width: 24); configuration.title }
    }
}

struct DayTimeline: View {
    @Environment(\.colorScheme) private var colorScheme
    let sessions: [WorkSession]
    let date: Date
    let tint: Color
    var body: some View {
        let interval = Calendar.current.dateInterval(of: .day, for: date)!
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<9) { index in
                    Text(String(format: "%02d", (index * 3) % 24))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if index != 8 { Spacer(minLength: 0) }
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04))
                    ForEach(sessions) { session in
                        let start = max(interval.start, session.start)
                        let end = min(interval.end, session.end ?? Date())
                        let offset = max(0, start.timeIntervalSince(interval.start) / interval.duration)
                        let width = max(0, end.timeIntervalSince(start) / interval.duration)
                        if width > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: session.colorHex).opacity(0.55))
                                .overlay {
                                    if WorkloadColorStyle.blendsIntoSurface(session.colorHex, onDarkSurface: colorScheme == .dark) {
                                        RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                                    }
                                }
                                .frame(width: max(3, geometry.size.width * width), height: 26)
                                .offset(x: geometry.size.width * offset)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timeline, \(sessions.count) sessions")
    }
}

struct SessionEditorView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let existing: WorkSession?
    @State private var start: Date
    @State private var end: Date
    @State private var hasEnded: Bool
    @State private var workloadID: UUID?
    @State private var error: String?
    @State private var confirmDelete = false

    init(session: WorkSession?, date: Date) {
        existing = session
        let calendar = Calendar.current
        let now = Date()
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        let selectedTime = calendar.isDateInToday(date) ? now :
            calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: date) ?? date
        let initial = session?.start ?? selectedTime
        _start = State(initialValue: initial)
        _end = State(initialValue: session?.end ?? (session == nil ? initial : now))
        _hasEnded = State(initialValue: session == nil || session?.end != nil)
        _workloadID = State(initialValue: session?.workloadID)
    }

    private var availableWorkloads: [Workload] {
        guard let existing else { return store.workloads }
        let recorded = Workload(id: existing.workloadID, name: existing.workloadName, colorHex: existing.colorHex)
        return [recorded] + store.workloads.filter { $0.id != recorded.id }
    }

    private var duration: TimeInterval { max(0, (hasEnded ? end : Date()).timeIntervalSince(start)) }
    private var source: String { existing?.source ?? "iPhone" }
    private var hasChanges: Bool {
        guard let existing else { return true }
        return start != existing.start || (hasEnded ? end : nil) != existing.end || workloadID != existing.workloadID
    }
    private var saveDisabled: Bool { workloadID == nil || (hasEnded && end <= start) || !hasChanges }

    var body: some View {
        Form {
            Section("Start Time") {
                DatePicker("Started", selection: $start, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .accessibilityLabel("Started")
                    .accessibilityIdentifier("sessionStart")
            }
            .textCase(nil)
            Section("End Time") {
                Toggle("Session Ended", isOn: $hasEnded)
                    .accessibilityIdentifier("sessionEndedToggle")
                if hasEnded {
                    DatePicker("Ended", selection: $end, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .accessibilityLabel("Ended")
                        .accessibilityIdentifier("sessionEnd")
                }
            }
            .textCase(nil)
            Section {
                LabeledContent("Duration") { Text(TimeFormat.duration(duration)).foregroundStyle(.secondary).monospacedDigit() }
                LabeledContent("Source") { Text(source).foregroundStyle(.secondary) }
            }
            if existing != nil {
                Section {
                    Button("Delete Session", role: .destructive) { confirmDelete = true }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("deleteSession")
                }
            }
            Section("Workload") {
                ForEach(availableWorkloads) { workload in
                    Button { workloadID = workload.id } label: {
                        HStack {
                            Circle().fill(workload.color)
                                .overlay {
                                    if WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: colorScheme == .dark) {
                                        Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                                    }
                                }
                                .frame(width: 20, height: 20)
                            Text(workload.name).foregroundStyle(.primary)
                            Spacer()
                            if workloadID == workload.id { Image(systemName: "checkmark").fontWeight(.semibold) }
                        }
                    }
                    .accessibilityIdentifier("editorWorkload-\(workload.name)")
                }
            }
            .textCase(nil)
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(existing == nil ? "New Session" : "Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .bold()
                    .disabled(saveDisabled)
                    .accessibilityIdentifier("saveSession")
            }
        }
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Session", role: .destructive) {
                guard let existing else { return }
                store.deleteSession(existing)
                if let message = store.errorMessage { error = message }
                else { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session from this device and your synced devices.")
        }
        .onAppear { if workloadID == nil { workloadID = availableWorkloads.first?.id } }
    }

    private func save() {
        guard let workload = availableWorkloads.first(where: { $0.id == workloadID }) else { error = "Select a workload."; return }
        var session = existing ?? WorkSession(start: start, workloadID: workload.id, workloadName: workload.name, colorHex: workload.colorHex, source: "iPhone")
        session.start = start
        session.end = hasEnded ? end : nil
        if existing == nil || existing?.workloadID != workload.id {
            session.workloadID = workload.id
            session.workloadName = workload.name
            session.colorHex = workload.colorHex
        }
        do { try store.saveSession(session); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct WeekDetailView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var offset = 0

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = store.settings.weekStartsMonday ? 2 : 1
        return calendar
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let week = week(containing: context.date)
                let total = TimeMath.total(sessions: store.sessions, in: week, now: context.date)
                let days = days(in: week, now: context.date)
                ScrollView {
                    VStack(spacing: 20) {
                        weekSummary(total: total)
                        if days.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 54))
                                    .foregroundStyle(Color.gray.opacity(0.4))
                                Text("No Sessions This Week")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Text("Start tracking your work by punching in on the Track tab")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 280)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                            .accessibilityIdentifier("emptyWeekState")
                        } else {
                            ForEach(days) { day in
                                dayCard(day, now: context.date)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 12) {
                            Button { offset -= 1 } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Previous week")
                            Text(weekTitle(week))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .accessibilityIdentifier("weekRangeTitle")
                            Button { offset = min(0, offset + 1) } label: { Image(systemName: "chevron.right") }
                                .disabled(offset >= 0)
                                .accessibilityLabel("Next week")
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }

    private func week(containing now: Date) -> DateInterval {
        let date = calendar.date(byAdding: .weekOfYear, value: offset, to: now) ?? now
        return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let last = week.end.addingTimeInterval(-1)
        let start = week.start.formatted(.dateTime.month(.abbreviated).day())
        if calendar.component(.month, from: week.start) == calendar.component(.month, from: last) {
            return "\(start)-\(calendar.component(.day, from: last))"
        }
        return "\(start) - \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func days(in week: DateInterval, now: Date) -> [WeekDayEntry] {
        (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: week.start),
                  let interval = calendar.dateInterval(of: .day, for: date) else { return nil }
            let sessions = TimeMath.sessions(on: date, from: store.sessions, calendar: calendar, now: now)
            guard !sessions.isEmpty else { return nil }
            return WeekDayEntry(date: date, sessions: sessions, seconds: TimeMath.total(sessions: sessions, in: interval, now: now))
        }
    }

    private func weekSummary(total: TimeInterval) -> some View {
        let goal = store.settings.weeklyGoalHours * 3600
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Week Total").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(TimeFormat.duration(total))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(store.settings.tint)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Goal").font(.system(size: 13))
                    Text(TimeFormat.duration(goal)).font(.system(size: 20, weight: .bold))
                }
                .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                Capsule().fill(Color.primary.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule().fill(store.settings.tint)
                            .frame(width: geometry.size.width * min(1, max(0, total / max(1, goal))))
                    }
            }
            .frame(height: 4)
            Text("\(TimeFormat.duration(max(0, goal - total))) remaining")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityIdentifier("weekSummary")
    }

    private func dayCard(_ day: WeekDayEntry, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.date.formatted(.dateTime.weekday(.wide)))
                        .font(.system(size: 16, weight: .bold))
                    Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormat.duration(day.seconds))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .italic()
                    .foregroundStyle(store.settings.tint)
            }
            ForEach(day.sessions) { session in
                WeekSessionRow(session: session, now: now)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.overviewCard, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct WeekDayEntry: Identifiable {
    let date: Date
    let sessions: [WorkSession]
    let seconds: TimeInterval
    var id: Date { date }
}

private struct WeekSessionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: WorkSession
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(session.start.formatted(date: .omitted, time: .shortened))
                    Text("–").foregroundStyle(.tertiary)
                    Text(session.end.map { $0.formatted(date: .omitted, time: .shortened) } ?? "Now")
                }
                .font(.system(size: 17, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                HStack(spacing: 6) {
                    Circle().fill(session.color)
                        .overlay {
                            if WorkloadColorStyle.blendsIntoSurface(session.colorHex, onDarkSurface: colorScheme == .dark) {
                                Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                            }
                        }
                        .frame(width: 5, height: 5)
                    Text(session.workloadName)
                        .foregroundStyle(WorkloadColorStyle.textNeedsPrimaryInk(session.colorHex, onDarkSurface: colorScheme == .dark) ? Color.primary : session.color)
                    Label(SessionSourceDisplay.title(session.source), systemImage: SessionSourceDisplay.symbol(session.source))
                        .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11))
                .lineLimit(1)
            }
            Spacer(minLength: 2)
            Text(TimeFormat.duration(session.duration(at: now)))
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekSessionRow")
    }
}
