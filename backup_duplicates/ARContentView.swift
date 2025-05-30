import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import Network

// This extension is already defined in UIColorExtension.swift, but with different implementation
// Let's update it to match and handle double hash
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle double hash (##hexvalue)
        if hexSanitized.hasPrefix("##") {
            hexSanitized = String(hexSanitized.dropFirst())
        }
        
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let red, green, blue, alpha: CGFloat
        
        switch hexSanitized.count {
        case 6:
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
            
        case 8:
            red = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            green = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            blue = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            alpha = CGFloat(rgb & 0x000000FF) / 255.0
            
        default:
            red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            blue = CGFloat(rgb & 0x0000FF) / 255.0
            alpha = 1.0
        }
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct ARContentView: UIViewControllerRepresentable {
    var launchURL: URL?
    
    func makeUIViewController(context: Context) -> ARViewController {
        // First, directly check for environment variable (works for App Clips)
        var folderID = "ar" // Default
        var finalURL = launchURL
        
        // Check for _XCAppClipURL environment variable
        if let envURLString = ProcessInfo.processInfo.environment["_XCAppClipURL"], 
           let envURL = URL(string: envURLString) {
            print("[AR] Found environment URL: \(envURLString)")
            finalURL = envURL
            
            // Try to extract folderID from environment URL
            if let path = URLComponents(url: envURL, resolvingAgainstBaseURL: true)?.path {
                let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
                print("[AR] Environment URL path components: \(pathComponents)")
                if pathComponents.count >= 2 && pathComponents[0] == "card" {
                    folderID = pathComponents[1]
                    print("[AR] Extracted folderID from environment: \(folderID)")
                }
            }
        }
        
        // If no environment URL, try launchURL
        if folderID == "ar", let url = launchURL {
            if let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
                let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
                if pathComponents.count >= 2 && pathComponents[0] == "card" {
                    folderID = pathComponents[1]
                    print("[AR] Extracted folderID from launchURL: \(folderID)")
                }
            }
        }
        
        print("[AR] Creating controller with folderID: \(folderID)")
        
        // Create controller with folderID and URL
        let controller = ARViewController(folderID: folderID)
        controller.launchURL = finalURL
        return controller
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // No updates required for now
    }
}

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - Properties
    var sceneView: ARSCNView!
    var videoPlayer: AVPlayer?
    var isVideoReady = false
    var isImageTracked = false
    private var referenceImage: ARReferenceImage?
    private var networkMonitor: NWPathMonitor?
    private var loadingTimer: Timer?
    private var areAssetsLoaded = false
    private var retryCount = 0
    private let maxRetries = 3
    private let loadingTimeout: TimeInterval = 30 // 30 seconds timeout
    private var videoPlaneNode: SCNNode? // Track the video plane node
    private var hasShownCTAButton = false // Track if CTA button has been shown
    private var transparentVideoPlayer: TransparentVideoPlayer? // For transparent video
    private var isUsingTransparentVideo = false // Flag to track transparent video mode
    
    // MARK: - Configuration
    private var config: ARConfig = ARConfig(
        targetImageUrl: "",
        videoURL: "",
        videoWithTransparency: false,
        videoRgbUrl: "",
        videoAlphaUrl: "",
        videoPlaneWidth: 1.0,
        videoPlaneHeight: 1.41431,
        addedWidth: 1.0,
        addedHeight: 1.0,
        ctaButtonText: "",
        ctaButtonColorHex: "#F84B07",
        ctaButtonURL: "https://effectizationstudio.com",
        ctaDelayMs: 1.0,
        overlayText: "Scan this image",
        loadingText: "Preparing your experience"
    )
    private var initialFolderID: String
    
    // Custom initializer that accepts a folderID
    init(folderID: String) {
        self.initialFolderID = folderID
        super.init(nibName: nil, bundle: nil)
        
        print("[AR] Controller initialized with folderID: \(folderID)")
    }
    
    // Required initializer for UIViewController
    required init?(coder: NSCoder) {
        self.initialFolderID = "ar"
        super.init(coder: coder)
    }
    
    var overlayImageView: UIImageView!
    var overlayLabel: UILabel!
    var actionButton: UIButton!
    var loadingIndicator: UIActivityIndicatorView!
    var loadingLabel: UILabel!
    var retryButton: UIButton!
    var noInternetView: UIView!
    var noInternetImageView: UIImageView!

    private var videoPlaneWidth: CGFloat = 17.086
    private var videoPlaneHeight: CGFloat = 30.375 // default dimensions

    var launchURL: URL? {
        didSet {
            if let url = launchURL {
                print("[AR] Launch URL set: \(url.absoluteString)")
                processLaunchURL(url)
            }
        }
    }

    private var loadingTimeoutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [.top, .bottom, .left, .right]
        
        // Log initial config values
        print("[AR] Initializing AR view with folderID: \(initialFolderID)")
        print("[AR] Initial config set with targetImageUrl: \(config.targetImageUrl)")
        logConfig()
        
        // Register for config notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configLoaded(_:)),
            name: Notification.Name("ConfigLoadedNotification"),
            object: nil
        )
        
        // Register for config changes from QR scans while app is running
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configChanged(_:)),
            name: NSNotification.Name("ConfigChangedNotification"),
            object: nil
        )
        
        // Register for folderID updates from URL handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(folderIDUpdated),
            name: NSNotification.Name("UpdateFolderID"),
            object: nil
        )
        
        // Set up a debug check to verify config values after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            print("[AR] 🔍 DEBUG CHECK - Config values after 3 seconds:")
            self?.logConfig()
            
            // If we're still using the wrong folder based on environment or launch URL
            if let self = self, let url = self.launchURL {
                let currentURLFolder = self.extractFolderIDFromURL(url) 
                let configURLFolder = self.extractFolderIDFromConfigURL(self.config.targetImageUrl)
                
                print("[AR] 🔍 URL folder: \(currentURLFolder ?? "unknown"), Config folder: \(configURLFolder ?? "unknown")")
                
                if let urlFolder = currentURLFolder, 
                   let configFolder = configURLFolder,
                   urlFolder != configFolder {
                    print("[AR] 🔄 Debug check detected mismatch: URL has \(urlFolder) but config has \(configFolder) - requesting config reload")
                    // Trigger a reload
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RequestConfigReloadNotification"),
                        object: nil
                    )
                }
            }
        }
        
        checkCameraPermission()
    }
    
    // Helper method to extract folderID from URL
    private func extractFolderIDFromURL(_ url: URL) -> String? {
        // Try path component extraction
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
    
    // Helper method to extract folderID from config URL
    private func extractFolderIDFromConfigURL(_ urlString: String) -> String? {
        let components = urlString.components(separatedBy: "/")
        for (index, component) in components.enumerated() {
            if component == "card" && index + 1 < components.count {
                return components[index + 1]
            }
        }
        return nil
    }
    
    @objc private func configLoaded(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? ARConfig {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let isNewConfig = self.config.targetImageUrl != config.targetImageUrl
                print("[AR] 🔍 CONFIG DIAGNOSIS:")
                print("[AR] 🔍 Previous targetImageUrl: \(self.config.targetImageUrl)")
                print("[AR] 🔍 New targetImageUrl: \(config.targetImageUrl)")
                print("[AR] 🔍 Is new config: \(isNewConfig)")
                print("[AR] 🔍 Button text: '\(config.ctaButtonText)'")
                print("[AR] 🔍 Video URL: \(config.videoURL)")
                print("[AR] 🔍 OverlayText: '\(config.overlayText)'")
                print("[AR] 🔍 Dimensions: \(config.videoPlaneWidth) x \(config.videoPlaneHeight)")
                
                if config.videoURL.contains("/ar/") && !config.videoURL.contains("/ar1/") {
                    print("[AR] ⚠️ WARNING: Using default 'ar' folder instead of 'ar1' folder!")
                }
                
                // Store the new config
                self.config = config
                
                // Update UI elements with the new configuration
                if let loadingLabel = self.loadingLabel {
                    loadingLabel.text = config.loadingText
                    print("[AR] 📝 Updated loading text: \(config.loadingText)")
                }
                
                if let overlayLabel = self.overlayLabel {
                    overlayLabel.text = config.overlayText
                    print("[AR] 📝 Updated overlay text: \(config.overlayText)")
                }
                
                // Update button even if it's not visible yet
                if let button = self.actionButton {
                    // Get all labels in the button hierarchy
                    let labels = button.subviews.compactMap { $0 as? UILabel }
                    if let label = labels.first {
                        label.text = config.ctaButtonText
                        print("[AR] 📝 Updated CTA button text: \(config.ctaButtonText)")
                } else {
                        // If no label found, add one
                        let newLabel = UILabel()
                        newLabel.text = config.ctaButtonText
                        newLabel.textColor = .white
                        newLabel.textAlignment = .center
                        newLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
                        newLabel.translatesAutoresizingMaskIntoConstraints = false
                        button.addSubview(newLabel)
                        
                        NSLayoutConstraint.activate([
                            newLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                            newLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                        ])
                        
                        print("[AR] 🆕 Created new CTA button label: \(config.ctaButtonText)")
                    }
                    
                    // Update button color
                    let hexColor = config.ctaButtonColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    if let buttonColor = UIColor(hex: hexColor) {
                        button.backgroundColor = buttonColor
                        print("[AR] 🎨 Updated button color: \(config.ctaButtonColorHex)")
                    }
                } else {
                    print("[AR] ⚠️ Button not yet initialized")
                }
                
                // Load overlay image from config URL
                if let imageURL = URL(string: config.targetImageUrl) {
                    print("[AR] Loading overlay image from: \(config.targetImageUrl)")
                    URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
                        if let data = data, let image = UIImage(data: data) {
            DispatchQueue.main.async {
                                if let overlayImageView = self?.overlayImageView {
                                    overlayImageView.image = image
                                    print("[AR] ✅ Successfully loaded overlay image")
                                }
                            }
                        } else if let error = error {
                            print("[AR] Failed to load overlay image: \(error.localizedDescription)")
                        }
                    }.resume()
                }
                
                // Start or restart asset loading if needed
                if !self.areAssetsLoaded || isNewConfig {
                    // Cancel any existing asset loading
                    self.cancelAssetLoading()
                    // Start fresh loading with new config
                    self.startAssetLoading()
                }
            }
        }
    }

    @objc private func configChanged(_ notification: Notification) {
        if let folderID = notification.userInfo?["folderID"] as? String {
            print("[AR] APP RUNNING QR SCAN - Received config change to folderID: \(folderID)")
            
            // Reset everything
            cancelAssetLoading()
            areAssetsLoaded = false
            isVideoReady = false
            isImageTracked = false
            hasShownCTAButton = false // Reset button state
            isUsingTransparentVideo = false
            
            // Clear any existing video
            videoPlayer?.pause()
            videoPlayer = nil
            transparentVideoPlayer?.pause()
            transparentVideoPlayer = nil
            
            // Remove existing video plane
            videoPlaneNode?.removeFromParentNode()
            videoPlaneNode = nil
            
            // Show loading animation
            showLoadingAnimation()
            
            // Clear the configuration values but don't assign a new default config
            // Just keep the current config structure
            print("[AR] Updated config with new folderID: \(folderID), targetImageUrl: \(config.targetImageUrl)")
            print("[AR] New config - videoWithTransparency: \(config.videoWithTransparency), videoRgbUrl: \(config.videoRgbUrl)")
            
            // Reset loading state
            self.loadingLabel.text = config.loadingText
            self.overlayLabel.text = config.overlayText
            
            // Force URLCache clear for new domain
            URLCache.shared.removeAllCachedResponses()
            
            // Reload assets with new config
            startAssetLoading()
            
            print("[AR] Forced reload with new folderID: \(folderID)")
        }
    }

    @objc private func folderIDUpdated() {
        print("[AR] 🔄 Received folderID update notification")
        
        if let folderID = UserDefaults.standard.string(forKey: "folderID") {
            print("[AR] 🔄 Updating to folderID: \(folderID)")
            
            // Add additional validation to ensure folderID isn't corrupted
            if folderID.isEmpty {
                print("[AR] ⚠️ Empty folderID received, using default 'ar'")
                return
            }
            
            print("[AR] ✨ Using folderID: \(folderID)")
            
            // Cancel any existing asset loading
            cancelAssetLoading()
            
            // Show loading animation (only if UI is initialized)
            if loadingLabel != nil && loadingIndicator != nil {
                showLoadingAnimation()
                } else {
                print("[AR] ⚠️ Cannot show loading animation - UI not initialized yet")
            }
            
            // Force clear caches
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
            UserDefaults.standard.removeObject(forKey: "cached_config")
            print("[AR] 🧹 Cleared all caches before loading config")
            
            // Explicitly log the expected config URL
            let configURL = "https://adagxr.com/card/\(folderID)/ar-img-config.json"
            print("[AR] 🔍 Will load configuration from \(configURL)")
            
            // Add cache-busting timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            print("[AR] ⏰ Added cache-busting timestamp: \(timestamp)")
            
            // Load config with direct ConfigManager call with success/failure handling
            ConfigManager.shared.loadConfiguration(folderID: folderID) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let config):
                    print("[AR] ✅ Successfully loaded configuration:")
                    print("[AR] - targetImageUrl: \(config.targetImageUrl)")
                    print("[AR] - videoURL: \(config.videoURL)")
                    print("[AR] - ctaButtonText: '\(config.ctaButtonText)'")
                    
                    if config.videoURL.contains("/ar/") && !config.videoURL.contains("/\(folderID)/") {
                        print("[AR] ⚠️ WARNING: Config contains default 'ar' URLs instead of '\(folderID)'!")
                    }
                    
                    DispatchQueue.main.async {
                        self.config = config
                        self.applyConfig(config)
                    }
                    
                case .failure(let error):
                    print("[AR] ❌ Failed to load configuration: \(error.localizedDescription)")
                    // Instead of falling back to default config, present QR scanner and show message
                    DispatchQueue.main.async {
                        self.presentQRScannerWithMessage()
                    }
                }
            }
        }
    }

    private func cancelAssetLoading() {
        // Cancel any ongoing downloads
        self.videoPlayer?.pause()
        self.videoPlayer = nil
        self.transparentVideoPlayer?.pause()
        self.transparentVideoPlayer = nil
        self.isVideoReady = false
        self.referenceImage = nil
        self.isUsingTransparentVideo = false
        
        // Reset loading state
        print("[AR] Cancelling previous asset loading")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }

    private func checkCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    // 2. Setup camera feed immediately
                    self?.setupCameraFeed()
                } else {
                    self?.showCameraPermissionAlert()
        }
            }
        }
    }

    private func setupCameraFeed() {
        // Initialize ARSCNView first and show camera feed immediately
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .clear // For alpha support
        view.addSubview(sceneView)
        
        // Start basic AR session immediately to show camera feed
        let configuration = ARImageTrackingConfiguration()
        sceneView.session.run(configuration)

        // Setup UI elements (but keep them hidden initially)
        setupUIElements()
        
        // Show loading indicator but don't start loading assets yet
        showLoadingAnimation()
        
        // Setup audio session
        setupAudioSession()
        
        // Setup network monitoring (but it won't show errors until we've tried loading config)
        setupNetworkMonitoring()
    }
    
    private func setupUIElements() {
        setupOverlay()
        setupButton()
        setupLoadingIndicator()
        setupLoadingLabel()
        setupNoInternetView()

        // Initially hide all UI elements
        overlayImageView.isHidden = true
        overlayLabel.isHidden = true
        noInternetView.isHidden = true
        
        // Show loading animation
        showLoadingAnimation()
    }
    
    private func startAssetLoading() {
        guard !config.targetImageUrl.isEmpty else {
            print("[AR] ❌ Cannot start asset loading: targetImageUrl is empty")
            return
        }
        
        print("[AR] Starting asset loading with config: \(config.targetImageUrl)")
        
        // Log the current configuration
        logConfig()
        
        // Start loading animation
        showLoadingAnimation()
        
        // Ensure we're showing loading state
        DispatchQueue.main.async { [weak self] in
            self?.showLoadingAnimation()
        }
        
        // Start loading assets in parallel
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Start both loads in parallel
            let group = DispatchGroup()
            
            // Load video
            group.enter()
            self?.preloadVideo {
                group.leave()
            }
            
            // Load reference image
            group.enter()
            self?.loadReferenceImage { _ in
                group.leave()
            }
            
            // When both are done
            group.notify(queue: .main) {
                self?.handleAssetsLoaded()
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("[AR] AVAudioSession configured for playback")
        } catch {
            print("[AR] Failed to set up AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func loadReferenceImage(completion: @escaping (Bool) -> Void) {
        guard let imageURL = URL(string: config.targetImageUrl) else {
            print("[AR] Invalid image URL: \(config.targetImageUrl)")
            completion(false)
            return
        }
        
        print("[AR] Loading reference image from: \(config.targetImageUrl)")
        let task = URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                print("[AR] Failed to load image: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            // Use the dimensions from config
            let physicalWidth: CGFloat = self.config.videoPlaneWidth
            let physicalHeight: CGFloat = self.config.videoPlaneHeight

            // Apply additional width and height multipliers if they exist
            var finalWidth = physicalWidth
            var finalHeight = physicalHeight
            
            // Always get the addedWidth and addedHeight from config, with fallback to 1.0
            let widthMultiplier = self.config.addedWidth ?? 1.0
            let heightMultiplier = self.config.addedHeight ?? 1.0
            
            // Apply the multipliers
            finalWidth *= widthMultiplier
            finalHeight *= heightMultiplier
            
            print("[AR] 📏 Applying size multipliers: width=\(physicalWidth) * \(widthMultiplier) = \(finalWidth)")
            print("[AR] 📏 Applying size multipliers: height=\(physicalHeight) * \(heightMultiplier) = \(finalHeight)")

            self.videoPlaneWidth = finalWidth
            self.videoPlaneHeight = finalHeight
            
            // Create reference image with physical width
            let refImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: finalWidth)
            refImage.name = "targetImage"
            self.referenceImage = refImage
            
            // Update overlay image if needed - only if the overlay image isn't already set
            DispatchQueue.main.async {
                if self.overlayImageView.image == nil {
                    self.overlayImageView.image = uiImage
                    print("[AR] Set overlay image from reference image")
    }
            }

            print("[AR] ✅ Reference image loaded successfully with dimensions: \(finalWidth) x \(finalHeight)")
            completion(true)
        }
        task.resume()
    }
    
    private func preloadVideo(completion: @escaping () -> Void) {
        // Check if we should use transparent video mode
        if config.videoWithTransparency {
            print("[AR] 🎬 Using transparent video mode with separate RGB+Alpha videos")
            
            // Create URLs for RGB and Alpha videos
            guard let rgbURL = URL(string: config.videoRgbUrl),
                  let alphaURL = URL(string: config.videoAlphaUrl) else {
                print("[AR] ❌ Invalid RGB or Alpha URLs: \(config.videoRgbUrl), \(config.videoAlphaUrl)")
                completion()
                return
            }
            
            // Validate URLs
            print("[AR] 🔍 RGB URL: \(rgbURL.absoluteString)")
            print("[AR] 🔍 Alpha URL: \(alphaURL.absoluteString)")
            
            // Create and set up transparent video player
            let transparentPlayer = TransparentVideoPlayer()
            self.transparentVideoPlayer = transparentPlayer
            self.isUsingTransparentVideo = true
            
            // Set callback for when videos are ready
            transparentPlayer.onReadyCallback = { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isVideoReady = true
                    print("[AR] ✅ Transparent video is ready with RGB+Alpha")
                    completion()
                }
            }
            
            // Set callback for errors
            transparentPlayer.onErrorCallback = { [weak self] error in
                print("[AR] ❌ Transparent video error: \(error.localizedDescription)")
                print("[AR] 🔄 Falling back to standard video mode")
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    // Reset transparent video flags
                    self.isUsingTransparentVideo = false
                    self.transparentVideoPlayer = nil
                    
                    // Fall back to standard video if available
                    if let videoURL = URL(string: self.config.videoRgbUrl) {
                        self.loadStandardVideo(videoURL: videoURL, completion: completion)
                    } else {
                        completion()
                    }
                }
            }
            
            // Load RGB and Alpha videos
            transparentPlayer.loadVideos(rgbURL: rgbURL, alphaURL: alphaURL) { success in
                if !success {
                    print("[AR] ❌ Failed to load transparent videos, falling back to standard video")
                    // Fall back to standard video
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        // Reset transparent video flags
                        self.isUsingTransparentVideo = false
                        self.transparentVideoPlayer = nil
                        
                        if let videoURL = URL(string: self.config.videoRgbUrl) {
                            self.loadStandardVideo(videoURL: videoURL, completion: completion)
                        } else {
                            completion()
                        }
                    }
                }
            }
            
            return
        }
        
        // Standard video mode (non-transparent) - use RGB HLS stream
        guard let videoURL = URL(string: self.config.videoRgbUrl) else {
            print("[AR] Invalid video RGB URL: \(config.videoRgbUrl)")
            completion()
            return
        }

        loadStandardVideo(videoURL: videoURL, completion: completion)
    }
    
    private func loadStandardVideo(videoURL: URL, completion: @escaping () -> Void) {
        print("[AR] 🎬 Using standard video mode: \(videoURL.absoluteString)")
        isUsingTransparentVideo = false

        // Check for HLS stream (.m3u8)
        if videoURL.pathExtension.lowercased() == "m3u8" {
            print("[AR] Detected HLS stream (.m3u8), using AVPlayer directly")
            setupVideoPlayer(with: videoURL, isHLS: true) {
                completion()
            }
            return
        }

        print("[AR] 📥 DOWNLOADING video from: \(videoURL.absoluteString)")
        
        // First, download the entire video to local storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Create a uniquely named file based on the URL to avoid conflicts
        let folderID = extractFolderIDFromConfigURL(config.videoRgbUrl) ?? "video"
        let destinationURL = documentsPath.appendingPathComponent("\(folderID)_cached_video.mov")
        
        // Always ensure we can write a new file
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            do {
                try FileManager.default.removeItem(at: destinationURL)
                print("[AR] 🗑️ Removed existing video file to prevent conflicts")
            } catch {
                print("[AR] ⚠️ Could not remove existing file: \(error.localizedDescription)")
                // Try to use the existing file if it exists
                self.setupVideoPlayer(with: destinationURL) {
                    completion()
                }
                return
            }
        }
        
        // Create download task to get the entire video file
        let downloadTask = URLSession.shared.downloadTask(with: videoURL) { [weak self] (tempURL, response, error) in
            guard let self = self else { 
                completion()
                return 
            }
            
            if let error = error {
                print("[AR] ❌ VIDEO DOWNLOAD FAILED: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            guard let tempURL = tempURL else {
                print("[AR] ❌ VIDEO DOWNLOAD FAILED: No temporary URL")
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            // Move the downloaded file to our documents directory
            do {
                // If file exists, remove it first
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                    print("[AR] 🔄 Removed existing cached video before saving new one")
                }
                
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("[AR] ✅ Video downloaded successfully to: \(destinationURL.path)")
                
                // Set up video player with the cached file
                self.setupVideoPlayer(with: destinationURL) {
                    completion()
                }
            } catch {
                print("[AR] ❌ ERROR saving downloaded video: \(error.localizedDescription)")
                
                // Try to use existing file if available
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    print("[AR] 🔄 Using existing cached video file")
                    self.setupVideoPlayer(with: destinationURL) {
                        completion()
                    }
                } else {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }
        
        downloadTask.resume()
    }
    
    // Separate method to set up the video player
    private func setupVideoPlayer(with videoURL: URL, isHLS: Bool = false, completion: @escaping () -> Void) {
        // First pause and release any existing player to prevent multiple playing
        if let existingPlayer = self.videoPlayer {
            existingPlayer.pause()
        }
        self.videoPlayer = nil
        
        let asset = AVURLAsset(url: videoURL)
        
        // Create player item
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        // Create player with an explicit rate to ensure it plays
        let player = AVPlayer(playerItem: playerItem)
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .none // Needed for proper looping
        // Don't mute audio to allow sound playback
        // player.isMuted = true  // This line was muting the audio
        
        // Set up video looping
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak player] _ in
            print("[AR] Video reached end, looping back to start")
            player?.seek(to: .zero)
            player?.play()
        }
        
        // Store player and mark as ready
            self.videoPlayer = player
            self.isVideoReady = true
        
        print("[AR] ✅ Video is FULLY LOADED and ready with looping enabled")
        
        // Complete setup
        DispatchQueue.main.async {
            completion()
        }
    }
    
    private func handleAssetsLoaded() {
        guard let referenceImage = self.referenceImage else { 
            print("[AR] ❌ ERROR: No reference image loaded")
            return
        }
        
        if !isVideoReady {
            print("[AR] ⚠️ WARNING: Video is not yet ready, waiting for video...")
            // Show loading state until video is ready
            DispatchQueue.main.async { [weak self] in
                guard let self = self, 
                      let loadingLabel = self.loadingLabel else {
                    print("[AR] ⚠️ Cannot update loading state - UI not initialized")
            return
        }
        
                self.showLoadingAnimation()
                loadingLabel.text = "Preparing AR experience..."
            }
            
            // Try again in 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleAssetsLoaded()
            }
            return
        }
        
        print("[AR] ✅ All assets fully loaded, proceeding to AR experience")
            
        // Update AR configuration with loaded reference image
                let configuration = ARImageTrackingConfiguration()
                configuration.trackingImages = [referenceImage]
                configuration.maximumNumberOfTrackedImages = 1
                
        // First, hide loading to improve UI responsiveness
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                
            // Hide loading animation
                    self.hideLoadingAnimation()
            
            // Explicitly set overlay text from config
            if let overlayLabel = self.overlayLabel {
                overlayLabel.text = self.config.overlayText
                print("[AR] 📝 Set overlay text to: '\(self.config.overlayText)'")
            }
            
            // Show scan overlay with appropriate text
            if let overlayImageView = self.overlayImageView, 
               let overlayLabel = self.overlayLabel {
                overlayImageView.isHidden = false
                overlayLabel.isHidden = false
                print("[AR] 👁️ Showing 'Scan this image' overlay")
            } else {
                print("[AR] ⚠️ Cannot show overlay - UI not initialized")
            }
            
            // Add small delay before updating AR session to prevent lag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Only update session if sceneView is initialized
                if let sceneView = self.sceneView {
                    // Update session configuration
                sceneView.session.run(configuration, options: [.removeExistingAnchors])
                    self.areAssetsLoaded = true
                    print("[AR] 🎯 AR session started and ready for tracking")
                } else {
                    print("[AR] ⚠️ Cannot update AR session - sceneView not initialized")
                }
            }
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Only show network error if we have no network connection and aren't showing assets yet
                if path.status == .satisfied {
                    print("[AR] Network connection available")
                    // If we aren't showing assets yet, retry loading
                    if !self.areAssetsLoaded {
                        print("[AR] Network is available, hide network error if shown")
                        self.hideNetworkError()
                    }
                } else {
                    // Only show no internet error if there's actually no internet
                    print("[AR] Network connection unavailable")
                    if !self.areAssetsLoaded {
                        print("[AR] No network, showing no internet error")
                        self.showNetworkError()
                    }
                }
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }

    private func setupRetryButton() {
        retryButton = UIButton(type: .system)
        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = UIColor(red: 248/255, green: 75/255, blue: 7/255, alpha: 1.0)
        retryButton.layer.cornerRadius = 25
        retryButton.clipsToBounds = true
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 20),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func retryButtonTapped() {
        print("[AR] Retry button tapped")
        // Always try to retry, don't rely on networkMonitor's current status which might be stale
        hideNetworkError()
        
        // Check if network is available again
        if let networkMonitor = self.networkMonitor, networkMonitor.currentPath.status == .satisfied {
            // Try loading config again
            if let url = launchURL {
                print("[AR] Re-processing launch URL: \(url)")
                processLaunchURL(url)
            } else {
                // No URL available, show QR scanner
                print("[AR] No URL available to reload - showing QR scanner")
                presentQRScannerWithMessage()
            }
        } else {
            // Still no network, just hide network error and show loading
            showLoadingAnimation()
        }
    }

    private func retryLoadingAssets() {
        guard !areAssetsLoaded else { return }
        
        // Ensure we're showing the loading state
        hideNetworkError()
        
        print("[AR] Retrying asset loading with config: \(config.targetImageUrl)")
        
        // First check if we have valid config
        if config.targetImageUrl.isEmpty || config.videoURL.isEmpty {
            print("[AR] Cannot load assets without valid config")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let group = DispatchGroup()
            
            // Load video
            group.enter()
            self?.preloadVideo {
                group.leave()
            }
            
            // Load reference image
            group.enter()
            self?.loadReferenceImage { _ in
                group.leave()
            }
            
            // When both are done
            group.notify(queue: .main) {
                self?.handleAssetsLoaded()
            }
        }
    }

    private func startLoadingTimeout() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadingTimeout()
        }
    }

    private func handleLoadingTimeout() {
        print("[AR] Loading timeout reached")
        // Check if we have network
        if let networkMonitor = self.networkMonitor, networkMonitor.currentPath.status == .satisfied {
            // We have internet but loading timed out, show QR scanner
            print("[AR] Network available but loading timed out - showing QR scanner")
            presentQRScannerWithMessage()
        } else {
            // No internet, show network error
            print("[AR] No network and loading timed out - showing network error")
            showNetworkError()
        }
    }

    private func handleSuccessfulAssetLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.loadingTimer?.invalidate()
            self.retryCount = 0
            self.hideLoadingAnimation()
            self.noInternetView.isHidden = true
            self.areAssetsLoaded = true
            
            if let referenceImage = self.referenceImage {
                let configuration = ARImageTrackingConfiguration()
                configuration.trackingImages = [referenceImage]
                configuration.maximumNumberOfTrackedImages = 1
                
                self.sceneView.session.run(configuration, options: [.removeExistingAnchors])
                self.overlayImageView.isHidden = false
                self.overlayLabel.isHidden = false
            }
        }
    }

    private func handleFailedAssetLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we have network before showing the error screen
            if let networkMonitor = self.networkMonitor, networkMonitor.currentPath.status == .satisfied {
                // We have internet but config loading failed, show QR scanner
                print("[AR] Network available but config/asset loading failed - showing QR scanner")
                self.presentQRScannerWithMessage()
            } else {
                // No internet, show network error
                print("[AR] No network connection - showing network error")
                self.showNetworkError()
            }
        }
    }

    private func showNetworkError() {
        guard !areAssetsLoaded else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.hideLoadingAnimation()
            self.overlayImageView.isHidden = true
            self.overlayLabel.isHidden = true
            self.noInternetView.isHidden = false
        }
    }

    private func hideNetworkError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.noInternetView.isHidden = true
                    self.showLoadingAnimation()
                }
    }

    private func showMaxRetriesReached() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Just keep showing the no internet view
            self.noInternetView.isHidden = false
        }
    }

    private func setupNoInternetView() {
        // Main container view
        noInternetView = UIView()
        noInternetView.backgroundColor = .black
        noInternetView.translatesAutoresizingMaskIntoConstraints = false
        noInternetView.isHidden = true
        view.addSubview(noInternetView)
        
        // No internet image - full screen
        noInternetImageView = UIImageView(image: UIImage(named: "noInternetClip"))
        noInternetImageView.contentMode = .scaleAspectFill
        noInternetImageView.translatesAutoresizingMaskIntoConstraints = false
        noInternetView.addSubview(noInternetImageView)

        // Create a gradient overlay for better text visibility
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        noInternetView.addSubview(gradientView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        gradientView.layer.addSublayer(gradientLayer)
        gradientView.tag = 100

        // Container for text and button
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        noInternetView.addSubview(contentStack)
        
        // No Internet text
        let noInternetLabel = UILabel()
        noInternetLabel.text = "NO INTERNET"
        noInternetLabel.textColor = .white
        noInternetLabel.font = .systemFont(ofSize: 24, weight: .bold)
        noInternetLabel.textAlignment = .center

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "You are not online"
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        subtitleLabel.textAlignment = .center

        // Add labels to stack
        contentStack.addArrangedSubview(noInternetLabel)
        contentStack.addArrangedSubview(subtitleLabel)

        // Retry button
        retryButton = UIButton(type: .system)
        retryButton.setTitle("RETRY", for: .normal)
        retryButton.setTitleColor(.black, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        retryButton.backgroundColor = UIColor(red: 198/255, green: 255/255, blue: 0/255, alpha: 1.0)
        retryButton.layer.cornerRadius = 25
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        noInternetView.addSubview(retryButton)

        // Portrait-only constraints
        NSLayoutConstraint.activate([
            // Container view
            noInternetView.topAnchor.constraint(equalTo: view.topAnchor),
            noInternetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noInternetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noInternetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Image view (full screen)
            noInternetImageView.topAnchor.constraint(equalTo: view.topAnchor),
            noInternetImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noInternetImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noInternetImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Gradient view
            gradientView.topAnchor.constraint(equalTo: noInternetView.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: noInternetView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: noInternetView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: noInternetView.bottomAnchor),

            // Content stack
            contentStack.centerXAnchor.constraint(equalTo: noInternetView.centerXAnchor),
            contentStack.bottomAnchor.constraint(equalTo: retryButton.topAnchor, constant: -24),

            // Retry button
            retryButton.centerXAnchor.constraint(equalTo: noInternetView.centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            retryButton.widthAnchor.constraint(equalTo: noInternetView.widthAnchor, multiplier: 0.9),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
            }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        noInternetView?.frame = view.bounds
        // Update gradient layer frame
        if let gradientView = noInternetView?.viewWithTag(100),
           let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = gradientView.bounds
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runARSession()
            print("[AR] AR session started.")
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        print("[AR] AR session paused.")
        }

    func runARSession() {
        guard ARImageTrackingConfiguration.isSupported else {
            print("[AR] AR Image tracking is not supported on this device")
            return
        }
        
        // Ensure sceneView is initialized
        guard sceneView != nil else {
            print("[AR] ARSCNView not initialized")
            return
        }
        
        // Load reference image, then update configuration
        loadReferenceImage { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.handleSuccessfulAssetLoading()
            } else {
                self.handleFailedAssetLoading()
            }
        }
    }

    // Called when the AR session updates anchors (used to check tracking status)
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor else { continue }
            
            if !imageAnchor.isTracked && self.isImageTracked {
                // Image tracking is lost
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    print("[AR] Image tracking lost. Showing overlay and pausing video.")
                    
                    // Only perform actions if state has actually changed
                    if self.isImageTracked {
                        self.isImageTracked = false
                        self.showOverlay()
                        
                        // Pause video playback
                        if self.isUsingTransparentVideo {
                            self.transparentVideoPlayer?.pause()
                            print("[AR] Transparent video paused")
                        } else if let player = self.videoPlayer {
                            player.pause()
                            print("[AR] Video paused")
                        }
                        
                        // Do NOT hide the CTA button once it has been shown
                        // The button should remain visible even when tracking is lost
                    }
                }
            } else if imageAnchor.isTracked && !self.isImageTracked {
                // Image tracking is gained or regained
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    print("[AR] Image detected/re-detected. Hiding overlay and playing video.")
                    
                    // Only perform actions if state has actually changed
                    if !self.isImageTracked {
                        self.isImageTracked = true
                        
                        // Add a small delay before hiding overlay to smooth transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Hide overlay
                            self.hideOverlay()
                            
                            // Resume video playback
                            if self.isUsingTransparentVideo {
                                if self.videoPlaneNode == nil {
                                    print("[AR] ⚠️ No video plane found for transparent video")
                                    // Try to recreate the video plane
                                    if let imageAnchorNode = self.sceneView.node(for: imageAnchor) {
                                        print("[AR] 🔄 Recreating video plane for anchor")
                                        self.createVideoPlane(for: imageAnchorNode, with: imageAnchor)
                                    }
                                }
                                
                                self.transparentVideoPlayer?.play()
                                print("[AR] Transparent video playback started/resumed")
                            } else if let player = self.videoPlayer {
                                // Ensure playback starts from beginning if it's a new detection
                                if player.currentTime() == .zero {
                                    player.seek(to: .zero)
                                }
                                player.play()
                                print("[AR] Video playback started/resumed")
                            } else {
                                print("[AR] Cannot play video - player not initialized")
                            }
                            
                            // Show the CTA button with a delay if it hasn't been shown yet
                            if !self.hasShownCTAButton {
                                print("[AR] 🔄 Showing CTA button after detection")
                                self.showButtonWithDelay()
                            }
                        }
                    }
                }
            }
        }
    }

    // Optional method to handle anchor removal
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARImageAnchor {
                DispatchQueue.main.async {
                    print("[AR] Image anchor removed. Image is no longer being tracked.")
                    if self.isImageTracked {
                        self.showOverlay()
                        self.isImageTracked = false
                    }
                }
            }
        }
    }

    // Reset the AR session to remove old anchors (useful for re-detection)
    func resetARSession() {
        let configuration = ARImageTrackingConfiguration()
        
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            configuration.trackingImages = referenceImages
        }
        
        // Reset tracking flags and video
        isImageTracked = false
        
        // Reset CTA button state
        hasShownCTAButton = false
        actionButton?.isHidden = true
        
        // Remove existing video plane
        videoPlaneNode?.removeFromParentNode()
        videoPlaneNode = nil
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("[AR] AR session reset.")
    }

    // MARK: - ARSCN View Delegate
    // This method is called when an anchor is detected and a node is added to the scene
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Only proceed if an image anchor was detected
        guard let imageAnchor = anchor as? ARImageAnchor else {
            print("[AR] Anchor detected but it's not an image anchor")
            return
        }
        
        // Check if video is ready
        if !isVideoReady || videoPlayer == nil {
            print("[AR] Image detected but video player not ready")
            // Try to load the video again if it failed
            if !isVideoReady {
                print("[AR] Attempting to reload video")
                preloadVideo { [weak self] in
                    guard let self = self, self.isVideoReady, self.videoPlayer != nil else {
                        print("[AR] Failed to load video after image detection")
                        return
                    }
                    // Create video plane now that video is ready
                    self.createVideoPlane(for: node, with: imageAnchor)
                }
            }
            return
        }
        
        createVideoPlane(for: node, with: imageAnchor)
    }
    
    // Extract video plane creation to a separate method
    private func createVideoPlane(for node: SCNNode, with imageAnchor: ARImageAnchor) {
        // Check if we're using transparent video
        if isUsingTransparentVideo, let transparentPlayer = self.transparentVideoPlayer {
            print("[AR] 🎬 Creating video plane with transparent RGB+Alpha video")
            
            // Remove previous video plane if it exists
            videoPlaneNode?.removeFromParentNode()
            videoPlaneNode = nil
            
            // Get dimensions from the detected image anchor
            let imageSize = imageAnchor.referenceImage.physicalSize
            print("[AR] 📏 Detected image anchor size: \(imageSize.width) x \(imageSize.height)")
            
            // Create a plane with the proper dimensions
            let videoPlane = SCNPlane(width: self.videoPlaneWidth, height: self.videoPlaneHeight)
            
            // Get material from transparent video player
            let videoMaterial = transparentPlayer.getMaterial()
            
            // Print debug info
            print("[AR] 📐 Creating transparent video plane with dimensions: \(videoPlaneWidth) x \(videoPlaneHeight)")
            
            // Apply the material to the plane
            videoPlane.materials = [videoMaterial]
            
            // Create a node with the plane geometry
            let planeNode = SCNNode(geometry: videoPlane)
            
            // Position the node at the anchor's center
            planeNode.eulerAngles.x = -.pi / 2  // Rotate to face the camera
            planeNode.position = SCNVector3Zero // Position at origin of the anchor
            
            // Debug the position
            print("[AR] 📍 Video plane positioned at: \(planeNode.position)")
            
            // Store the plane node reference
            videoPlaneNode = planeNode
            
            // Add the plane node to the anchor's node
            node.addChildNode(planeNode)
            
            // Start playing transparent video
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if imageAnchor.isTracked {
                    // Set tracking state
                    self.isImageTracked = true
                    
                    // Add a small delay to smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Start playing the video
                        transparentPlayer.play()
                        
                        // Hide overlay and show button
                        self.hideOverlay()
                        self.showButtonWithDelay()
                        
                        print("[AR] ✅ Transparent video plane added and playback started")
                    }
                } else {
                    // Image might not be tracked yet
                    print("[AR] ⚠️ Image anchor added but not yet tracked")
                    transparentPlayer.pause()
                    self.isImageTracked = false
                    self.showOverlay()
                }
            }
            
            return
        }

        // Standard video mode - HLS stream (non-transparent)
        guard let videoPlayer = self.videoPlayer else {
            print("[AR] Cannot create video plane: no video player")
            return
        }
        
        // Remove previous video plane if it exists
        videoPlaneNode?.removeFromParentNode()
        videoPlaneNode = nil
        
        print("[AR] 🎬 Image anchor detected, adding video plane for HLS stream")
        
        // Create a plane geometry for the video
        let videoPlane = SCNPlane(width: self.videoPlaneWidth, height: self.videoPlaneHeight)
        
        // Create a material for the plane with the video player
        let videoMaterial = SCNMaterial()
        videoMaterial.diffuse.contents = videoPlayer
        videoMaterial.isDoubleSided = true
        
        // Set transparency mode based on config
        if config.videoWithTransparency {
            // Enable transparency for alpha channel support
            videoMaterial.transparencyMode = .dualLayer
            videoMaterial.blendMode = .alpha
            videoMaterial.writesToDepthBuffer = false
            videoMaterial.lightingModel = .constant
        } else {
            // Standard video without transparency
            videoMaterial.transparencyMode = .default
            videoMaterial.lightingModel = .constant
        }
        
        // Print debug info about the plane and material
        print("[AR] 📐 Creating video plane with dimensions: \(videoPlaneWidth) x \(videoPlaneHeight)")
        print("[AR] 🎥 Setting video player as plane material contents, videoWithTransparency: \(config.videoWithTransparency)")
        
        // Apply the material to the plane
        videoPlane.materials = [videoMaterial]
        
        // Create a node with the plane geometry
        let planeNode = SCNNode(geometry: videoPlane)
        
        // Position the node at the anchor's center
        planeNode.eulerAngles.x = -.pi / 2  // Rotate to face the camera
        
        // Store the plane node reference
        videoPlaneNode = planeNode
        
        // Add the plane node to the anchor's node
        node.addChildNode(planeNode)
        
        // Handle video playback immediately if the image is being tracked
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if imageAnchor.isTracked {
                // Set tracking state
                self.isImageTracked = true
                
                // Add a small delay to smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Start playing the video immediately
                videoPlayer.seek(to: .zero)
                videoPlayer.play()
                
                // Hide overlay and show button
                self.hideOverlay()
                self.showButtonWithDelay()
                
                print("[AR] ✅ Video plane added and video playback started")
                }
            } else {
                // Image might not be tracked yet
                print("[AR] ⚠️ Image anchor added but not yet tracked")
                videoPlayer.pause()
                self.isImageTracked = false
                self.showOverlay()
            }
        }
    }

    // Set up the overlay image and label displayed initially
    func setupOverlay() {
        // Create overlay image view without initial image
        overlayImageView = UIImageView()
        overlayImageView.contentMode = .scaleAspectFit
        overlayImageView.alpha = 0.8
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.isHidden = true // Start hidden
        view.addSubview(overlayImageView)
        
        // Create overlay label with config text
        overlayLabel = UILabel()
        
        // Ensure we set the text from config
        if !config.overlayText.isEmpty {
            overlayLabel.text = config.overlayText
            print("[AR] Initial overlay text set: '\(config.overlayText)'")
        } else {
        overlayLabel.text = "Scan this image"
            print("[AR] Using default overlay text: 'Scan this image'")
        }
        
        overlayLabel.textColor = .white
        overlayLabel.textAlignment = .center
        overlayLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayLabel.isHidden = true // Start hidden
        view.addSubview(overlayLabel)

        NSLayoutConstraint.activate([
            overlayImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlayImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            overlayImageView.heightAnchor.constraint(equalTo: overlayImageView.widthAnchor, multiplier: 1.5),

            overlayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayLabel.topAnchor.constraint(equalTo: overlayImageView.bottomAnchor, constant: 20)
        ])
    }

    // Set up the button displayed after image detection
    func setupButton() {
        // Create blur effect view with modern style
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 25
        blurView.clipsToBounds = true
        blurView.isHidden = true
        
        // Main button with modern styling
        actionButton = UIButton(type: .custom)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Apply button color from config
        let hexColor = config.ctaButtonColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let buttonColor = UIColor(hex: hexColor) {
            actionButton.backgroundColor = buttonColor
            print("[AR] Initial button color set: \(config.ctaButtonColorHex)")
        } else {
        actionButton.backgroundColor = UIColor(red: 248/255, green: 75/255, blue: 7/255, alpha: 1.0)
            print("[AR] Using default button color")
        }
        
        actionButton.layer.cornerRadius = 25
        actionButton.clipsToBounds = true
        actionButton.isHidden = true
        
        // Modern arrow icon
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let arrowImage = UIImage(systemName: "arrow.right.circle.fill", withConfiguration: arrowConfig)?.withRenderingMode(.alwaysTemplate)
        let arrowImageView = UIImageView(image: arrowImage)
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tintColor = .white

        // Create label with config text
        let label = UILabel()
        label.text = config.ctaButtonText
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        print("[AR] Initial button text set: '\(config.ctaButtonText)'")

        // Add views
        view.addSubview(blurView)
        view.addSubview(actionButton)
        actionButton.addSubview(arrowImageView)
        actionButton.addSubview(label)

        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            blurView.heightAnchor.constraint(equalToConstant: 50),

            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            actionButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            actionButton.heightAnchor.constraint(equalToConstant: 50),

            label.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            
            arrowImageView.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            arrowImageView.trailingAnchor.constraint(equalTo: actionButton.trailingAnchor, constant: -16),
            arrowImageView.widthAnchor.constraint(equalToConstant: 24),
            arrowImageView.heightAnchor.constraint(equalToConstant: 24)
        ])

        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    // Action performed when the button is tapped
    @objc func buttonTapped() {
        if let url = URL(string: config.ctaButtonURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        print("[AR] Button tapped and URL opened.")
    }

    // Set up the loading indicator
    func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // Set up the loading label
    func setupLoadingLabel() {
        loadingLabel = UILabel()
        loadingLabel.text = config.loadingText
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.alpha = 0.0 // Start with 0 alpha
        view.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16)
        ])
    }

    func showLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, 
                  let loadingLabel = self.loadingLabel,
                  let loadingIndicator = self.loadingIndicator else {
                print("[AR] ⚠️ Cannot show loading animation - UI components not initialized")
                return
            }
            
            UIView.animate(withDuration: 0.3) {
                loadingLabel.alpha = 1.0
            }
        loadingIndicator.startAnimating()
            print("[AR] Loading animation started")
        }
    }

    func hideLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let loadingLabel = self.loadingLabel,
                  let loadingIndicator = self.loadingIndicator else {
                print("[AR] ⚠️ Cannot hide loading animation - UI components not initialized")
                return
            }
            
            UIView.animate(withDuration: 0.3) {
                loadingLabel.alpha = 0.0
            } completion: { _ in
        loadingIndicator.stopAnimating()
            }
            print("[AR] Loading animation hidden")
        }
    }

    // Hide the overlay (used when the image is detected)
    func hideOverlay() {
        overlayImageView.isHidden = true
        overlayLabel.isHidden = true
        print("[AR] Overlay hidden.")
    }

    // Show the overlay (used when the image is lost)
    func showOverlay() {
        DispatchQueue.main.async {
            self.overlayImageView.isHidden = false
            self.overlayLabel.isHidden = false
            print("[AR] Overlay shown.")
        }
    }

    // Show the button with a delay after the image is detected
    func showButtonWithDelay() {
        // Don't show button again if already shown
        guard !hasShownCTAButton else {
            print("[AR] 🔘 CTA button already shown, not showing again")
            return
        }
        
        // Use delay from config
        print("[AR] 🔘 Will show CTA button after \(config.ctaDelayMs) seconds with text: '\(config.ctaButtonText)'")
        
        // Ensure button text is updated with config value
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update button label with config text
            if let label = self.actionButton.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = self.config.ctaButtonText
                print("[AR] 📝 Updated button text to: '\(self.config.ctaButtonText)'")
            }
            
            // Update button color
            let hexColor = self.config.ctaButtonColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if let buttonColor = UIColor(hex: hexColor) {
                self.actionButton.backgroundColor = buttonColor
                print("[AR] 🎨 Updated button color to: \(self.config.ctaButtonColorHex)")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.ctaDelayMs) { [weak self] in
            guard let self = self else { return }
            self.hasShownCTAButton = true
            self.actionButton.isHidden = false
            print("[AR] 👆 Button displayed after delay: \(self.config.ctaDelayMs) seconds.")
        }
    }

    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please allow camera access to use AR features",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    // Add back the observer methods that were removed
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    print("[AR] Video is ready to play")
                case .failed:
                    print("[AR] Video failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    print("[AR] Video status is unknown")
                @unknown default:
                    break
                }
            }
        }
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.removeObserver(self)
        if let playerItem = videoPlayer?.currentItem {
            playerItem.removeObserver(self, forKeyPath: "status")
        }
        networkMonitor?.cancel()
        loadingTimer?.invalidate()
        loadingTimeoutTimer?.invalidate()
    }

    // Process URL from QR code or App Clip launch
    func processLaunchURL(_ url: URL) {
        print("[AR] 🌐 Processing launch URL: \(url.absoluteString)")
        
        // Debug: Log URL components
        print("[AR] 🔍 URL COMPONENTS:")
        print("[AR] 🔍 scheme: \(url.scheme ?? "nil")")
        print("[AR] 🔍 host: \(url.host ?? "nil")")
        print("[AR] 🔍 path: \(url.path)")
        print("[AR] 🔍 pathComponents: \(url.pathComponents)")
        
        // Extract folderID using multiple approaches
        var extractedFolderID: String? = nil
        
        // Approach 1: Parse path components
        if let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            print("[AR] 🔍 URL path components: \(pathComponents)")
            
            if pathComponents.count >= 2 && pathComponents[0] == "card" {
                extractedFolderID = pathComponents[1]
                print("[AR] ✅ Extracted folderID from path: \(pathComponents[1])")
            }
        }
        
        // Approach 2: Check for card in pathComponents
        if extractedFolderID == nil {
            let pathComponents = url.pathComponents.filter { !$0.isEmpty }
            if pathComponents.contains("card") {
                if let cardIndex = pathComponents.firstIndex(of: "card"), cardIndex + 1 < pathComponents.count {
                    extractedFolderID = pathComponents[cardIndex + 1]
                    print("[AR] ✅ Extracted folderID using alternative path method: \(pathComponents[cardIndex + 1])")
                }
            }
        }
        
        // Approach 3: Try subdomain extraction
        if extractedFolderID == nil, let host = url.host, host.contains(".") {
            let hostComponents = host.components(separatedBy: ".")
            if hostComponents.count >= 3 && hostComponents[1] == "adagxr" {
                extractedFolderID = hostComponents[0]
                print("[AR] ✅ Extracted folderID from subdomain: \(hostComponents[0])")
            }
        }
        
        // If we found a folderID, use it
        if let folderID = extractedFolderID {
            print("[AR] 🎯 FINAL FOLDER ID: \(folderID)")
            
            // Compare with our initial folderID
            if folderID != initialFolderID {
                print("[AR] ⚠️ URL folderID (\(folderID)) doesn't match initial folderID (\(initialFolderID))")
                print("[AR] 🔄 Will reload with correct folderID: \(folderID)")
                
                // Force a config reload with the correct folderID
                NotificationCenter.default.post(
                    name: NSNotification.Name("RequestConfigReloadNotification"),
                    object: nil,
                    userInfo: ["folderID": folderID]
                )
                return
            }
            
            // Store folderID for later use
            UserDefaults.standard.set(folderID, forKey: "folderID")
            print("[AR] 💾 Saved folderID to UserDefaults: \(folderID)")
            
            // Cancel any existing asset loading
            cancelAssetLoading()
            
            // Show loading animation only if UI is initialized
            if loadingLabel != nil && loadingIndicator != nil {
                showLoadingAnimation()
            } else {
                print("[AR] ⚠️ Cannot show loading animation - UI not initialized yet")
            }
            
            // Force clear caches
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
            UserDefaults.standard.removeObject(forKey: "cached_config")
            print("[AR] 🧹 Cleared all caches")
            
            // Explicitly log the expected config URL
            let configURL = "https://adagxr.com/card/\(folderID)/ar-img-config.json"
            print("[AR] 🔍 Will load configuration from \(configURL)")
            
            // Add cache-busting timestamp to URL
            let timestamp = Int(Date().timeIntervalSince1970)
            print("[AR] ⏰ Added cache-busting timestamp: \(timestamp)")
            
            // Load new configuration directly with ConfigManager
            ConfigManager.shared.loadConfig(folderID: folderID, configID: "ar-img-config") { [weak self] newConfig in
                guard let self = self else { return }
                
                // Check if the config has valid content or is empty (indicates failure)
                if !newConfig.targetImageUrl.isEmpty && !newConfig.videoURL.isEmpty {
                    print("[AR] ✅ Received valid configuration:")
                    print("[AR] - targetImageUrl: \(newConfig.targetImageUrl)")
                    print("[AR] - videoURL: \(newConfig.videoURL)")
                    print("[AR] - ctaButtonText: '\(newConfig.ctaButtonText)'")
                    
                    if newConfig.videoURL.contains("/ar/") && !newConfig.videoURL.contains("/ar1/") && folderID == "ar1" {
                        print("[AR] ⚠️ WARNING: Config contains default 'ar' URLs instead of 'ar1'!")
                    }
                    
                    DispatchQueue.main.async {
                        self.config = newConfig
                        self.logConfig()
                        self.applyConfig(newConfig)
                    }
                } else {
                    print("[AR] ❌ Received empty/invalid configuration, showing QR scanner")
                    DispatchQueue.main.async {
                        self.presentQRScannerWithMessage()
                    }
                }
            }
        } else {
            print("[AR] ❌ Could not extract folderID from URL: \(url.absoluteString)")
        }
    }
    
    // Apply configuration to the AR experience
    func applyConfig(_ newConfig: ARConfig) {
        print("[AR] Applying new configuration")
        
        // Update the current config
        config = newConfig
        
        // Update UI elements
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update loading text
            if let loadingLabel = self.loadingLabel {
                loadingLabel.text = newConfig.loadingText
                print("[AR] Updated loading text: \(newConfig.loadingText)")
            }
            
            // Update overlay text
            if let overlayLabel = self.overlayLabel {
                overlayLabel.text = newConfig.overlayText
                print("[AR] Updated overlay text: \(newConfig.overlayText)")
            }
            
            // Update button text and color
            if let button = self.actionButton {
                // Update button text
                if let label = button.subviews.compactMap({ $0 as? UILabel }).first {
                    label.text = newConfig.ctaButtonText
                    print("[AR] Updated button text: \(newConfig.ctaButtonText)")
                }
                
                // Update button color
                let hexColor = newConfig.ctaButtonColorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                if let buttonColor = UIColor(hex: hexColor) {
                    button.backgroundColor = buttonColor
                    print("[AR] Updated button color: \(newConfig.ctaButtonColorHex)")
                }
            }
            
            // Load overlay image from new config URL
            if let overlayImageView = self.overlayImageView, let imageURL = URL(string: newConfig.targetImageUrl) {
                print("[AR] Loading overlay image from: \(newConfig.targetImageUrl)")
                let imageView = overlayImageView // Create a local reference to avoid capturing self
                URLSession.shared.dataTask(with: imageURL) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            imageView.image = image
                            print("[AR] Successfully loaded overlay image")
                        }
                    } else if let error = error {
                        print("[AR] Failed to load overlay image: \(error.localizedDescription)")
                    }
                }.resume()
            }
            
            // Start or restart asset loading only if assets aren't already loaded
            if !self.areAssetsLoaded {
                self.startAssetLoading()
            }
        }
    }

    private func logConfig() {
        print("[AR] 📋 CURRENT CONFIG VALUES:")
        print("[AR] - targetImageUrl: \(config.targetImageUrl)")
        print("[AR] - videoURL: \(config.videoURL)")
        print("[AR] - videoWithTransparency: \(config.videoWithTransparency)")
        if config.videoWithTransparency {
            print("[AR] - videoRgbUrl: \(config.videoRgbUrl)")
            print("[AR] - videoAlphaUrl: \(config.videoAlphaUrl)")
        }
        print("[AR] - videoPlaneWidth: \(config.videoPlaneWidth)")
        print("[AR] - videoPlaneHeight: \(config.videoPlaneHeight)")
        print("[AR] - addedWidth: \(config.addedWidth ?? 1.0)")
        print("[AR] - addedHeight: \(config.addedHeight ?? 1.0)")
        print("[AR] - ctaButtonText: '\(config.ctaButtonText)'")
        print("[AR] - ctaButtonColorHex: \(config.ctaButtonColorHex)")
        print("[AR] - ctaButtonURL: \(config.ctaButtonURL)")
        print("[AR] - ctaDelayMs: \(config.ctaDelayMs)")
        print("[AR] - overlayText: '\(config.overlayText)'")
        print("[AR] - loadingText: '\(config.loadingText)'")
    }

    // MARK: - Present QR Scanner on Config Failure
    private func presentQRScannerWithMessage() {
        // Dismiss any presented view controllers first
        if let presented = self.presentedViewController {
            presented.dismiss(animated: false, completion: nil)
        }
        
        let qrVC = QRViewController()
        qrVC.modalPresentationStyle = .fullScreen
        qrVC.modalTransitionStyle = .crossDissolve
        self.present(qrVC, animated: true) {
            // Show the message after presentation
            qrVC.showUnsupportedQRCodeMessage()
        }
    }

}


