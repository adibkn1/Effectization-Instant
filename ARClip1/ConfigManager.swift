import Foundation

// Configuration model that matches the remote JSON structure
struct ARConfig: Codable {
    let targetImageURL: String
    let videoURL: String
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
    
    // Static function to create a default configuration with the correct folderID
    static func defaultConfig(folderID: String) -> ARConfig {
        // Always use "ar" as the fallback folder
        let safeFolder = "ar"
        
        // Include proper fallback text values instead of empty strings
        return ARConfig(
            targetImageURL: "https://adagxr.com/card/\(safeFolder)/image.png",
            videoURL: "https://adagxr.com/card/\(safeFolder)/video.mov", 
            videoPlaneWidth: 1.0,
            videoPlaneHeight: 1.41431,
            addedWidth: 1.0,
            addedHeight: 1.0,
            ctaButtonText: "Learn More", // Default button text
            ctaButtonColor: "#F84B07",   // Default orange color
            ctaButtonURL: "https://effectizationstudio.com",
            ctaButtonDelay: 1.0,
            overlayText: "Scan this image", // Default overlay text
            loadingText: "Preparing your experience" // Default loading text
        )
    }
}

class ConfigManager {
    static let shared = ConfigManager()
    
    // Set to false to FORCE loading from remote URL
    private let useLocalSampleConfig = false
    
    private init() {}
    
    private var cachedConfig: ARConfig?
    private let cacheTimeKey = "config_cache_timestamp"
    private let cachedConfigKey = "cached_config"
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    // Load configuration from remote or cached source
    func loadConfig(folderID: String, configID: String, completion: @escaping (ARConfig) -> Void) {
        print("[Config] Loading configuration for folderID: \(folderID), configID: \(configID)")
        
        // Check if we should use local sample config in debug mode
        if useLocalSampleConfig {
            print("[Config] 🧪 DEBUG MODE: Using local sample_config.json")
            loadFallbackConfig(completion: completion)
            return
        }
        
        // First try to fetch from remote to ensure fresh content
        print("[Config] 🌐 FORCING remote fetch from adagxr.com")
        
        // Start a timeout handler
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("[Config] ⚠️ Remote fetch timeout reached, may use fallback if remote fetch fails")
        }
        
