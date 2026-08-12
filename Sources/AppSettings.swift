import Foundation

enum AppSettings {
  private static let enabledKey = "isEnabled"
  private static let hideTrayIconKey = "hideTrayIcon"

  /// On by default.
  static var isEnabled: Bool {
    get {
      if UserDefaults.standard.object(forKey: enabledKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: enabledKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: enabledKey)
    }
  }

  /// Off by default.
  static var hideTrayIcon: Bool {
    get {
      if UserDefaults.standard.object(forKey: hideTrayIconKey) == nil {
        return false
      }
      return UserDefaults.standard.bool(forKey: hideTrayIconKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: hideTrayIconKey)
    }
  }
}
