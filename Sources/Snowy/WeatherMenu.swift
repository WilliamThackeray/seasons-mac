import AppKit
import SnowCore
import SwiftUI

/// The menu-bar forecast. Same control order as the website: density, wind, then cursor tool.
@MainActor
final class WeatherMenuModel: ObservableObject {
    @Published var controlsEnabled = false
    @Published var snowfall: Snowfall = .steady
    @Published var wind = WindSettings()
    @Published var tool: SnowTool = .glove
    @Published var pauseTitle = "Pause Snow"
    @Published var status = ""
    @Published var updateLabel: String?
    @Published var canInstallUpdate = false

    var setSnowfall: (Snowfall) -> Void = { _ in }
    var setWind: (WindSettings) -> Void = { _ in }
    var setTool: (SnowTool) -> Void = { _ in }
    var togglePause: () -> Void = {}
    var clear: () -> Void = {}
    var openApp: () -> Void = {}
    var support: () -> Void = {}
    var installUpdate: () -> Void = {}
    var quit: () -> Void = {}
    var close: () -> Void = {}
}

struct WeatherMenuView: View {
    @ObservedObject var model: WeatherMenuModel

    private var snowfall: Binding<Snowfall> {
        Binding(get: { model.snowfall }, set: { model.setSnowfall($0) })
    }
    private var tool: Binding<SnowTool> {
        Binding(get: { model.tool }, set: { model.setTool($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Szns (Seasons)")
                    .font(.headline)
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("Density") {
                Picker("Density", selection: snowfall) {
                    ForEach(Snowfall.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.controlsEnabled)
            }

            section("Wind") {
                VStack(spacing: 6) {
                    HStack {
                        Text(model.wind.summary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Make it calm") { model.setWind(WindSettings()) }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .disabled(!model.controlsEnabled || model.wind.speedFraction < 0.01)
                    }
                    WindPadRepresentable(settings: model.wind, onChange: model.setWind, onClose: model.close)
                        .frame(width: 176, height: 176)
                        .disabled(!model.controlsEnabled)
                }
            }

            section("Cursor tool") {
                Picker("Cursor tool", selection: tool) {
                    ForEach(SnowTool.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.controlsEnabled)
            }

            HStack(spacing: 8) {
                Button(model.pauseTitle) { model.togglePause() }
                Button("Clear Settled Snow") { model.clear() }
            }
            .controlSize(.small)
            .disabled(!model.controlsEnabled)

            Divider()

            VStack(alignment: .leading, spacing: 1) {
                command("Open Szns…", action: model.openApp)
                command("Drop some coins", action: model.support)
                if let updateLabel = model.updateLabel {
                    command(updateLabel, tint: .accentColor, enabled: model.canInstallUpdate, action: model.installUpdate)
                }
                command("Quit Szns", action: model.quit)
            }
        }
        .padding(14)
        .frame(width: 280)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func command(_ title: String, tint: Color = .primary, enabled: Bool = true,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct WindPadRepresentable: NSViewRepresentable {
    var settings: WindSettings
    var onChange: (WindSettings) -> Void
    var onClose: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WindPad {
        let pad = WindPad(frame: CGRect(x: 0, y: 0, width: 176, height: 176))
        pad.settings = settings
        pad.onChange = onChange
        pad.onClose = onClose
        context.coordinator.pad = pad
        return pad
    }

    func updateNSView(_ pad: WindPad, context: Context) {
        if pad.settings != settings { pad.settings = settings }
        guard context.coordinator.needsFocus, let window = pad.window else { return }
        window.makeFirstResponder(pad)
        context.coordinator.needsFocus = false
    }

    final class Coordinator {
        var pad: WindPad?
        var needsFocus = true
    }
}
