import Foundation
import UIKit

// MARK: - Configuration Model
struct ARConfig: Codable {
    // MARK: - Properties
    let targetImageURL: String
    let videoURL: String
    let hasTransparency: Bool
    let videoRGBURL: String
    let videoAlphaURL: String
    let videoPlaneWidth: CGFloat
    let videoPlaneHeight: CGFloat
    let addedWidth: CGFloat?
    let addedHeight: CGFloat?
    let ctaButtonText: String
    let ctaButtonColor: String
    let ctaButtonURL: String
    let ctaButtonDelay: TimeInterval
    let overlayText: String
    let loadingText: String
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case targetImageURL
        case videoURL
        case hasTransparency
        case videoRGBURL
        case videoAlphaURL
        case videoPlaneWidth
        case videoPlaneHeight
        case addedWidth
        case addedHeight
        case ctaButtonText
        case ctaButtonColor
        case ctaButtonURL
        case ctaButtonDelay
        case overlayText
        case loadingText
    }
}

// MARK: - Config Manager
final class ConfigManager {
    // MARK: - Singleton
    static let shared = ConfigManager()
    private init() {}
    
    // MARK: - Constants
    private let BASE_URL = "https://adagxr.com/card"
    private let CONFIG_FILENAME = "sample_config.json"
    private let DEFAULT_FOLDER_ID = "ar"
    
    // MARK: - Configuration Loading
    func loadConfiguration(folderID: String, completion: @escaping (Result<ARConfig, Error>) -> Void) {
        // Log start of configuration loading
        log("📥 Starting configuration load for folder: \(folderID)")
        
        // Construct the URL for the configuration file
        let configURLString = "\(BASE_URL)/\(folderID)/\(CONFIG_FILENAME)"
        log("🔗 Configuration URL: \(configURLString)")
        
        // Force clear all caches
        URLCache.shared.removeAllCachedResponses()
        log("🧹 Cleared URL cache to force fresh request")
        
        guard let configURL = URL(string: configURLString) else {
            log("❌ Invalid URL: \(configURLString)")
            completion(.failure(ConfigError.invalidURL))
            return
        }
        
        // Create a network request with cache-busting settings
        var request = URLRequest(url: configURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        
        // Add cache-busting query parameter
        let timestamp = Int(Date().timeIntervalSince1970)
        let cacheBustURL = URL(string: configURLString + "?t=\(timestamp)")!
        request.url = cacheBustURL
        log("🔄 Added cache-busting timestamp: \(timestamp)")
        
        // Add debug headers - fix String.SubSequence issue
        let requestID = String(UUID().uuidString.prefix(8))
        request.addValue(requestID, forHTTPHeaderField: "X-Request-ID")
        
        log("🚀 Sending request [\(requestID)] to: \(cacheBustURL.absoluteString)")
        
        // Execute the network request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Check for network errors
            if let error = error {
                self.log("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                self.log("❌ Invalid HTTP response")
                completion(.failure(ConfigError.invalidResponse))
                return
            }
            
            self.log("📊 Response status code: \(httpResponse.statusCode)")
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                self.log("❌ HTTP error: \(httpResponse.statusCode)")
                completion(.failure(ConfigError.httpError(httpResponse.statusCode)))
                return
            }
            
            // Validate data
            guard let data = data, !data.isEmpty else {
                self.log("❌ Empty response data")
                completion(.failure(ConfigError.emptyData))
                return
            }
            
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
                self.log("📋 Button text: '\(config.ctaButtonText)'")
                self.log("📋 Target image URL: \(config.targetImageURL)")
                self.log("📋 Video URL: \(config.videoURL)")
                self.log("📋 Video dimensions: \(config.videoPlaneWidth) x \(config.videoPlaneHeight)")
                
                // Return the parsed configuration on the main thread
                DispatchQueue.main.async {
                    completion(.success(config))
                }
            } catch {
                self.log("❌ JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Backwards compatibility method for older code
    func loadConfig(folderID: String, configID: String, completion: @escaping (ARConfig) -> Void) {
        loadConfiguration(folderID: folderID) { result in
            switch result {
            case .success(let config):
                completion(config)
            case .failure:
                // Return an empty config instead of nil
                let emptyConfig = ARConfig(
                    targetImageURL: "",
                    videoURL: "",
                    hasTransparency: false,
                    videoRGBURL: "",
                    videoAlphaURL: "",
                    videoPlaneWidth: 1.0,
                    videoPlaneHeight: 1.41431,
                    addedWidth: 1.0,
                    addedHeight: 1.0,
                    ctaButtonText: "Learn More",
                    ctaButtonColor: "#F84B07",
                    ctaButtonURL: "https://effectizationstudio.com",
                    ctaButtonDelay: 1.0,
                    overlayText: "Scan this image",
                    loadingText: "Preparing your experience"
                )
                completion(emptyConfig)
            }
        }
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
        print("[ConfigManager] \(message)")
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