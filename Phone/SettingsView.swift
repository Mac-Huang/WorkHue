import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exportFile: ExportFile?
    @State private var importing = false
    @State private var replaceExisting = false
    @State private var importedCount: Int?
    @State private var exportError: String?
    private let themes = ThemePalette.hexes

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(TrackingFocus.allCases) { focus in
                        Button {
                            var settings = store.settings
                            settings.focus = focus
                            store.updateSettings(settings)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: focus.systemImage)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(store.settings.focus == focus ? store.settings.tint : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(store.settings.focus == focus ? store.settings.tint.opacity(0.16) : Color.primary.opacity(0.06), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(focus.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                    Text(focusSubtitle(focus)).font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if store.settings.focus == focus { Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(store.settings.tint) }
                            }
                            .frame(height: 84)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("focus-\(focus.rawValue)")
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    }
                } header: { Text("Your Focus") }
                Section {
                    HStack(spacing: 20) {
                        ForEach(themes, id: \.self) { hex in
                            Button {
                                var settings = store.settings
                                settings.themeHex = hex
                                store.updateSettings(settings)
                            } label: {
                                Circle().fill(ThemePalette.color(for: hex).opacity(ThemePalette.canonicalHex(store.settings.themeHex) == hex ? 1 : 0.5))
                                    .frame(width: 36, height: 36)
                                    .scaleEffect(ThemePalette.canonicalHex(store.settings.themeHex) == hex ? 1.12 : 0.92)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(themeName(hex))
                            .accessibilityAddTraits(ThemePalette.canonicalHex(store.settings.themeHex) == hex ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                } header: { Text("Accent Color") }
                Section {
                        VStack(spacing: 11) {
                            LabeledContent(store.settings.focus == .momentum ? "Weekly Goal" : (store.settings.focus == .balance ? "Weekly Limit" : "Weekly Target"), value: hourValue(store.settings.weeklyGoalHours) + "h / week")
                            Slider(value: settingBinding(\.weeklyGoalHours), in: TrackingSettings.weeklyHoursRange, step: 0.5)
                                .accessibilityLabel("Weekly Goal").accessibilityIdentifier("weeklyGoalSlider")
                        }
                        .frame(height: 82)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                        VStack(spacing: 11) {
                            LabeledContent(store.settings.focus == .momentum ? "Daily Goal" : (store.settings.focus == .balance ? "Daily Limit" : "Daily Target"), value: hourValue(store.settings.dailyLimitHours) + "h / day")
                            Slider(value: settingBinding(\.dailyLimitHours), in: TrackingSettings.dailyHoursRange, step: 0.5)
                                .accessibilityLabel("Daily Goal").accessibilityIdentifier("dailyGoalSlider")
                        }
                        .frame(height: 82)
                        .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    } header: { Text(store.settings.focus == .momentum ? "Your Goals" : (store.settings.focus == .balance ? "Your Limits" : "Your Targets")) }
                Section {
                    NavigationLink { WorkloadsSettingsView() } label: {
                        Label("Workload Colors", systemImage: "circle.grid.2x2.fill")
                    }
                    .accessibilityIdentifier("workloadsSettings")
                } header: { Text("Workloads") } footer: {
                    Text("Define a color for each kind of work. Choose one each time you punch in.")
                }
                Section {
                    Button {
                        do { exportFile = ExportFile(url: try store.exportCSV()) }
                        catch { exportError = error.localizedDescription }
                    } label: { Label("Export CSV", systemImage: "square.and.arrow.up").fontWeight(.semibold) }
                    .accessibilityIdentifier("exportCSV")
                } header: { Text("Export") }
                Section {
                    Toggle("Replace existing sessions", isOn: $replaceExisting)
                        .accessibilityIdentifier("replaceExistingToggle")
                    Button { importing = true } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down").fontWeight(.semibold)
                    }
                    .accessibilityIdentifier("importCSV")
                } header: { Text("Import") }
                Section {
                    NavigationLink { DebugInfoView() } label: { Text("Debug Info").foregroundStyle(.secondary) }
                        .accessibilityIdentifier("debugInfo")
                        .listRowBackground(Color.clear)
                } footer: {
                    Text("© Johann Wahlmueller. Made in Hong Kong.")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 22)
                }
            }
            .textCase(nil)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("settingsDone") } }
            .sheet(item: $exportFile) { file in ActivitySheet(items: [file.url]) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    importedCount = try store.importCSV(from: url, replaceExisting: replaceExisting)
                } catch { exportError = error.localizedDescription }
            }
            .alert("CSV", isPresented: Binding(get: { exportError != nil || importedCount != nil }, set: { if !$0 { exportError = nil; importedCount = nil } })) {
                Button("OK") { exportError = nil; importedCount = nil }
            } message: { Text(exportError ?? "Imported \(importedCount ?? 0) sessions.") }
        }
    }
    private func focusSubtitle(_ focus: TrackingFocus) -> String {
        switch focus {
        case .balance: return "Protect your personal time"
        case .momentum: return "Achieve more, track progress"
        case .observe: return "Awareness without expectations"
        }
    }
    private func hourValue(_ value: Double) -> String { String(format: "%.1f", value) }

    private func settingBinding<Value>(_ key: WritableKeyPath<TrackingSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: key] }, set: { value in var settings = store.settings; settings[keyPath: key] = value; store.updateSettings(settings) })
    }
    private func themeName(_ hex: String) -> String {
        ["34C759": "Green", "0099FF": "Blue", "30B0A8": "Teal", "5856D6": "Purple", "FF2D55": "Pink", "FF9500": "Orange"][hex] ?? hex
    }
}

