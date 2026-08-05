import SwiftUI
import AppKit
import ApplicationServices
import ServiceManagement
import Carbon

@main
struct F3LangSwitchApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    MenuBarExtra {
      VStack(alignment: .leading, spacing: 0) {
        Text("F3 Lang Switch")
          .font(.headline)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)

        Divider()

        Toggle(
          "Enabled",
          isOn: Binding(
            get: { model.isEnabled },
            set: { model.setEnabled($0) }
          )
        )
        .disabled(!model.isAccessibilityTrusted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        if !model.isAccessibilityTrusted {
          Button("Grant Accessibility…") {
            model.openAccessibilitySettings()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
        }

        Divider()

        Toggle(
          "Open at Login",
          isOn: Binding(
            get: { model.openAtLogin },
            set: { model.setOpenAtLogin($0) }
          )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)

        Divider()

        Button("Quit F3 Lang Switch") {
          model.remapper.stop()
          NSApp.terminate(nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
      }
      .frame(minWidth: 220)
      .onAppear {
        model.refresh()
      }
    } label: {
      // Text label is reliably visible in the menu bar
      Text(model.isEnabled && model.isAccessibilityTrusted ? "F3" : "F3·")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
    }
    .menuBarExtraStyle(.window)
  }
}

@MainActor
final class AppModel: ObservableObject {
  @Published var isEnabled: Bool
  @Published var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
  @Published var openAtLogin: Bool = false

  let remapper = MissionControlRemapper()

  init() {
    self.isEnabled = AppSettings.isEnabled
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