        fetchRemoteConfig(folderID: folderID, configID: configID) { config in
            // Cancel timeout
            timeoutTimer.invalidate()
            
            // ONLY use the remote config - no validation checks that would trigger fallback
            print("[Config] ✅ Using remote config with loaded values")
            completion(config)
        }
    }
    
    private func fetchRemoteConfig(folderID: String, configID: String, completion: @escaping (ARConfig) -> Void) {
        // Use the requested folderID
        let requestedFolder = folderID
        
        // Always force configID to be sample_config
        let finalConfigID = "sample_config"
        
        // Add timestamp for cache busting
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let configURLString = "https://adagxr.com/card/\(requestedFolder)/\(finalConfigID).json?t=\(timestamp)"
        print("[Config] 📥 FETCHING config from URL: \(configURLString)")
        
        guard let url = URL(string: configURLString) else {
            print("[Config] ❌ ERROR: Invalid config URL: \(configURLString)")
            // Call loadFallbackConfig instead of creating inline
            loadFallbackConfig(completion: completion)
            return
        }
        
        // Add retry mechanism with improved logging
        fetchWithRetry(url: url, retryCount: 0, maxRetries: 3, requestedFolder: requestedFolder, completion: completion)
    }
    
    private func fetchWithRetry(url: URL, retryCount: Int, maxRetries: Int, requestedFolder: String, completion: @escaping (ARConfig) -> Void) {
        print("[Config] 🔄 Fetch attempt #\(retryCount + 1) for URL: \(url.absoluteString)")
        
        // Create request with aggressive cache policy
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30 // Increase timeout
        
        // Add cache-busting headers
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Cache-Buster")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        print("[Config] 📤 Sending request with headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[Config] ❌ NETWORK ERROR: \(error.localizedDescription)")
                
                // Retry if we haven't reached max retries
                if retryCount < maxRetries {
                    let delay = Double(retryCount + 1) // Increase delay with each retry
                    print("[Config] 🔄 Will retry in \(delay) seconds")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchWithRetry(url: url, retryCount: retryCount + 1, maxRetries: maxRetries, requestedFolder: requestedFolder, completion: completion)
                    }
                    return
                }
                
                // If max retries reached, fall back to /ar config
                print("[Config] ⚠️ Max retries reached, using fallback config")
                self.loadFallbackConfig(completion: completion)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Config] ❌ Invalid response type")
                self.loadFallbackConfig(completion: completion)
                return
            }
            
            print("[Config] 🔍 Server response code: \(httpResponse.statusCode), headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Config] ❌ Server error: \(httpResponse.statusCode)")
                
                // Retry if we haven't reached max retries
                if retryCount < maxRetries {
                    let delay = Double(retryCount + 1)
                    print("[Config] 🔄 Will retry in \(delay) seconds")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchWithRetry(url: url, retryCount: retryCount + 1, maxRetries: maxRetries, requestedFolder: requestedFolder, completion: completion)
                    }
                    return
                }
                
                print("[Config] ⚠️ Max retries reached, using fallback config")
                self.loadFallbackConfig(completion: completion)
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("[Config] ⚠️ No data received or empty response")
                self.loadFallbackConfig(completion: completion)
                return
            }
            
            // Log the raw response for debugging
            if let dataString = String(data: data, encoding: .utf8) {
                print("[Config] 📄 Received JSON: \(dataString)")
            }
            
            do {
                let decoder = JSONDecoder()
                let config = try decoder.decode(ARConfig.self, from: data)
                print("[Config] ✅ Successfully decoded config from adagxr.com:")
                print("[Config] 📋 REMOTE CONFIG DETAILS:")
                print("[Config] - targetImageURL: \(config.targetImageURL)")
                print("[Config] - videoURL: \(config.videoURL)")
                print("[Config] - videoPlaneWidth: \(config.videoPlaneWidth)")
                print("[Config] - videoPlaneHeight: \(config.videoPlaneHeight)")
                print("[Config] - addedWidth: \(config.addedWidth ?? 1.0)")
                print("[Config] - addedHeight: \(config.addedHeight ?? 1.0)")
                print("[Config] - ctaButtonText: '\(config.ctaButtonText)'")
                print("[Config] - ctaButtonColor: \(config.ctaButtonColor)")
                print("[Config] - ctaButtonURL: \(config.ctaButtonURL)")
                print("[Config] - ctaButtonDelay: \(config.ctaButtonDelay)")
                print("[Config] - overlayText: '\(config.overlayText)'")
                print("[Config] - loadingText: '\(config.loadingText)'")
                
                self.cacheConfig(config)
                
                DispatchQueue.main.async {
                    completion(config)
                }
            } catch {
                print("[Config] ❌ JSON decode error: \(error.localizedDescription)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("[Config] 🔍 Raw data received: \(dataString)")
                    
                    // Try to extract fields from partial data if available
                    if let config = self.createConfigFromPartialJSON(jsonString: dataString, folderID: "ar") {
                        print("[Config] ✅ Created config from partial data")
                        DispatchQueue.main.async {
                            completion(config)
                        }
                        return
                    }
                }
                
                // If we couldn't create a config from partial data and have retries left, retry
                if retryCount < maxRetries {
                    let delay = Double(retryCount + 1)
                    print("[Config] 🔄 Will retry in \(delay) seconds after JSON parsing failure")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.fetchWithRetry(url: url, retryCount: retryCount + 1, maxRetries: maxRetries, requestedFolder: requestedFolder, completion: completion)
                    }
                    return
                }
                
                print("[Config] ⚠️ Max retries reached, using fallback config")
                self.loadFallbackConfig(completion: completion)
            }
        }
        
        task.resume()
    }
    
    // Helper method to load a known good fallback config
    private func loadFallbackConfig(completion: @escaping (ARConfig) -> Void) {
        print("[Config] 📦 Loading explicit fallback config with hardcoded values")
        
        let fallbackConfig = ARConfig(
            targetImageURL: "https://adagxr.com/card/ar/image.png",
            videoURL: "https://adagxr.com/card/ar/video.mov",
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
        
        print("[Config] 📋 FALLBACK CONFIG DETAILS:")
        print("[Config] - targetImageURL: \(fallbackConfig.targetImageURL)")
        print("[Config] - videoURL: \(fallbackConfig.videoURL)")
        print("[Config] - videoPlaneWidth: \(fallbackConfig.videoPlaneWidth)")
        print("[Config] - videoPlaneHeight: \(fallbackConfig.videoPlaneHeight)")
        print("[Config] - addedWidth: \(fallbackConfig.addedWidth ?? 1.0)")
        print("[Config] - addedHeight: \(fallbackConfig.addedHeight ?? 1.0)")
        print("[Config] - ctaButtonText: '\(fallbackConfig.ctaButtonText)'")
        print("[Config] - ctaButtonColor: \(fallbackConfig.ctaButtonColor)")
        print("[Config] - overlayText: '\(fallbackConfig.overlayText)'")
        print("[Config] - loadingText: '\(fallbackConfig.loadingText)'")
        
        DispatchQueue.main.async {
            completion(fallbackConfig)
        }
    }
    
    // Helper to create a config from partial JSON data
    private func createConfigFromPartialJSON(jsonString: String, folderID: String) -> ARConfig? {
        // We use only the values from the JSON and don't rely on folderID parameter
        // If the JSON parsing fails, the caller will use the default config from the /ar folder
        
        guard let targetImageURL = extractJSONString(from: jsonString, key: "targetImageURL"),
              let videoURL = extractJSONString(from: jsonString, key: "videoURL"),
              let ctaButtonText = extractJSONString(from: jsonString, key: "ctaButtonText"),
              let ctaButtonColor = extractJSONString(from: jsonString, key: "ctaButtonColor"),
              let ctaButtonURL = extractJSONString(from: jsonString, key: "ctaButtonURL"),
              let overlayText = extractJSONString(from: jsonString, key: "overlayText"),
              let loadingText = extractJSONString(from: jsonString, key: "loadingText") else {
            // If we can't parse the required fields, return nil and let the caller use defaultConfig
            return nil
        }
        
        // Try to extract optional numerical values
        let addedWidth = extractJSONNumber(from: jsonString, key: "addedWidth") ?? 1.0
        let addedHeight = extractJSONNumber(from: jsonString, key: "addedHeight") ?? 1.0
        let videoPlaneWidth = extractJSONNumber(from: jsonString, key: "videoPlaneWidth") ?? 1.0
        let videoPlaneHeight = extractJSONNumber(from: jsonString, key: "videoPlaneHeight") ?? 1.41431
        let ctaButtonDelay = extractJSONNumber(from: jsonString, key: "ctaButtonDelay") ?? 1.0
        
        // Create config with extracted values
        return ARConfig(
            targetImageURL: targetImageURL,
            videoURL: videoURL,
            videoPlaneWidth: videoPlaneWidth,
            videoPlaneHeight: videoPlaneHeight,
            addedWidth: addedWidth,
            addedHeight: addedHeight,
            ctaButtonText: ctaButtonText,
            ctaButtonColor: ctaButtonColor,
            ctaButtonURL: ctaButtonURL,
            ctaButtonDelay: TimeInterval(ctaButtonDelay),
            overlayText: overlayText,
            loadingText: loadingText
        )
    }
    
    // Helper method to extract string values from JSON
    private func extractJSONString(from jsonString: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            if let match = regex.firstMatch(in: jsonString, options: [], range: NSRange(location: 0, length: jsonString.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: jsonString) {
                    return String(jsonString[swiftRange])
                }
            }
        }
        return nil
    }
    
    // Helper method to extract number values from JSON
    private func extractJSONNumber(from jsonString: String, key: String) -> CGFloat? {
        let pattern = "\"\(key)\"\\s*:\\s*([0-9.]+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            if let match = regex.firstMatch(in: jsonString, options: [], range: NSRange(location: 0, length: jsonString.count)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: jsonString) {
                    let valueString = String(jsonString[swiftRange])
                    return CGFloat(Double(valueString) ?? 0)
                }
            }
        }
        return nil
    }
    
    private func cacheConfig(_ config: ARConfig) {
        print("[Config] Caching config: \(config.targetImageURL)")
        do {
            let encoder = JSONEncoder()
            let configData = try encoder.encode(config)
            UserDefaults.standard.set(configData, forKey: cachedConfigKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimeKey)
            print("[Config] Config successfully cached")
        } catch {
            print("[Config] Failed to cache config: \(error.localizedDescription)")
        }
    }
    
    private func getCachedConfig() -> ARConfig? {
        print("[Config] Checking for cached config")
        
        // Check if cache exists
        guard let cacheTime = UserDefaults.standard.object(forKey: cacheTimeKey) as? TimeInterval else {
            print("[Config] No cache timestamp found")
            return nil
        }
        
        // Check if cache is still valid
        let currentTime = Date().timeIntervalSince1970
        let cacheAge = currentTime - cacheTime
        
        guard cacheAge < cacheValidityDuration else {
            print("[Config] Cache expired: \(Int(cacheAge/60)) minutes old, max \(Int(cacheValidityDuration/60)) minutes")
            return nil
        }
        
        guard let configData = UserDefaults.standard.data(forKey: cachedConfigKey) else {
            print("[Config] No cached config data found")
            return nil
        }
        
        print("[Config] Found valid cache (\(Int(cacheAge)) seconds old)")
        
        // Try to decode cached config
        do {
            let decoder = JSONDecoder()
            let config = try decoder.decode(ARConfig.self, from: configData)
            print("[Config] Successfully decoded cached config: \(config.targetImageURL)")
            return config
        } catch {
            print("[Config] Failed to decode cached config: \(error.localizedDescription)")
            return nil
        }
    }
}