struct WorkloadsSettingsView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var editing: WorkloadEditItem?
    @State private var archive: Workload?
    var body: some View {
        List {
            Section {
                ForEach(store.workloads) { workload in
                    Button { editing = WorkloadEditItem(workload: workload) } label: {
                        HStack {
                            Circle().fill(workload.color.gradient)
                                .overlay {
                                    if WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: colorScheme == .dark) {
                                        Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                    }
                                }
                                .frame(width: 28, height: 28)
                            Text(workload.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 4)
                    }
                    .swipeActions { if store.workloads.count > 1 { Button("Archive", role: .destructive) { archive = workload } } }
                    .accessibilityIdentifier("workloadRow-\(workload.name)")
                }
            } footer: {
                Text("Edits apply to new sessions. Existing sessions keep their recorded name and color. Archived workloads remain in your history.")
            }
        }
        .navigationTitle("Workload Colors")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = WorkloadEditItem(workload: nil) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Workload")
                    .accessibilityIdentifier("addWorkload")
            }
        }
        .sheet(item: $editing) { item in WorkloadEditorView(workload: item.workload) }
        .confirmationDialog("Archive this workload?", isPresented: Binding(get: { archive != nil }, set: { if !$0 { archive = nil } }), titleVisibility: .visible) {
            Button("Archive", role: .destructive) { if let archive { store.archiveWorkload(archive) }; archive = nil }
        } message: { Text("Existing sessions keep their color and name.") }
    }
}

private struct WorkloadEditItem: Identifiable { let id = UUID(); let workload: Workload? }

struct WorkloadEditorView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let original: Workload?
    @State private var name: String
    @State private var color: Color
    @State private var hex: String
    @State private var validation: String?
    private let presets = ["43D10D", "2699F5", "7955EB", "F39538", "ED68B6", "EA4545", "22B6A9", "AD794E"]

    init(workload: Workload?) {
        original = workload
        _name = State(initialValue: workload?.name ?? "")
        _color = State(initialValue: Color(hex: workload?.colorHex ?? "2699F5"))
        _hex = State(initialValue: workload?.colorHex ?? "2699F5")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Workload name", text: $name).textInputAutocapitalization(.words)
                        .accessibilityIdentifier("workloadNameField")
                }
                Section("Color") {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { value in
                            Button { hex = value; color = Color(hex: value) } label: {
                                Circle().fill(Color(hex: value).gradient).aspectRatio(1, contentMode: .fit)
                                    .overlay { if hex == value { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(value)")
                            .accessibilityIdentifier("workloadColor-\(value)")
                        }
                    }.padding(.vertical, 6)
                    ColorPicker("Custom Color", selection: $color, supportsOpacity: false)
                        .accessibilityIdentifier("workloadCustomColor")
                        .onChange(of: color) { _, value in hex = value.hexValue }
                }
                Section("Preview") {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Label("Punch In", systemImage: "play.fill").font(.headline)
                            Text(name.isEmpty ? "Workload" : name).font(.caption)
                        }
                        .foregroundStyle(WorkloadColorStyle.phoneNeedsDarkInk(hex) ? Color.black : .white)
                        .padding(.horizontal, 30).padding(.vertical, 15)
                        .background(color.gradient, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            if WorkloadColorStyle.blendsIntoSurface(hex, onDarkSurface: colorScheme == .dark) {
                                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                            }
                        }
                        .accessibilityIdentifier("workloadPreview")
                        Spacer()
                    }.padding(.vertical, 10)
                }
                if let validation { Text(validation).foregroundStyle(.red) }
            }
            .navigationTitle(original == nil ? "Add Workload" : "Edit Workload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { validation = "Enter a workload name."; return }
                        guard trimmed.count <= 40 else { validation = "Use 40 characters or fewer."; return }
                        var workload = original ?? Workload(name: trimmed, colorHex: hex)
                        workload.name = trimmed
                        workload.colorHex = hex
                        workload.modifiedAt = Date()
                        store.saveWorkload(workload)
                        dismiss()
                    }.bold().accessibilityIdentifier("saveWorkload")
                }
            }
        }
    }
}

private extension Color {
    var hexValue: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

private struct ExportFile: Identifiable { let id = UUID(); let url: URL }

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
