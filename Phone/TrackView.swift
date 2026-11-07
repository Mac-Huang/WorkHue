import SwiftUI

struct TrackView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectingWorkload = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { geometry in
                if selectingWorkload && store.activeSession == nil {
                    ScrollView {
                        VStack(spacing: 24) {
                            punchControl(now: context.date)
                            Text("Choose your workload")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            workloadButtons
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: 24) {
                            ZStack {
                                punchControl(now: context.date)
                            }
                            .frame(width: 220, height: 220)
                            .overlay(alignment: .top) {
                                statusFooter
                                    .frame(width: max(220, geometry.size.width - 40))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .offset(y: 244)
                                    .allowsHitTesting(false)
                            }
                            // Reserve the idle caption's height in both states.
                            idleCaption.hidden()
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onChange(of: store.activeSession?.id) { _, id in if id != nil { selectingWorkload = false } }
    }

    private func punchControl(now: Date) -> some View {
        Button {
            if store.activeSession != nil {
                store.stop()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectingWorkload.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            PunchCircle(session: store.activeSession, now: now, tint: store.activeSession.map { Color(hex: $0.colorHex) } ?? store.settings.tint)
                .frame(width: 220, height: 220)
        }
        .buttonStyle(PunchButtonStyle())
        .accessibilityLabel(store.activeSession == nil ? "Punch in" : "Punch out")
        .accessibilityValue(store.activeSession.map { phoneTimer($0.duration(at: now)) } ?? "")
        .accessibilityHint(store.activeSession == nil ? "Choose a workload color to start a session." : "Stop the current session.")
        .accessibilityIdentifier("punchButton")
    }

    // Keep the footer outside the control's layout so both states use the same center.
    private var statusFooter: some View {
        Group {
            if let active = store.activeSession {
                VStack(spacing: 14) {
                    Label("Started \(active.start.formatted(date: .omitted, time: .shortened))", systemImage: "clock.fill")
                        .font(.system(size: 16)).foregroundStyle(.secondary)
                    Label {
                        Text(active.workloadName)
                            .foregroundStyle(WorkloadColorStyle.textNeedsPrimaryInk(active.colorHex, onDarkSurface: colorScheme == .dark) ? Color.primary : Color(hex: active.colorHex))
                    } icon: {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color(hex: active.colorHex))
                            .overlay {
                                if WorkloadColorStyle.blendsIntoSurface(active.colorHex, onDarkSurface: colorScheme == .dark) {
                                    Image(systemName: "circle").foregroundStyle(Color.primary.opacity(0.3))
                                }
                            }
                    }
                    .font(.system(size: 13, weight: .medium))
                }
            } else {
                idleCaption
            }
        }
    }

    private var idleCaption: some View {
        Text("Tap to punch in")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.secondary)
    }

    private var workloadButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(store.workloads) { workload in
                Button {
                    store.start(workload: workload)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    selectingWorkload = false
                } label: {
                    VStack(spacing: 4) {
                        Label("Punch In", systemImage: "play.fill").font(.system(size: 15, weight: .semibold))
                        Text(workload.name).font(.system(size: 12)).lineLimit(1)
                    }
                    .foregroundStyle(WorkloadColorStyle.phoneNeedsDarkInk(workload.colorHex) ? Color.black : .white)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(workload.color.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        if WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: colorScheme == .dark) {
                            RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Punch in: \(workload.name)")
                .accessibilityIdentifier("punchWorkload-\(workload.name)")
            }
        }
    }
}

struct PunchCircle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var expanded = false
    @State private var visible = false
    let session: WorkSession?
    let now: Date
    let tint: Color
    private var animates: Bool {
        session != nil && visible && scenePhase == .active && !reduceMotion && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }
    var body: some View {
        ZStack {
            if session == nil {
                Circle().strokeBorder(Color.gray.opacity(0.3), lineWidth: 10)
                Text("OUT")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(uiColor: .systemGray))
            } else {
                Circle().fill(tint.opacity(0.22))
                    .frame(width: 230, height: 230)
                    .scaleEffect(expanded ? 240.0 / 230.0 : 1)
                    .shadow(color: tint.opacity(expanded ? 0.16 : 0.1), radius: expanded ? 8 : 5)
                Circle().fill(tint.opacity(0.28)).frame(width: 220, height: 220)
                Circle().fill(tint.gradient)
                    .overlay {
                        if let session, WorkloadColorStyle.blendsIntoSurface(session.colorHex, onDarkSurface: colorScheme == .dark) {
                            Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                        }
                    }
                    .frame(width: 200, height: 200)
                VStack(spacing: 13) {
                    Text("IN")
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                    if let session {
                        Text(phoneTimer(session.duration(at: now)))
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(session.map { WorkloadColorStyle.phoneNeedsDarkInk($0.colorHex) } == true ? Color.black : .white)
            }
        }
        .animation(animates ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : nil, value: expanded)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onChange(of: animates) { _, value in expanded = value }
    }
}

private func phoneTimer(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    if total < 3600 { return String(format: "%02d:%02d", total / 60, total % 60) }
    return TimeFormat.timer(seconds)
}

struct PunchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WorkloadPickerView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onSelect: (Workload) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.workloads) { workload in
                        Button { onSelect(workload) } label: {
                            HStack {
                                Circle().fill(workload.color.gradient)
                                    .overlay {
                                        if WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: colorScheme == .dark) {
                                            Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                Text(workload.name).foregroundStyle(.primary)
                                Spacer()
                                Text("Punch In").font(.subheadline.weight(.semibold))
                                    .foregroundStyle(WorkloadColorStyle.textNeedsPrimaryInk(workload.colorHex, onDarkSurface: colorScheme == .dark) ? Color.primary : workload.color)
                            }.padding(.vertical, 6)
                        }
                    }
                } footer: { Text("Define your workload names and colors in Settings.") }
            }
            .navigationTitle("Choose Workload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
