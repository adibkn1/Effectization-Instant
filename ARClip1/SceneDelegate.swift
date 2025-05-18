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
        logToFile("🚀 App Clip LAUNCHED")
        logToFile("🔍 CONNECTION OPTIONS: \(connectionOptions)")
        
        // FOR TESTING: Set this to "ar2" or any other folderID you want to test
        // When not empty, this will override any URL from the xcscheme
        let debugFolderIDOverride = "" // Set to "ar2" to test ar2 without changing xcscheme
        
        if !debugFolderIDOverride.isEmpty {
            logToFile("🧪 DEBUGGING MODE: Overriding with folderID: \(debugFolderIDOverride)")
            currentFolderID = debugFolderIDOverride
            // Create a fake URL for testing
            self.launchURL = URL(string: "https://adagxr.com/card/\(debugFolderIDOverride)")
        }
        
        if let activities = connectionOptions.userActivities.first {
            logToFile("📱 LAUNCH ACTIVITY: \(activities.activityType)")
            if activities.activityType == NSUserActivityTypeBrowsingWeb,
               let url = activities.webpageURL {
                logToFile("🌐 LAUNCH URL: \(url.absoluteString)")
                logToFile("🔍 URL COMPONENTS: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), path=\(url.path)")
                
                // Only use the URL from activities if we're not in debug override mode
                if debugFolderIDOverride.isEmpty {
                    self.launchURL = url
                }
            }
        } else {
            logToFile("⚠️ NO USER ACTIVITIES at launch")
        }
        
        // Clear any existing cache
        clearAppCache()
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Extract launch URL from user activity (only if not using debug override)
        if debugFolderIDOverride.isEmpty, 
           let userActivity = connectionOptions.userActivities.first,
           userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL {
            logToFile("📱 App launched with URL: \(incomingURL.absoluteString)")
            self.launchURL = incomingURL
        }
        
        // Add button to view logs
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.addViewLogsButton()
        }
        
        // Register for config reload requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigReloadRequest),
            name: NSNotification.Name("RequestConfigReloadNotification"),
            object: nil
        )
        
        // Create the SwiftUI view that provides the window contents
        let contentView = ARContentView(launchURL: launchURL)
            .edgesIgnoringSafeArea(.all)
        
        // Use a UIHostingController as window root view controller
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle the App Clip invocation
        if let userActivity = connectionOptions.userActivities.first {
            print("[App] App launched with user activity: \(userActivity.activityType)")
            handleUserActivity(userActivity)
        } else {
            print("[App] No user activity found at launch")
            // Load default config
            loadAndApplyConfig()
        }
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        self.logToFile("📱 App CONTINUATION with activity: \(userActivity.activityType)")
        self.logToFile("📱 Full user activity details: \(userActivity)")
        
        // Clear the cache every time to force a fresh load
        self.clearAppCache()
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL {
            
            self.logToFile("🔍 CONTINUATION URL: \(incomingURL.absoluteString)")
            self.logToFile("🔍 URL COMPONENTS: scheme=\(incomingURL.scheme ?? "nil"), host=\(incomingURL.host ?? "nil"), path=\(incomingURL.path)")
            self.launchURL = incomingURL
            
            // Force a complete reset of config
            if let path = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true)?.path {
                let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
                self.logToFile("🔍 PATH COMPONENTS: \(pathComponents)")
                
                if pathComponents.count >= 2 && pathComponents[0] == "card" {
                    let newFolderID = pathComponents[1]
                    self.logToFile("🔄 Continuation detected NEW folderID: \(newFolderID) (current was: \(self.currentFolderID))")
                    
                    // Always update the folderID and force a reload
                    self.currentFolderID = newFolderID
                    self.currentConfigID = "sample_config"
                    
                    // Ensure cache is completely clear
                    self.logToFile("🧹 Ensuring URLCache is completely cleared for all domains")
                    URLCache.shared.removeAllCachedResponses()
                    
                    // We need to notify the active AR view controller
                    self.logToFile("📣 Posting ConfigChangedNotification to update AR view")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ConfigChangedNotification"), 
                        object: nil,
                        userInfo: ["folderID": newFolderID]
                    )
                }
            }
        }
        
        // Always reload config when continuing
        self.logToFile("🔄 Forcing config reload on continuation")
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        self.loadAndApplyConfig()
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
        logToFile("⏳ Starting config load: folderID=\(currentFolderID), configID=\(currentConfigID)")
        
        // Force clear all caches before loading
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
        UserDefaults.standard.removeObject(forKey: "cached_config")
        
        // Set loading flag indicating we're in the process of loading a config
        UserDefaults.standard.set(false, forKey: "config_notification_posted")
        
        // ENSURE configID is sample_config
        self.currentConfigID = "sample_config"
        
        // Add debug view
        print("⏬ EXPLICITLY LOADING config from: https://adagxr.com/card/\(currentFolderID)/\(currentConfigID).json")
        logToFile("⏬ EXPLICITLY LOADING config from: https://adagxr.com/card/\(currentFolderID)/\(currentConfigID).json")
        
        // Add network timeout handler
        let configTimeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.logToFile("⚠️ Config loading timed out after 30 seconds")
        }
        
        ConfigManager.shared.loadConfig(folderID: currentFolderID, configID: currentConfigID) { [weak self] config in
            guard let self = self else { return }
            
            // Cancel timeout
            configTimeout.invalidate()
            
            // Only proceed if we haven't already posted a config notification
            guard !UserDefaults.standard.bool(forKey: "config_notification_posted") else {
                self.logToFile("✅ Config notification was already posted, not posting another")
                return
            }
            
            // Print debug information about which config was loaded
            self.logToFile("✅ CONFIG LOADED: buttonText='\(config.ctaButtonText)', overlayText='\(config.overlayText)'")
            
            // Post notification with the config
            self.logToFile("📣 Posting ConfigLoadedNotification with loaded config")
            NotificationCenter.default.post(
                name: Notification.Name("ConfigLoadedNotification"),
                object: nil,
                userInfo: ["config": config]
            )
            
            // Mark that we've posted a notification to avoid duplicate default configs
            UserDefaults.standard.set(true, forKey: "config_notification_posted")
        }
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
    
    @objc private func handleConfigReloadRequest() {
        logToFile("📣 Received config reload request")
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