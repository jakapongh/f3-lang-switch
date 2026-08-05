import Foundation

/// Launch-at-login helper for macOS versions before SMAppService.
enum LaunchAgentHelper {
  private static var plistURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents/com.user.f3-lang-switch.plist")
  }

  static var isEnabled: Bool {
    FileManager.default.fileExists(atPath: plistURL.path)
  }

  static func setEnabled(_ enabled: Bool) {
    let fm = FileManager.default
    if enabled {
      guard let exe = Bundle.main.executableURL?.path else { return }
      let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.user.f3-lang-switch</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(exe)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <false/>
        </dict>
        </plist>
        """
      try? fm.createDirectory(
        at: plistURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try? plist.write(to: plistURL, atomically: true, encoding: .utf8)
      let uid = getuid()
      Process.launchedProcess(
        launchPath: "/bin/launchctl",
        arguments: ["bootstrap", "gui/\(uid)", plistURL.path]
      )
    } else {
      let uid = getuid()
      Process.launchedProcess(
        launchPath: "/bin/launchctl",
        arguments: ["bootout", "gui/\(uid)", plistURL.path]
      )
      try? fm.removeItem(at: plistURL)
    }
  }
}
