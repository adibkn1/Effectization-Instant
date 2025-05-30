import Foundation

struct Constants {
  // Base URL for all AR assets and configs
  static let baseCardURL = "https://adagxr.com/card"

  // Filename for the JSON config in each folder
  static let configFilename = "ar-img-config.json"

  // Default folder ID when none is provided
  static let defaultFolderID = "ar"

  // Path segment used in deep links
  static let cardPathComponent = "card"

  // Retry/time-out settings
  static let maxAssetRetries = 3
  static let loadingTimeout: TimeInterval = 30
} 