import Foundation

// MARK: - Configuration Model
struct ARConfig: Codable {
    // MARK: - Properties
    let scanningTextContent: String
    let loadingText: String
    
    let targetImageUrl: URL
    let overlayOpacity: CGFloat
    
    let videoWithTransparency: Bool
    let videoRgbUrl: URL?
    let videoAlphaUrl: URL?
    
    let actualTargetImageWidthMeters: CGFloat
    let videoPlaneWidth: CGFloat
    let videoPlaneHeight: CGFloat
    
    let ctaVisible: Bool
    let ctaButtonText: String?
    let ctaButtonColorHex: String?
    let ctaDelayMs: Int?
    let ctaButtonURL: URL?
    
    // MARK: - Computed Properties for Backward Compatibility
    // These properties provide backward compatibility with existing code
    var videoURL: String {
        // Default video URL will be the RGB URL when using transparency
        if videoWithTransparency, let rgbUrl = videoRgbUrl?.absoluteString {
            return rgbUrl
        }
        return "" // Placeholder for backward compatibility
    }
    
    var overlayText: String {
        return scanningTextContent
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case scanningTextContent
        case loadingText
        
        case targetImageUrl
        case overlayOpacity
        
        case videoWithTransparency
        case videoRgbUrl
        case videoAlphaUrl
        
        case actualTargetImageWidthMeters
        case videoPlaneWidth
        case videoPlaneHeight
        
        case ctaVisible
        case ctaButtonText
        case ctaButtonColorHex
        case ctaDelayMs
        case ctaButtonURL
    }
}

// MARK: - Config Manager
final class ConfigManager {
    // MARK: - Singleton
    static let shared = ConfigManager()
    private init() {}
    
    // MARK: - Configuration Loading
    func loadConfiguration(folderID: String, completion: @escaping (Result<ARConfig, Error>) -> Void) {
        // Log start of configuration loading
        log("📥 Starting configuration load for folder: \(folderID)")
        
        // Add cache-busting timestamp
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Build URL with cache-busting parameter using Constants
        let configURLString = "\(Constants.baseCardURL)/\(folderID)/\(Constants.configFilename)?t=\(timestamp)"
        log("🔗 Configuration URL: \(configURLString)")
        
        // Force clear all caches
        URLCache.shared.removeAllCachedResponses()
        log("🧹 Cleared URL cache to force fresh request")
        
        guard let configURL = URL(string: configURLString) else {
            log("❌ Invalid URL: \(configURLString)")
            completion(.failure(ConfigError.invalidURL))
            return
        }
        
        log("🚀 Sending request to: \(configURL.absoluteString)")
        
        // Use NetworkClient instead of direct URLSession
        NetworkClient.get(from: configURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
            // Log response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                self.log("📄 Received JSON: \(jsonString)")
            }
            
            // Parse JSON data
            do {
                let decoder = JSONDecoder()
                let config = try decoder.decode(ARConfig.self, from: data)
                
                // Log successful parsing
                self.log("✅ Successfully parsed configuration")
                    self.log("📋 Button text: '\(config.ctaButtonText ?? "nil")'")
                    self.log("📋 Target image URL: \(config.targetImageUrl)")
                self.log("📋 Video dimensions: \(config.videoPlaneWidth) x \(config.videoPlaneHeight)")
                
                // Return the parsed configuration on the main thread
                DispatchQueue.main.async {
                    completion(.success(config))
                }
                } catch let parseError {
                    self.log("❌ JSON parsing error: \(parseError.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(parseError))
            }
                }
                
            case .failure(let error):
                self.log("❌ Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Backwards compatibility method for older code - now properly returns errors
    func loadConfig(folderID: String, configID: String, completion: @escaping (Result<ARConfig, Error>) -> Void) {
        loadConfiguration(folderID: folderID, completion: completion)
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
        ARLog.debug("[ConfigManager] \(message)")
    }
    
    // MARK: - Error Types
    enum ConfigError: Error {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case emptyData
        case parsingError
        case unknown
        
        var localizedDescription: String {
            switch self {
            case .invalidURL:
                return "Invalid configuration URL"
            case .invalidResponse:
                return "Invalid HTTP response"
            case .httpError(let code):
                return "HTTP error with status code: \(code)"
            case .emptyData:
                return "Empty response data"
            case .parsingError:
                return "Error parsing configuration data"
            case .unknown:
                return "Unknown configuration error"
            }
        }
    }
} 