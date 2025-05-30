import Foundation

extension URL {
  /// Returns the folderID when URL is in the form .../card/<folderID>/...
  func extractFolderID() -> String? {
    // 1. Try path-based extraction
    let parts = self.pathComponents.filter { !$0.isEmpty }
    if let idx = parts.firstIndex(of: Constants.cardPathComponent), idx + 1 < parts.count {
      return parts[idx + 1]
    }

    // 2. Try subdomain-based extraction: <folderID>.adagxr.com
    if let host = self.host, host.contains(".adagxr.") {
      return host.components(separatedBy: ".").first
    }

    return nil
  }
  
  /// Static method to extract folderID from a URL string
  static func extractFolderID(from urlString: String) -> String? {
    // First try to create a URL and use the instance method
    if let url = URL(string: urlString) {
      return url.extractFolderID()
    }
    
    // Fallback to manual string parsing
    let components = urlString.components(separatedBy: "/")
    for (index, component) in components.enumerated() {
      if component == Constants.cardPathComponent && index + 1 < components.count {
        return components[index + 1]
      }
    }
    
    return nil
  }
} 