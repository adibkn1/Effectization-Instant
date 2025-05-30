import UIKit
import SwiftUI
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var currentConfigID: String = "default"
    var currentFolderID: String = ""  // No default folder ID
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
        ARLog.debug("Scene will connect")
        
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
        
        // FIRST: Check environment variables for debugging/App Clip
        // This is the highest priority source for the URL
        if let envURLString = ProcessInfo.processInfo.environment["_XCAppClipURL"],
           let url = URL(string: envURLString) {
            ARLog.debug("🔍 URL from environment (_XCAppClipURL): \(envURLString)")
            initialURL = url
        }
        
        // SECOND: Process URLs from connection options
        if initialURL == nil, let url = connectionOptions.urlContexts.first?.url {
            ARLog.debug("🔍 URL from connection options: \(url.absoluteString)")
            initialURL = url
        }
        
        // THIRD: Handle user activity if present
        if initialURL == nil, let userActivity = connectionOptions.userActivities.first,
           let url = userActivity.webpageURL {
            ARLog.debug("🔍 User activity received: \(userActivity.activityType)")
            ARLog.debug("🔍 URL from user activity: \(url.absoluteString)")
                initialURL = url
        }
        
        // Check if we have a valid URL with folderID
        guard let url = initialURL, let folder = url.extractFolderID() else {
            if NetworkMonitor.shared.isConnected {
                window?.rootViewController = QRViewController()
                window?.makeKeyAndVisible()
            } else {
                // Delay 200ms before showing No-Internet
                let placeholder = UIViewController()
                window?.rootViewController = placeholder
                window?.makeKeyAndVisible()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        self.window?.rootViewController = NoInternetViewController(initialLink: nil)
                    }
                }
            }
            return
        }
        
        // We have a valid folderID
        if NetworkMonitor.shared.isConnected {
            let ar = ARViewController(folderID: folder)
            ar.launchURL = url
            window?.rootViewController = ar
        } else {
            // Delay 200ms before showing No-Internet
            let placeholder = UIViewController()
            window?.rootViewController = placeholder
            window?.makeKeyAndVisible()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // If network still offline after delay
                if !NetworkMonitor.shared.isConnected {
                    self.window?.rootViewController = NoInternetViewController(initialLink: url)
                }
            }
        }
        window?.makeKeyAndVisible()
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        ARLog.debug("Scene continue user activity: \(userActivity.activityType)")
        
        var incomingURL: URL? = nil
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            incomingURL = userActivity.webpageURL
        } else if let inputURL = userActivity.userInfo?["url"] as? URL {
            incomingURL = inputURL
        }
        
        guard let url = incomingURL, let folder = url.extractFolderID() else {
            if NetworkMonitor.shared.isConnected {
                window?.rootViewController = QRViewController()
                window?.makeKeyAndVisible()
            } else {
                // Delay 200ms before showing No-Internet
                let placeholder = UIViewController()
                window?.rootViewController = placeholder
                window?.makeKeyAndVisible()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        self.window?.rootViewController = NoInternetViewController(initialLink: nil)
            }
        }
            }
            return
        }
        
        if NetworkMonitor.shared.isConnected {
            let ar = ARViewController(folderID: folder)
            ar.launchURL = url
            window?.rootViewController = ar
        } else {
            // Delay 200ms before showing No-Internet
            let placeholder = UIViewController()
            window?.rootViewController = placeholder
            window?.makeKeyAndVisible()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // If network still offline after delay
                if !NetworkMonitor.shared.isConnected {
                    self.window?.rootViewController = NoInternetViewController(initialLink: url)
                }
            }
        }
        window?.makeKeyAndVisible()
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        ARLog.debug("Scene open URL contexts")
        
        guard let url = URLContexts.first?.url, let folder = url.extractFolderID() else {
            if NetworkMonitor.shared.isConnected {
                window?.rootViewController = QRViewController()
                window?.makeKeyAndVisible()
            } else {
                // Delay 200ms before showing No-Internet
                let placeholder = UIViewController()
                window?.rootViewController = placeholder
                window?.makeKeyAndVisible()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        self.window?.rootViewController = NoInternetViewController(initialLink: nil)
                    }
                }
            }
            return
        }
        
        if NetworkMonitor.shared.isConnected {
            let ar = ARViewController(folderID: folder)
            ar.launchURL = url
            window?.rootViewController = ar
        } else {
            // Delay 200ms before showing No-Internet
            let placeholder = UIViewController()
            window?.rootViewController = placeholder
            window?.makeKeyAndVisible()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // If network still offline after delay
                if !NetworkMonitor.shared.isConnected {
                    self.window?.rootViewController = NoInternetViewController(initialLink: url)
                }
            }
        }
        window?.makeKeyAndVisible()
    }
    
    // New method to handle URL with validated folderID
    private func processURLWithFolderID(_ url: URL, folderID: String) {
        logToFile("📱 Processing URL with valid folderID: \(folderID)")
        
        // Update app state
        currentFolderID = folderID
        currentConfigID = "ar-img-config"
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        // Notify observers of folder ID change
        NotificationCenter.default.post(name: NSNotification.Name("UpdateFolderID"), object: nil)
        
        // Load configuration
        loadConfigForFolder(folderID)
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
        
        // Extract folder ID using URL extension
        if let folderID = url.extractFolderID() {
            logToFile("✅ Extracted folderID: \(folderID)")
            processURLWithFolderID(url, folderID: folderID)
        } else {
            logToFile("⚠️ Could not extract folderID, showing QR scanner")
            DispatchQueue.main.async {
                self.window?.rootViewController = QRViewController()
            }
        }
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
            logToFile("❌ Missing URL from any source, showing QR scanner")
            DispatchQueue.main.async {
                self.window?.rootViewController = QRViewController()
            }
            return
        }
        
        // Process the URL without falling back to defaults
        handleURL(finalURL)
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
            
            // If there's a third component, use it as the config ID
            if pathComponents.count >= 3 {
                currentConfigID = pathComponents[2]
                logToFile("🏷️ Set configID to: \(currentConfigID) from path component")
            } else {
                // If no specific config, default to "ar-img-config"
                currentConfigID = "ar-img-config"
                logToFile("🏷️ No config in path, using: \(currentConfigID)")
            }
            
            // Load configuration
            loadConfigForFolder(currentFolderID)
        } else {
            // Invalid path format, show QR scanner
            logToFile("⚠️ Invalid path format, showing QR scanner")
            DispatchQueue.main.async {
                self.window?.rootViewController = QRViewController()
            }
        }
    }
    
    // Method to load config for a specific folder
    private func loadConfigForFolder(_ folderID: String) {
        logToFile("⏳ Loading config for folderID=\(folderID)")
        
        // Clear caches before loading
        URLCache.shared.removeAllCachedResponses()
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        
        // Create a timeout mechanism
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // If we haven't posted a notification yet
            if !UserDefaults.standard.bool(forKey: "config_notification_posted") {
                self.logToFile("⚠️ Configuration load timed out after 20s, showing QR scanner")
                
                // Show QR scanner on timeout
                DispatchQueue.main.async {
                    self.window?.rootViewController = QRViewController()
                }
            }
        }
        
        // Load configuration using ConfigManager
        ConfigManager.shared.loadConfiguration(folderID: folderID) { [weak self] result in
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
                self.logToFile("✅ Configuration loaded successfully")
                self.logToFile("📋 targetImageUrl: \(config.targetImageUrl)")
                self.logToFile("📋 videoURL: \(config.videoURL)")
                
                // Post notification with config
                self.postConfigNotification(config)
                
            case .failure(let error):
                // Log error
                self.logToFile("❌ Failed to load configuration: \(error.localizedDescription)")
                
                // Show QR scanner on failure
                DispatchQueue.main.async {
                    self.window?.rootViewController = QRViewController()
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
        
        // Clear the notification posted flag so we can post a new notification
        UserDefaults.standard.removeObject(forKey: "config_notification_posted")
        
        // Reload config
            loadConfigForFolder(folderID)
        } else {
            logToFile("⚠️ No folderID specified in reload request, showing QR scanner")
            DispatchQueue.main.async {
                self.window?.rootViewController = QRViewController()
            }
        }
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