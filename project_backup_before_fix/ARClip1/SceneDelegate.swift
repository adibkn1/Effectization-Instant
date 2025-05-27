import UIKit
import SwiftUI
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var currentConfigID: String = "default"
    var currentFolderID: String = "ar" // Default folder ID
    var launchURL: URL?
    
    // Set up persistent logging
    private let logFileURL: URL = {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("app_clip_log.txt")
    }()
    
    private func logToFile(_ message: String) {
        // Also send to console
        print(message)
        
        // Format with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Append to file
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomicWrite)
            }
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("[AR] Scene will connect")
        
        // Register for config reload requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigReloadRequest),
            name: NSNotification.Name("RequestConfigReloadNotification"),
            object: nil
        )
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window
        window = UIWindow(windowScene: windowScene)
        
        var initialURL: URL? = nil
        var folderID = "ar" // Default folder ID
        
        // FIRST: Check environment variables for debugging/App Clip
        // This is the highest priority source for the URL
        if let envURL = ProcessInfo.processInfo.environment["_XCAppClipURL"],
           let url = URL(string: envURL) {
            print("[AR] 🔍 URL from environment (_XCAppClipURL): \(envURL)")
            initialURL = url
            
            // Extract folder ID from URL
            if let extractedFolderID = extractFolderIDFromURL(url) {
                folderID = extractedFolderID
                print("[AR] ✅ Extracted folderID from environment: \(folderID)")
            } else {
                print("[AR] ⚠️ Could not extract folderID from environment URL")
            }
            
            handleURL(url)
        }
        
        // SECOND: Process URLs from connection options
        if folderID == "ar", let url = connectionOptions.urlContexts.first?.url {
            print("[AR] 🔍 URL from connection options: \(url.absoluteString)")
            initialURL = url
            
            // Extract folder ID from URL
            if let extractedFolderID = extractFolderIDFromURL(url) {
                folderID = extractedFolderID
                print("[AR] ✅ Extracted folderID from URL context: \(folderID)")
            } else {
                print("[AR] ⚠️ Could not extract folderID from URL context")
            }
            
            // Update internal state and continue with URL handling
            handleURL(url)
        }
        
        // THIRD: Handle user activity if present
        if folderID == "ar", let userActivity = connectionOptions.userActivities.first {
            print("[AR] 🔍 User activity received: \(userActivity.activityType)")
            if let url = userActivity.webpageURL {
                print("[AR] 🔍 URL from user activity: \(url.absoluteString)")
                initialURL = url
                
                // Extract folder ID from URL
                if let extractedFolderID = extractFolderIDFromURL(url) {
                    folderID = extractedFolderID
                    print("[AR] ✅ Extracted folderID from user activity: \(folderID)")
                } else {
                    print("[AR] ⚠️ Could not extract folderID from user activity")
                }
                
                handleURL(url)
            }
        }
        
        // Set current folder ID from extraction result
        currentFolderID = folderID
        print("[AR] 🚀 Using folderID: \(folderID) for view controller creation")
        
        // Create and set root view controller with extracted folderID
        let arViewController = ARViewController(folderID: folderID)
        
        // Set the URL after initialization so it can handle any additional processing
        if let url = initialURL {
            arViewController.launchURL = url
        }
        
        window?.rootViewController = arViewController
        window?.makeKeyAndVisible()
    }
    
    // Helper method to extract folderID from URL
    private func extractFolderIDFromURL(_ url: URL) -> String? {
        // Try path component extraction first
        let pathComponents = url.pathComponents.filter { !$0.isEmpty }
        if pathComponents.contains("card") {
            if let cardIndex = pathComponents.firstIndex(of: "card"), cardIndex + 1 < pathComponents.count {
                return pathComponents[cardIndex + 1]
            }
        }
        
        // Try URL path extraction
        if let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
            let pathComps = path.components(separatedBy: "/").filter { !$0.isEmpty }
            if pathComps.count >= 2 && pathComps[0] == "card" {
                return pathComps[1]
            }
        }
        
        // Try subdomain extraction
        if let host = url.host, host.contains(".") {
            let hostComponents = host.components(separatedBy: ".")
            if hostComponents.count >= 3 && hostComponents[1] == "adagxr" {
                return hostComponents[0]
            }
        }
        
        return nil
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        print("[AR] Scene continue user activity: \(userActivity.activityType)")
        if let url = userActivity.webpageURL {
            print("[AR] URL from user activity: \(url.absoluteString)")
            if let arViewController = window?.rootViewController as? ARViewController {
                arViewController.launchURL = url
            }
            handleURL(url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("[AR] Scene open URL contexts")
        if let url = URLContexts.first?.url {
            print("[AR] URL from contexts: \(url.absoluteString)")
            if let arViewController = window?.rootViewController as? ARViewController {
                arViewController.launchURL = url
            }
            handleURL(url)
        }
    }
    
    private func handleURL(_ url: URL) {
        logToFile("📱 Handling URL: \(url.absoluteString)")
        
        // DEBUG: Print all URL components for diagnosis
        logToFile("🔍 DEBUG URL COMPONENTS:")
        logToFile("🔍 scheme: \(url.scheme ?? "nil")")
        logToFile("🔍 host: \(url.host ?? "nil")")
        logToFile("🔍 path: \(url.path)")
        logToFile("🔍 pathComponents: \(url.pathComponents)")
        logToFile("🔍 filtered pathComponents: \(url.pathComponents.filter { !$0.isEmpty })")
        
        // Extract folder ID from URL path using improved method
        let pathComponents = url.pathComponents.filter { !$0.isEmpty }
        
        // For URLs with 'card' in the path (e.g., /card/ar1/)
        if pathComponents.contains("card") {
            if let cardIndex = pathComponents.firstIndex(of: "card"), cardIndex + 1 < pathComponents.count {
                // Get the folder ID (ar1, ar2, etc.)
                let folderID = pathComponents[cardIndex + 1]
                logToFile("✅ Extracted folderID from path: \(folderID)")
                
                // Update app state
                currentFolderID = folderID
                currentConfigID = "sample_config"
                
                // Clear caches
                URLCache.shared.removeAllCachedResponses()
                
                logToFile("🔄 Updated app state with folderID: \(folderID)")
                
                // Notify observers of folder ID change
                NotificationCenter.default.post(name: NSNotification.Name("UpdateFolderID"), object: nil)
                
                // Load configuration
                loadAndApplyConfig()
                return
            }
        }
        
        // Try to extract from host if it's a subdomain
        if let host = url.host, host.contains(".") {
            let hostComponents = host.components(separatedBy: ".")
            if hostComponents.count >= 3 && hostComponents[1] == "adagxr" {
                let possibleFolderID = hostComponents[0]
                logToFile("✅ Extracted folderID from subdomain: \(possibleFolderID)")
                
                // Update app state
                currentFolderID = possibleFolderID
                currentConfigID = "sample_config"
                
                // Clear caches
                URLCache.shared.removeAllCachedResponses()
                
                // Notify observers
                NotificationCenter.default.post(name: NSNotification.Name("UpdateFolderID"), object: nil)
                
                // Load configuration
                loadAndApplyConfig()
                return
            }
        }
        
        // Fallback to default folder ID
        logToFile("⚠️ Could not extract folderID, using default")
        currentFolderID = "ar"
        currentConfigID = "sample_config"
        
        // Notify observers
        NotificationCenter.default.post(name: NSNotification.Name("UpdateFolderID"), object: nil)
        
        // Load configuration
        loadAndApplyConfig()
    }
    
    private func handleUserActivity(_ userActivity: NSUserActivity) {
        logToFile("🔍 Handling user activity: \(userActivity.activityType)")
        logToFile("🔍 All user activity info: \(userActivity)")
        
        // Get URL either from web activity or custom scheme
        var incomingURL: URL?
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            incomingURL = userActivity.webpageURL
            logToFile("📱 Got URL from web browsing activity")
        } else if let inputURL = userActivity.userInfo?["url"] as? URL {
            // This is for testing with custom URL schemes
            incomingURL = inputURL
            logToFile("📱 Got URL from custom scheme: \(inputURL)")
        }
        
        guard let finalURL = incomingURL else { 
            logToFile("❌ Missing URL from any source")
            loadAndApplyConfig() // Load with default settings
            return
        }
        
        logToFile("🌐 App Clip processing URL: \(finalURL.absoluteString)")
        
        // Special handling for development testing with appclip:// scheme
        if finalURL.scheme == "appclip" {
            logToFile("🧪 Development testing mode with appclip:// scheme")
            let path = finalURL.path
            
            // Handle the special case where we need to extract from the host instead
            var pathToUse = path
            if path.isEmpty && finalURL.host != nil {
                pathToUse = "/\(finalURL.host!)\(path)"
                logToFile("🧪 Using host as part of path: \(pathToUse)")
            }
            
            handlePath(pathToUse)
            return
        }
        
        // Normal URL handling
        if let path = URLComponents(url: finalURL, resolvingAgainstBaseURL: true)?.path {
            handlePath(path)
        } else {
            logToFile("⚠️ Could not extract path from URL")
            loadAndApplyConfig() // Load with default settings
        }
    }
    
    private func handlePath(_ path: String) {
        logToFile("📂 Processing URL Path: \(path)")
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        logToFile("📂 Path components: \(pathComponents)")
        
        // Check if path contains "card" followed by an AR folder ID
        if pathComponents.count >= 2 && pathComponents[0] == "card" {
            // Set the folder ID (ar1, ar2, etc.)
            currentFolderID = pathComponents[1]
            logToFile("🏷️ Set folderID to: \(currentFolderID)")
            logToFile("📂 Will load config from: https://adagxr.com/card/\(currentFolderID)/")
            
            // If there's a third component, use it as the config ID
            if pathComponents.count >= 3 {
                currentConfigID = pathComponents[2]
                logToFile("🏷️ Set configID to: \(currentConfigID) from path component")
            } else {
                // If no specific config, default to "sample_config"
                currentConfigID = "sample_config"
                logToFile("🏷️ No config in path, defaulting to: \(currentConfigID)")
            }
        } else if pathComponents.count <= 1 {
            // Handle the case where the URL is just /card or / without a specific folder ID
            // In this case, use ar as the default folder ID
            currentFolderID = "ar" // Default to ar when no folder ID is specified
            currentConfigID = "sample_config"
            logToFile("⚠️ Path only contains 'card' or empty, defaulting folderID to: \(currentFolderID)")
            logToFile("📂 Will load config from: https://adagxr.com/card/\(currentFolderID)/")
        } else {
            logToFile("⚠️ Path does not contain expected 'card/[folderID]' format")
            // Default to ar as a fallback for any unexpected path format
            currentFolderID = "ar" 
            currentConfigID = "sample_config"
            logToFile("🔄 Falling back to default folderID: \(currentFolderID)")
        }
        
        logToFile("📋 FINAL CONFIG: Using folder ID: \(currentFolderID), config ID: \(currentConfigID)")
        
        // Load configuration and update the AR experience
        loadAndApplyConfig()
    }
    
    private func loadAndApplyConfig() {
        logToFile("⏳ Starting config load for folderID=\(currentFolderID)")
        logToFile("🔍 CURRENT STATE: folderID='\(currentFolderID)', configID='\(currentConfigID)'")
        
        // Clear caches before loading
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        
        // Set loading state
        let loadingID = String(UUID().uuidString.prefix(6))
        logToFile("🔄 [Request \(loadingID)] Loading configuration")
        
        // DEBUG: Log what config URL should be loaded
        let expectedURL = "https://adagxr.com/card/\(currentFolderID)/sample_config.json"
        logToFile("🔍 Expected config URL: \(expectedURL)")
        
        // Create a timeout mechanism
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // If we haven't posted a notification yet
            if !UserDefaults.standard.bool(forKey: "config_notification_posted") {
                self.logToFile("⚠️ [Request \(loadingID)] Configuration load timed out after 20s")
                // Instead of posting a default config, present QR scanner and show message
                DispatchQueue.main.async {
                    if let window = self.window {
                        let qrVC = QRViewController()
                        qrVC.modalPresentationStyle = .fullScreen
                        qrVC.modalTransitionStyle = .crossDissolve
                        window.rootViewController?.present(qrVC, animated: true) {
                            qrVC.showUnsupportedQRCodeMessage()
                        }
                    }
                }
            }
        }
        
        // Load configuration using new ConfigManager
        ConfigManager.shared.loadConfiguration(folderID: currentFolderID) { [weak self] result in
            guard let self = self else { return }
            
            // Cancel timeout timer
            timeoutTimer.invalidate()
            
            // Only proceed if we haven't already posted a notification
            guard !UserDefaults.standard.bool(forKey: "config_notification_posted") else {
                self.logToFile("✅ Config notification was already posted, not posting another")
                return
            }
            
            switch result {
            case .success(let config):
                // Log successful configuration
                self.logToFile("✅ [Request \(loadingID)] Configuration loaded successfully")
                self.logToFile("📋 targetImageURL: \(config.targetImageURL)")
                self.logToFile("📋 videoURL: \(config.videoURL)")
                self.logToFile("📋 Button text: '\(config.ctaButtonText)'")
                self.logToFile("📋 Overlay text: '\(config.overlayText)'")
                
                // Post notification with config
                self.postConfigNotification(config)
                
            case .failure(let error):
                // Log error
                self.logToFile("❌ [Request \(loadingID)] Failed to load configuration: \(error.localizedDescription)")
                
                // Instead of posting a default config, present QR scanner and show message
                DispatchQueue.main.async {
                    if let window = self.window {
                        let qrVC = QRViewController()
                        qrVC.modalPresentationStyle = .fullScreen
                        qrVC.modalTransitionStyle = .crossDissolve
                        window.rootViewController?.present(qrVC, animated: true) {
                            qrVC.showUnsupportedQRCodeMessage()
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to post config notification
    private func postConfigNotification(_ config: ARConfig) {
        // Only post if we haven't already
        guard !UserDefaults.standard.bool(forKey: "config_notification_posted") else {
            return
        }
        
        logToFile("📣 Posting ConfigLoadedNotification")
        
        // Post notification with config
        NotificationCenter.default.post(
            name: Notification.Name("ConfigLoadedNotification"),
            object: nil,
            userInfo: ["config": config]
        )
        
        // Mark that we've posted a notification
        UserDefaults.standard.set(true, forKey: "config_notification_posted")
    }
    
    // Clear all app caches
    private func clearAppCache() {
        logToFile("🧹 Clearing app cache")
        
        // Clear UserDefaults cache
        UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
        UserDefaults.standard.removeObject(forKey: "cached_config")
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        logToFile("✅ Cache cleared")
    }
    
    @objc private func handleConfigReloadRequest(_ notification: Notification) {
        logToFile("📣 Received config reload request")
        
        // Check if a specific folderID was provided
        if let folderID = notification.userInfo?["folderID"] as? String {
            logToFile("🔄 Will reload config with specified folderID: \(folderID)")
            currentFolderID = folderID
        }
        
        // Clear the notification posted flag so we can post a new notification
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        
        // Reload config
        loadAndApplyConfig()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        logToFile("📱 sceneDidDisconnect")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        logToFile("📱 sceneDidBecomeActive")
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        logToFile("📱 sceneWillResignActive")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        logToFile("📱 sceneWillEnterForeground")
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        logToFile("📱 sceneDidEnterBackground")
    }
    
    private func addViewLogsButton() {
        guard let rootViewController = window?.rootViewController else { return }
        
        let button = UIButton(type: .system)
        button.setTitle("View Logs", for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showLogs), for: .touchUpInside)
        
        if let hostingController = rootViewController as? UIHostingController<ARContentView> {
            hostingController.view.addSubview(button)
            
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: hostingController.view.safeAreaLayoutGuide.topAnchor, constant: 10),
                button.trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor, constant: -10),
                button.widthAnchor.constraint(equalToConstant: 100),
                button.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }
    
    @objc private func showLogs() {
        guard let rootViewController = window?.rootViewController,
              FileManager.default.fileExists(atPath: logFileURL.path),
              let logData = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            let alert = UIAlertController(title: "No Logs", message: "No log data found", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            window?.rootViewController?.present(alert, animated: true)
            return
        }
        
        let logViewController = UIViewController()
        logViewController.view.backgroundColor = .black
        
        let textView = UITextView()
        textView.text = logData
        textView.isEditable = false
        textView.backgroundColor = .black
        textView.textColor = .white
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.darkGray
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(logViewController, action: #selector(UIViewController.dismiss(animated:completion:)), for: .touchUpInside)
        
        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear Logs", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        clearButton.layer.cornerRadius = 8
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearLogs), for: .touchUpInside)
        
        logViewController.view.addSubview(textView)
        logViewController.view.addSubview(closeButton)
        logViewController.view.addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: logViewController.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: logViewController.view.leadingAnchor, constant: 10),
            textView.trailingAnchor.constraint(equalTo: logViewController.view.trailingAnchor, constant: -10),
            textView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -10),
            
            closeButton.bottomAnchor.constraint(equalTo: logViewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            closeButton.leadingAnchor.constraint(equalTo: logViewController.view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 100),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            clearButton.bottomAnchor.constraint(equalTo: logViewController.view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            clearButton.trailingAnchor.constraint(equalTo: logViewController.view.trailingAnchor, constant: -20),
            clearButton.widthAnchor.constraint(equalToConstant: 100),
            clearButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Show the log view controller
        logViewController.modalPresentationStyle = .fullScreen
        rootViewController.present(logViewController, animated: true)
    }
    
    @objc private func clearLogs() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        self.logToFile("Logs cleared")
        // Force refresh the logs view
        window?.rootViewController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.showLogs()
        }
    }
} 