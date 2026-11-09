import AppKit
import SnowCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var coordinator: DesktopCoordinator?
    private var statusItem: NSStatusItem?
    private let weatherModel = WeatherMenuModel()
    private var weatherPopover: NSPopover?
    /// A click that dismisses the panel also hits the status item. Ignore that reopen.
    private var closedPanelAt: TimeInterval = 0
    private var welcomeWindow: WelcomeWindowController?
    private var snowyWindow: SnowyWindowController?
    private let decorationSettings = DecorationSettings()
    private let updater = SnowyUpdater()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read the persisted domain before coordinator startup can write settings.
        let defaults = UserDefaults.standard
        let domainName = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let shouldShowWelcome = FirstLaunchPolicy.shouldPresent(in: defaults, domainName: domainName)
        buildStatusItem()
        wireWeatherModel()
        updater.onChange = { [weak self] in self?.syncUpdate() }
        updater.start()
        do {
            let coordinator = try DesktopCoordinator()
            self.coordinator = coordinator
            coordinator.onStateChange = { [weak self] in self?.syncWeather() }
            decorationSettings.onChange = { [weak coordinator] configuration in
                coordinator?.setDecorations(configuration)
            }
            decorationSettings.desktops = coordinator.editorDesktops
            decorationSettings.onEditorVisibility = { [weak coordinator] visible in
                coordinator?.setEditorVisible(visible)
            }
            coordinator.onDesktopGeometryChange = { [weak self] desktops in
                self?.decorationSettings.desktops = desktops
            }
            decorationSettings.apply()
        } catch {
            weatherModel.status = "Metal is unavailable on this Mac"
            weatherModel.controlsEnabled = false
        }
        syncWeather()
        if coordinator != nil {
            FirstLaunchPolicy.markConsidered(in: defaults)
            if shouldShowWelcome { presentWelcome() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let welcomeWindow { welcomeWindow.present() }
        else { presentSnowyWindow() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        welcomeWindow?.close()
        snowyWindow?.close()
        weatherPopover?.performClose(nil)
        coordinator?.stop()
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Szns")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Szns (Seasons)"
        item.button?.target = self
        item.button?.action = #selector(toggleWeatherPanel)
        statusItem = item
    }

    private func wireWeatherModel() {
        weatherModel.setSnowfall = { [weak self] value in self?.coordinator?.snowfall = value }
        weatherModel.setWind = { [weak self] value in self?.coordinator?.wind = value }
        weatherModel.setTool = { [weak self] value in self?.coordinator?.tool = value }
        weatherModel.togglePause = { [weak self] in self?.coordinator?.paused.toggle() }
        weatherModel.clear = { [weak self] in self?.coordinator?.clear() }
        weatherModel.openApp = { [weak self] in
            self?.weatherPopover?.performClose(nil)
            self?.presentSnowyWindow()
        }
        weatherModel.support = { [weak self] in self?.openSupportCheckout() }
        weatherModel.installUpdate = { [weak self] in self?.updater.install() }
        weatherModel.quit = { NSApp.terminate(nil) }
        weatherModel.close = { [weak self] in self?.weatherPopover?.performClose(nil) }
    }

    private func syncUpdate() {
        if let version = updater.availableVersion {
            weatherModel.updateLabel = "Update to \(version)…"
            weatherModel.canInstallUpdate = updater.canInstall
        } else {
            weatherModel.updateLabel = nil
            weatherModel.canInstallUpdate = false
        }
    }

    @objc private func toggleWeatherPanel() {
        if let popover = weatherPopover, popover.isShown {
            popover.performClose(nil)
            return
        }
        // The click that dismisses a transient popover is delivered here too.
        if ProcessInfo.processInfo.systemUptime - closedPanelAt < 0.3 { return }
        guard let button = statusItem?.button else { return }
        syncWeather()
        syncUpdate()
        let hosting = NSHostingController(rootView: WeatherMenuView(model: weatherModel))
        hosting.sizingOptions = [.preferredContentSize]
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentViewController = hosting
        popover.delegate = self
        weatherPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

    private func presentSnowyWindow() {
        if snowyWindow == nil {
            snowyWindow = SnowyWindowController(
                settings: decorationSettings,
                resetDecorations: { [weak self] in self?.coordinator?.resetDecorations() },
                replayWalkthrough: { [weak self] in self?.presentWelcome() }
            )
        }
        snowyWindow?.present()
    }

    private func presentWelcome() {
        if welcomeWindow == nil {
            let welcome = WelcomeWindowController()
            welcome.onClose = { [weak self] in self?.welcomeWindow = nil }
            welcomeWindow = welcome
        }
        welcomeWindow?.present()
    }

    @objc private func openSupportCheckout() {
        guard let url = URL(string: "https://snowy.aauburn.com/#drop-some-coins") else { return }
        NSWorkspace.shared.open(url)
    }

    private func syncWeather() {
        guard let coordinator else { return }
        weatherModel.controlsEnabled = !coordinator.failed
        weatherModel.pauseTitle = coordinator.paused ? "Resume Snow" : "Pause Snow"
        weatherModel.snowfall = coordinator.snowfall
        weatherModel.wind = coordinator.wind
        weatherModel.tool = coordinator.tool
        if coordinator.failed { weatherModel.status = "Rendering stopped — relaunch to retry" }
        else if coordinator.policy.suspended { weatherModel.status = "Resting while your Mac cools down" }
        else if coordinator.paused { weatherModel.status = "Snow is paused" }
        else if coordinator.policy.reducedMotion { weatherModel.status = "Quiet drifts · Reduce Motion" }
        else if coordinator.policy.particleScale < 1 { weatherModel.status = "Gentle snowfall · saving energy" }
        else { weatherModel.status = "Brush a snowy edge to sweep it away" }
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closed = notification.object as? NSPopover, closed === weatherPopover else { return }
        closedPanelAt = ProcessInfo.processInfo.systemUptime
        statusItem?.button?.highlight(false)
        weatherPopover = nil
    }
}
