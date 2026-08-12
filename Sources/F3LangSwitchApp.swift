import AppKit
import ApplicationServices
import Carbon
import Combine
import ServiceManagement

/// Pure AppKit entry point. All UI code runs on the main thread.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }

  private let model = AppModel()
  private var statusItem: NSStatusItem?
  private var settingsController: SettingsWindowController?
  private var cancellables: Set<AnyCancellable> = []

  // MARK: - Lifecycle

  func applicationDidFinishLaunching(_ notification: Notification) {
    installReopenHandler()
    installMainMenu()

    model.objectWillChange
      .sink { [weak self] _ in self?.refreshStatusItemTitle() }
      .store(in: &cancellables)
    model.$hideTrayIcon
      .dropFirst()
      .sink { [weak self] _ in self?.updateStatusItemVisibility() }
      .store(in: &cancellables)

    let controller = SettingsWindowController(model: model)
    settingsController = controller

    updateStatusItemVisibility()
    controller.show()
  }

  func applicationWillTerminate(_ notification: Notification) {
    model.remapper.stop()
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  // MARK: - Reopen: app is opened again while already running

  private func installReopenHandler() {
    NSAppleEventManager.shared().setEventHandler(
      self,
      andSelector: #selector(handleReopen(_:with:)),
      forEventClass: AEEventClass(kCoreEventClass),
      andEventID: AEEventID(kAEReopenApplication)
    )
  }

  @objc private func handleReopen(_ event: NSAppleEventDescriptor, with replyEvent: NSAppleEventDescriptor) {
    settingsController?.show()
  }

  // MARK: - Main menu (shown only while the settings window is visible)

  private func installMainMenu() {
    let mainMenu = NSMenu()

    let appMenuItem = NSMenuItem()
    mainMenu.addItem(appMenuItem)
    let appMenu = NSMenu()
    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settingsItem.target = self
    appMenu.addItem(settingsItem)
    appMenu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit F3 Lang Switch", action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    appMenu.addItem(quitItem)
    appMenuItem.submenu = appMenu

    let windowMenuItem = NSMenuItem()
    mainMenu.addItem(windowMenuItem)
    let windowMenu = NSMenu(title: "Window")
    windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    windowMenuItem.submenu = windowMenu

    NSApp.mainMenu = mainMenu
  }

  // MARK: - Status item (tray icon)

  private func updateStatusItemVisibility() {
    if model.hideTrayIcon {
      if let item = statusItem {
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
      }
      return
    }
    guard statusItem == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      button.title = statusTitle
      if let descriptor = NSFont.systemFont(ofSize: 13, weight: .semibold).fontDescriptor.withDesign(.rounded),
         let font = NSFont(descriptor: descriptor, size: 13) {
        button.font = font
      }
    }
    let menu = NSMenu()
    menu.delegate = self
    menu.autoenablesItems = false
    item.menu = menu
    statusItem = item
  }

  private var statusTitle: String {
    model.isEnabled && model.isAccessibilityTrusted ? "F3" : "F3·"
  }

  private func refreshStatusItemTitle() {
    statusItem?.button?.title = statusTitle
  }

  // MARK: - Actions

  @objc private func openSettings(_ sender: Any?) {
    settingsController?.show()
  }

  @objc private func quitApp(_ sender: Any?) {
    model.remapper.stop()
    NSApp.terminate(nil)
  }

  @objc private func toggleEnabled(_ sender: Any?) {
    model.setEnabled(!model.isEnabled)
  }

  @objc private func toggleOpenAtLogin(_ sender: Any?) {
    model.setOpenAtLogin(!model.openAtLogin)
  }

  @objc private func grantAccessibility(_ sender: Any?) {
    model.openAccessibilitySettings()
  }
}

// MARK: - Tray menu

extension AppDelegate: NSMenuDelegate {
  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()

    let titleItem = NSMenuItem(title: "F3 Lang Switch", action: nil, keyEquivalent: "")
    titleItem.isEnabled = false
    menu.addItem(titleItem)
    menu.addItem(.separator())

    let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    enabledItem.target = self
    enabledItem.state = model.isEnabled ? .on : .off
    enabledItem.isEnabled = model.isAccessibilityTrusted
    menu.addItem(enabledItem)

    if !model.isAccessibilityTrusted {
      let grantItem = NSMenuItem(title: "Grant Accessibility…", action: #selector(grantAccessibility), keyEquivalent: "")
      grantItem.target = self
      menu.addItem(grantItem)
    }

    let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
    loginItem.target = self
    loginItem.state = model.openAtLogin ? .on : .off
    menu.addItem(loginItem)

    menu.addItem(.separator())

    let settingsItem = NSMenuItem(title: "Open Settings…", action: #selector(openSettings), keyEquivalent: "")
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Quit F3 Lang Switch", action: #selector(quitApp), keyEquivalent: "")
    quitItem.target = self
    menu.addItem(quitItem)
  }
}

// MARK: - App model

/// App state. Used on the main thread only.
final class AppModel: ObservableObject {
  @Published var isEnabled: Bool
  @Published var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
  @Published var openAtLogin: Bool = false
  @Published var hideTrayIcon: Bool

  let remapper = MissionControlRemapper()

  init() {
    self.isEnabled = AppSettings.isEnabled
    self.hideTrayIcon = AppSettings.hideTrayIcon
    ProcessInfo.processInfo.disableAutomaticTermination("F3 Lang Switch menu bar agent")
    ProcessInfo.processInfo.disableSuddenTermination()
    refresh()
    if isEnabled && isAccessibilityTrusted {
      remapper.start()
    }
    if !AXIsProcessTrusted() {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        self?.promptForAccessibilityIfNeeded()
      }
    }
  }

  func refresh() {
    isAccessibilityTrusted = AXIsProcessTrusted()
    isEnabled = AppSettings.isEnabled
    if #available(macOS 13.0, *) {
      openAtLogin = SMAppService.mainApp.status == .enabled
    } else {
      openAtLogin = LaunchAgentHelper.isEnabled
    }
    setEnabled(isEnabled)
  }

  func setEnabled(_ enabled: Bool) {
    AppSettings.isEnabled = enabled
    isEnabled = enabled
    guard isAccessibilityTrusted else {
      remapper.stop()
      return
    }
    if enabled {
      remapper.start()
    } else {
      remapper.stop()
    }
  }

  func setOpenAtLogin(_ enabled: Bool) {
    do {
      if #available(macOS 13.0, *) {
        if enabled {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
      } else {
        LaunchAgentHelper.setEnabled(enabled)
        openAtLogin = LaunchAgentHelper.isEnabled
      }
    } catch {
      openAtLogin = false
    }
  }

  func setHideTrayIcon(_ enabled: Bool) {
    AppSettings.hideTrayIcon = enabled
    hideTrayIcon = enabled
  }

  func openAccessibilitySettings() {
    // Only open Settings — don't also trigger the system AX prompt (double dialog).
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    ) {
      NSWorkspace.shared.open(url)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.refresh()
    }
  }

  private func promptForAccessibilityIfNeeded() {
    guard !AXIsProcessTrusted() else { return }
    let alert = NSAlert()
    alert.messageText = "Accessibility Access Needed"
    alert.informativeText =
      "F3 Lang Switch needs Accessibility permission to remap the Mission Control key (F3) to switch languages."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Later")
    if alert.runModal() == .alertFirstButtonReturn {
      openAccessibilitySettings()
    }
  }
}
