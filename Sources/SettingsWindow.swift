import AppKit
import SwiftUI

/// SwiftUI content of the settings window.
struct SettingsView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("F3 Lang Switch")
          .font(.title2.bold())
        Text(
          "Remaps the Mission Control key (F3) to toggle the input source between ABC and Thai. "
            + "Settings can be changed here or from the menu bar icon."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      Divider()

      Toggle(
        "Enabled",
        isOn: Binding(
          get: { model.isEnabled },
          set: { model.setEnabled($0) }
        )
      )
      .disabled(!model.isAccessibilityTrusted)

      if !model.isAccessibilityTrusted {
        Button("Grant Accessibility…") {
          model.openAccessibilitySettings()
        }
      }

      Toggle(
        "Open at Login",
        isOn: Binding(
          get: { model.openAtLogin },
          set: { model.setOpenAtLogin($0) }
        )
      )

      Toggle(
        "Hide Tray Icon",
        isOn: Binding(
          get: { model.hideTrayIcon },
          set: { model.setHideTrayIcon($0) }
        )
      )

      Divider()

      HStack {
        Spacer()
        Button("Quit F3 Lang Switch") {
          model.remapper.stop()
          NSApp.terminate(nil)
        }
      }
    }
    .padding(20)
    .frame(width: 360)
  }
}

/// Owns the settings window. The Dock icon is shown only while this window is visible.
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let model: AppModel
  private var window: NSWindow?

  init(model: AppModel) {
    self.model = model
    super.init()
  }

  func show() {
    let win = window ?? makeWindow()
    window = win
    NSApp.setActivationPolicy(.regular)
    win.center()
    win.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func makeWindow() -> NSWindow {
    let hostingView = NSHostingView(rootView: SettingsView(model: model))
    let win = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    win.title = "F3 Lang Switch"
    win.contentView = hostingView
    let size = hostingView.fittingSize
    win.setContentSize(NSSize(width: max(size.width, 360), height: size.height))
    win.isReleasedWhenClosed = false
    win.delegate = self
    return win
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
