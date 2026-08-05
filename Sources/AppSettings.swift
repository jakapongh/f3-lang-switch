import Foundation

enum AppSettings {
  private static let enabledKey = "isEnabled"

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
}
