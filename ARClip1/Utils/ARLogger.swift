import Foundation

/// Centralized logger for all AR-related debug/info/error messages.
class ARLog {
  /// Enable or disable all logging here
  static var isEnabled = false

  /// Standard debug message
  static func debug(_ message: String) {
    guard isEnabled else { return }
    print("[AR DEBUG] \(message)")
  }

  /// Warning message
  static func warning(_ message: String) {
    guard isEnabled else { return }
    print("[AR WARNING] \(message)")
  }

  /// Error message
  static func error(_ message: String) {
    guard isEnabled else { return }
    print("[AR ERROR] \(message)")
  }
} 