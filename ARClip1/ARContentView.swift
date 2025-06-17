import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import Network
import UIKit

struct ARContentView: UIViewControllerRepresentable {
    var launchURL: URL?
    
    func makeUIViewController(context: Context) -> UIViewController {
        // 1) If we got a valid deep-link URL and folderID, go straight to AR
        if let url = launchURL,
           let folderID = url.extractFolderID() {
            let arVC = ARViewController(folderID: folderID)
            arVC.launchURL = url
            return arVC
        }

        // 2) Otherwise show the QR scanner
        return QRViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates required
    }
}

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - Properties
    var sceneView: ARSCNView!
    var videoPlayer: AVPlayer?
    var transparentVideoPlayer: TransparentVideoPlayer?
    
    // Tracking states
    private var isVideoReady = false
    private var isImageTracked = false
    private var areAssetsLoaded = false
    private var hasShownCTAButton = false
    private var isUsingTransparentVideo = false
    
    // Loading and retry management
    private var retryCount = 0
    private let maxRetries = Constants.maxAssetRetries
    private let loadingTimeout: TimeInterval = Constants.loadingTimeout
    private var loadingTimer: Timer?
    private var loadingTimeoutTimer: Timer?
    
    // Scene elements
    private var referenceImage: ARReferenceImage?
    private var videoPlaneNode: SCNNode?
    
    // UI components
    var loadingView: LoadingView!
    var overlayView: OverlayView!
    var ctaView: CTAButtonView!
    var noInternetView: NoInternetView!
    
    // Legacy UI components (to be removed in future)
    var overlayImageView: UIImageView!
    var overlayLabel: UILabel!
    var loadingIndicator: UIActivityIndicatorView!
    var loadingLabel: UILabel!
    var retryButton: UIButton!
    var noInternetImageView: UIImageView!
    
    // Network
    private var networkMonitor: NWPathMonitor?
    
    // Analytics tracking
    private var experienceStartTime = Date()
    
    // MARK: - Configuration
    private var config: ARConfig?
    private var initialFolderID: String
    
    // Video plane dimensions
    var videoPlaneWidth: CGFloat = 17.086
    var videoPlaneHeight: CGFloat = 30.375

    var launchURL: URL? {
        didSet {
            if let url = launchURL {
                ARLog.debug("Launch URL set: \(url.absoluteString)")
                processLaunchURL(url)
            }
        }
    }

    // Custom initializer that accepts a folderID
    init(folderID: String) {
        self.initialFolderID = folderID
        super.init(nibName: nil, bundle: nil)
        ARLog.debug("Controller initialized with folderID: \(folderID)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Track screen view
        AnalyticsManager.shared.trackScreenView(screenName: "AR Experience", screenClass: "ARViewController")
        
        // Only proceed if launchURL was set
        guard launchURL != nil else { return }
        
        self.edgesForExtendedLayout = [.top, .bottom, .left, .right]
        
        // Initialize AR view with folderID
        ARLog.debug("Initializing AR view with folderID: \(initialFolderID)")
        
        // Register for notifications
        setupNotificationObservers()
        
        // Set up a debug check for config values
        scheduleConfigDebugCheck()
        
        checkCameraPermission()
        
        // Subscribe to network status changes
        setupNetworkMonitoring()
    }
    
    private func setupNotificationObservers() {
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
    }
        
    private func scheduleConfigDebugCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            
            ARLog.debug("🔍 DEBUG CHECK - Config values after 3 seconds:")
            self.logConfig()
            
            // Check if we're using the wrong folder based on environment or launch URL
            if let url = self.launchURL {
                let currentURLFolder = url.extractFolderID()
                let configURLFolder = self.config?.targetImageUrl != nil ? 
                    URL.extractFolderID(from: self.config!.targetImageUrl.absoluteString) : nil
                
                ARLog.debug("🔍 URL folder: \(currentURLFolder ?? "unknown"), Config folder: \(configURLFolder ?? "unknown")")
                
                if let urlFolder = currentURLFolder, 
                   let configFolder = configURLFolder,
                   urlFolder != configFolder {
                    ARLog.debug("🔄 Debug check detected mismatch: URL has \(urlFolder) but config has \(configFolder) - requesting config reload")
                    // Trigger a reload
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RequestConfigReloadNotification"),
                        object: nil
                    )
            }
        }
        }
    }
    
    @objc private func configLoaded(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? ARConfig {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let isNewConfig = self.config?.targetImageUrl != config.targetImageUrl
                ARLog.debug("🔍 CONFIG DIAGNOSIS:")
                ARLog.debug("🔍 Previous targetImageUrl: \(self.config?.targetImageUrl.absoluteString ?? "nil")")
                ARLog.debug("🔍 New targetImageUrl: \(config.targetImageUrl)")
                ARLog.debug("🔍 Is new config: \(isNewConfig)")
                ARLog.debug("🔍 Button text: '\(config.ctaButtonText ?? "nil")'")
                ARLog.debug("🔍 Video URL: \(config.videoURL)")
                ARLog.debug("🔍 OverlayText: '\(config.overlayText)'")
                ARLog.debug("🔍 Dimensions: \(config.videoPlaneWidth) x \(config.videoPlaneHeight)")
                
                if config.videoURL.contains("/ar/") && !config.videoURL.contains("/ar1/") {
                    ARLog.warning("Using default 'ar' folder instead of 'ar1' folder!")
                }
                
                // Track config loaded event
                AnalyticsManager.shared.trackEvent(name: "AR Config Loaded", properties: [
                    "folder_id": self.initialFolderID,
                    "is_new_config": isNewConfig,
                    "has_video_url": !config.videoURL.isEmpty,
                    "has_image_url": config.targetImageUrl.absoluteString.isEmpty == false
                ])
                
                // Store the new config
                self.config = config
                
                // Apply the configuration using ConfigApplier
                ConfigApplier.apply(config, to: self)
                
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
            ARLog.debug("APP RUNNING QR SCAN - Received config change to folderID: \(folderID)")
            
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
            
            // Load the config from the server instead of using a default
            ConfigManager.shared.loadConfiguration(folderID: folderID) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let config):
                    DispatchQueue.main.async {
                        self.config = config
                        // Apply configuration with ConfigApplier
                        ConfigApplier.apply(config, to: self)
            
            // Force URLCache clear for new domain
            URLCache.shared.removeAllCachedResponses()
            
            // Reload assets with new config
                        self.startAssetLoading()
            
                        ARLog.debug("Config loaded for folderID: \(folderID)")
                    }
                
                case .failure(let error):
                    ARLog.error("Failed to load config for folderID \(folderID): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        QRScannerHelper.openQRScanner(from: self)
                    }
                }
            }
        }
    }

    @objc private func folderIDUpdated() {
        ARLog.debug("🔄 Received folderID update notification")
        
        if let folderID = UserDefaults.standard.string(forKey: "folderID") {
            ARLog.debug("🔄 Updating to folderID: \(folderID)")
            
            // Add additional validation to ensure folderID isn't corrupted
            if folderID.isEmpty {
                ARLog.warning("Empty folderID received, showing QR scanner")
                QRScannerHelper.openQRScanner(from: self)
                return
            }
            
            ARLog.debug("✨ Using folderID: \(folderID)")
            
            // Cancel any existing asset loading
            cancelAssetLoading()
            
            // Show loading animation (only if UI is initialized)
            if loadingView != nil {
                showLoadingAnimation()
                } else {
                ARLog.warning("Cannot show loading animation - UI not initialized yet")
            }
            
            // Force clear caches
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
            UserDefaults.standard.removeObject(forKey: "cached_config")
            ARLog.debug("🧹 Cleared all caches before loading config")
            
            // Explicitly log the expected config URL
            let configURL = "\(Constants.baseCardURL)/\(folderID)/\(Constants.configFilename)"
            ARLog.debug("🔍 Will load configuration from \(configURL)")
            
            // Add cache-busting timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            ARLog.debug("⏰ Added cache-busting timestamp: \(timestamp)")
            
            // Load config with direct ConfigManager call with success/failure handling
            ConfigManager.shared.loadConfiguration(folderID: folderID) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let config):
                    ARLog.debug("✅ Successfully loaded configuration:")
                    ARLog.debug("- targetImageUrl: \(config.targetImageUrl)")
                    ARLog.debug("- videoURL: \(config.videoURL)")
                    ARLog.debug("- ctaButtonText: '\(config.ctaButtonText ?? "nil")'")
                    
                    if config.videoURL.contains("/ar/") && !config.videoURL.contains("/\(folderID)/") {
                        ARLog.warning("Config contains generic 'ar' URLs instead of '\(folderID)'!")
                    }
                    
                    DispatchQueue.main.async {
                        self.config = config
                        ConfigApplier.apply(config, to: self)
                    }
                    
                case .failure(let error):
                    ARLog.error("Failed to load configuration: \(error.localizedDescription)")
                    ARLog.debug("🔄 Showing QR scanner due to config load failure")
                    
                    DispatchQueue.main.async {
                        QRScannerHelper.openQRScanner(from: self)
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
        ARLog.debug("Cancelling previous asset loading")
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
                guard let self = self else { return }
                
                if granted {
                    // Setup camera feed
                    self.setupCameraFeed()
                } else {
                    self.showCameraPermissionAlert()
        }
            }
        }
    }

    private func setupCameraFeed() {
        // Initialize ARSCNView
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .black
        sceneView.automaticallyUpdatesLighting = false
        view.addSubview(sceneView)
        
        // Make sure sceneView is at the back of the view hierarchy
        view.sendSubviewToBack(sceneView)
        
        // Create AR configuration
        let configuration = ARImageTrackingConfiguration()
        configuration.isAutoFocusEnabled = true
        configuration.maximumNumberOfTrackedImages = 1
        
        sceneView.session.run(configuration)

        // Setup UI elements
        setupUIElements()
        
        // Show loading indicator
        showLoadingAnimation()
        
        // Setup audio session
        setupAudioSession()
        
        // Setup network monitoring
        setupNetworkMonitoring()
    }
    
    private func setupUIElements() {
        setupOverlay()
        setupCTAView()
        setupLoadingView()
        setupNoInternetView()

        // Initially hide all UI elements
        overlayView.hide()
        noInternetView.isHidden = true
        
        // Apply initial configuration to UI elements
        ConfigApplier.apply(config, to: self)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            ARLog.debug("AVAudioSession configured for playback")
        } catch {
            ARLog.error("Failed to set up AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    private func startAssetLoading() {
        guard let config = self.config, !config.targetImageUrl.absoluteString.isEmpty else {
            ARLog.error("Cannot start asset loading: targetImageUrl is empty")
            return
        }
        
        ARLog.debug("Starting asset loading with config: \(config.targetImageUrl)")
        
        // Log the current configuration
        logConfig()
        
        // Start loading animation
        showLoadingAnimation()
        
        // Track asset download start
        let assetTypes = ["reference_image"] + (config.videoWithTransparency ? 
            ["rgb_video", "alpha_video"] : ["standard_video"])
        
        AnalyticsManager.shared.trackAssetDownloadStart(
            folderID: initialFolderID,
            assetTypes: assetTypes
        )
        
        let downloadStartTime = Date()
        
        // Create an ARAssetLoader to handle asset loading
        let loader = ARAssetLoader(config: config)
            let group = DispatchGroup()
            
        var loadedImage: ARReferenceImage?
        var loadedVideo: VideoLoadingResult?
        var loadError: Error?
        
        // Load reference image
            group.enter()
        var imageCompleted = false
        loader.loadReferenceImage { result in
            if !imageCompleted {
                imageCompleted = true
                
            switch result {
            case .success(let image): 
                loadedImage = image
            case .failure(let error): 
                loadError = error
                ARLog.error("Failed to load reference image: \(error.localizedDescription)")
            }
                
                group.leave()
            }
            }
            
        // Load video
            group.enter()
        var videoCompleted = false
        loader.loadVideo { result in
            if !videoCompleted {
                videoCompleted = true
                
            switch result {
            case .success(let videoResult): 
                loadedVideo = videoResult
            case .failure(let error): 
                loadError = error
                ARLog.error("Failed to load video: \(error.localizedDescription)")
            }
                
                group.leave()
            }
            }
            
            // When both are done
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Calculate download duration
            let downloadDuration = Date().timeIntervalSince(downloadStartTime)
            
            if let error = loadError {
                ARLog.error("Asset loading failed: \(error.localizedDescription)")
                
                // Track failed download
                AnalyticsManager.shared.trackAssetDownloadComplete(
                    folderID: self.initialFolderID,
                    assetTypes: assetTypes,
                    duration: downloadDuration,
                    success: false,
                    errorMessage: error.localizedDescription
                )
                
                self.handleFailedAssetLoading()
            return
        }
        
            guard let referenceImage = loadedImage, let videoResult = loadedVideo else {
                ARLog.error("Asset loading incomplete")
                
                // Track failed download
                AnalyticsManager.shared.trackAssetDownloadComplete(
                    folderID: self.initialFolderID,
                    assetTypes: assetTypes,
                    duration: downloadDuration,
                    success: false,
                    errorMessage: "Incomplete asset loading"
                )
                
                self.handleFailedAssetLoading()
                return
            }
            
            // Track successful download
            AnalyticsManager.shared.trackAssetDownloadComplete(
                folderID: self.initialFolderID,
                assetTypes: assetTypes,
                duration: downloadDuration,
                success: true
            )
            
            // Store the reference image
            self.referenceImage = referenceImage
            
            // Setup appropriate video player based on the result
            switch videoResult {
            case .standard(let player):
                self.videoPlayer = player
                self.isUsingTransparentVideo = false
                
            case .transparent(let player):
                self.transparentVideoPlayer = player
                self.isUsingTransparentVideo = true
            }
            
            // Mark video as ready
            self.isVideoReady = true
            
            // Process loaded assets
            self.handleAssetsLoaded()
        }
    }
    
    private func handleAssetsLoaded() {
        guard let referenceImage = self.referenceImage else { 
            ARLog.error("ERROR: No reference image loaded")
            return
        }
        
        if !isVideoReady {
            ARLog.warning("Video is not yet ready, waiting for video...")
            // Show loading state until video is ready
            showLoadingAndRetryLater()
            return
        }
        
        ARLog.debug("✅ All assets fully loaded, proceeding to AR experience")
            
        // Update AR configuration with loaded reference image
                let configuration = ARImageTrackingConfiguration()
                configuration.isAutoFocusEnabled = true
                configuration.trackingImages = [referenceImage]
                configuration.maximumNumberOfTrackedImages = 1
                
        // First, hide loading to improve UI responsiveness
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                
            // Hide loading animation and ensure it's fully removed
                    self.hideLoadingAnimation()
            self.loadingView?.isHidden = true
            
            // Apply config to update UI elements
            ConfigApplier.applyOverlayView(self.config, to: self)
            
            // Show scan overlay with appropriate text
            if let overlayView = self.overlayView {
                overlayView.show()
                ARLog.debug("👁️ Showing 'Scan this image' overlay")
            } else {
                ARLog.warning("Cannot show overlay - UI not initialized")
            }
            
            // Add small delay before updating AR session to prevent lag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Only update session if sceneView is initialized
                if let sceneView = self.sceneView {
                    // Update session configuration
                sceneView.session.run(configuration, options: [.removeExistingAnchors])
                    self.areAssetsLoaded = true
                    ARLog.debug("🎯 AR session started and ready for tracking")
                } else {
                    ARLog.warning("Cannot update AR session - sceneView not initialized")
                }
            }
        }
    }
    
    private func showLoadingAndRetryLater() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.loadingView != nil {
                self.showLoadingAnimation()
                // Use a temporary config object for loading state if needed
                if self.config == nil {
                    let tempConfig = ARConfig(
                        scanningTextContent: "Scan this image",
                        loadingText: "Preparing your experience",
                        targetImageUrl: URL(string: "")!,
                        overlayOpacity: 1.0,
                        videoWithTransparency: false,
                        videoRgbUrl: URL(string: ""),
                        videoAlphaUrl: URL(string: ""),
                        actualTargetImageWidthMeters: 0.1,
                        videoPlaneWidth: 1.0,
                        videoPlaneHeight: 1.41431,
                        ctaVisible: true,
                        ctaButtonText: "",
                        ctaButtonColorHex: "#F84B07",
                        ctaDelayMs: 1000,
                        ctaButtonURL: URL(string: "https://effectizationstudio.com")
                    )
                    ConfigApplier.applyLoadingView(tempConfig, to: self)
                } else {
                    ConfigApplier.applyLoadingView(self.config, to: self)
                }
            } else {
                ARLog.warning("Cannot update loading state - UI not initialized")
            }
            
            // Try again in 0.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.handleAssetsLoaded()
            }
        }
    }

    private func handleFailedAssetLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Hide loading animation
            self.hideLoadingAnimation()
            
            // Show appropriate UI based on network status
            if NetworkMonitor.shared.isConnected {
                // Network is up but asset loading failed -> Show QR scanner
                QRScannerHelper.openQRScanner(from: self)
            } else {
                // Network is down -> Show network error view
                self.showNetworkErrorView()
            }
        }
    }

    private func setupNetworkMonitoring() {
        NetworkMonitor.shared.onStatusChange = { [weak self] isConnected in
            guard let self = self else { return }
            
            if isConnected {
                // Network is back online
                if let url = self.launchURL, let _ = url.extractFolderID() {
                    // Valid URL: retry AR
                    self.hideNetworkError()
                    self.processLaunchURL(url)
                } else {
                    // Invalid URL: show QR scanner
                    QRScannerHelper.openQRScanner(from: self)
                }
            } else {
                // Network went offline
                if !self.areAssetsLoaded {
                    // Only show error if we're still loading
                    self.showNetworkErrorView()
                }
            }
        }
        
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Only show network error if we have a config with valid URLs but can't load them
                let hasValidConfig = self.config != nil && 
                    !self.config!.targetImageUrl.absoluteString.isEmpty && 
                    !self.config!.videoURL.isEmpty
                
                if path.status == .satisfied {
                    ARLog.debug("Network connection available")
                    // If we have a config and aren't showing assets yet, retry loading
                    if hasValidConfig && !self.areAssetsLoaded {
                        ARLog.debug("Retry loading assets with valid config")
                        self.hideNetworkError()
                        self.retryLoadingAssets()
                    }
                } else if hasValidConfig {
                    // Only show the error if we have a valid config but no network
                    ARLog.debug("Network connection unavailable")
                    if !self.areAssetsLoaded {
                        self.showNetworkError()
                    }
                } else {
                    ARLog.debug("Waiting for configuration before checking network requirement")
                    // Show loading state if we don't have a config yet
                    self.hideNetworkError()
            }
        }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }

    private func retryLoadingAssets() {
        guard !areAssetsLoaded else { return }
        
        // Ensure we're showing the loading state
        hideNetworkError()
        
        ARLog.debug("Retrying asset loading with config: \(config?.targetImageUrl.absoluteString ?? "")")
        
        // First check if we have valid config
        if config?.targetImageUrl.absoluteString.isEmpty == true || config?.videoURL.isEmpty == true {
            ARLog.debug("Cannot load assets without valid config")
            return
        }
        
        // Use ARAssetLoader to load assets
        startAssetLoading()
    }

    private func startLoadingTimeout() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadingTimeout()
        }
    }

    private func handleLoadingTimeout() {
        ARLog.debug("Loading timeout reached")
        showNetworkError()
    }

    private func showNetworkError() {
        guard !areAssetsLoaded else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.hideLoadingAnimation()
            self.overlayView.hide()
            self.noInternetView.show()
        }
    }

    private func hideNetworkError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.noInternetView.hide()
                    self.showLoadingAnimation()
                }
    }

    private func showMaxRetriesReached() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Just keep showing the no internet view
            self.noInternetView.show()
        }
    }

    private func setupNoInternetView() {
        noInternetView = NoInternetView(frame: view.bounds)
        noInternetView.translatesAutoresizingMaskIntoConstraints = false
        noInternetView.isHidden = true
        
        // Set up retry callback
        noInternetView.onRetry = { [weak self] in
            guard let self = self else { return }
            ARLog.debug("Retry button tapped")

            // Try loading config again
            if let url = self.launchURL {
                ARLog.debug("Re-processing launch URL: \(url)")
                self.hideNetworkError()
                self.processLaunchURL(url)
            } else {
                // If no URL available, try with current config
                if self.config != nil && 
                   (self.config?.targetImageUrl.absoluteString.isEmpty == false) && 
                   (self.config?.videoURL.isEmpty == false) {
                    self.hideNetworkError()
                    self.retryLoadingAssets()
                } else {
                    // Post a notification to reload config
                    ARLog.debug("Requesting config reload")
                    self.hideNetworkError()
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RequestConfigReloadNotification"),
                        object: nil
                    )
                }
            }
        }
        
        view.addSubview(noInternetView)

        // Portrait-only constraints
        NSLayoutConstraint.activate([
            // Container view
            noInternetView.topAnchor.constraint(equalTo: view.topAnchor),
            noInternetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noInternetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noInternetView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
            }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        noInternetView?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runARSession()
            ARLog.debug("AR session started.")
            }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the video when view disappears
        if isUsingTransparentVideo {
            transparentVideoPlayer?.pause()
        } else {
            videoPlayer?.pause()
        }
        sceneView.session.pause()
        ARLog.debug("AR session paused.")
        }

    func runARSession() {
        guard ARImageTrackingConfiguration.isSupported else {
            ARLog.debug("AR Image tracking is not supported on this device")
            return
        }
        
        // Ensure sceneView is initialized
        guard sceneView != nil else {
            ARLog.debug("ARSCNView not initialized")
            return
        }
        
        // Start asset loading to prepare AR experience
        startAssetLoading()
    }

    // Called when the AR session updates anchors (used to check tracking status)
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor,
                  imageAnchor.referenceImage.name == "targetImage" else { continue }
            
                let isTracking = imageAnchor.isTracked
                let trackingStateChanged = isTracking != self.isImageTracked
                
            // Only track state changes instead of continuous updates
                if trackingStateChanged {
                // Track analytics when tracking state changes
                    AnalyticsManager.shared.trackEvent(name: "AR Image Tracking Update", properties: [
                        "folder_id": initialFolderID,
                        "is_tracking": isTracking,
                        "time_in_experience_seconds": Date().timeIntervalSince(experienceStartTime)
                    ])
            
                if !isTracking && self.isImageTracked {
                    // Image tracking lost
                    handleTrackingLost()
                    ARLog.debug("Image tracking lost - video paused")
                } else if isTracking && !self.isImageTracked {
                    // Image tracking gained or regained
                    handleTrackingGained(imageAnchor: imageAnchor)
                    ARLog.debug("Image tracking gained - resuming video")
                }
            }
        }
    }

    private func handleTrackingLost() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            ARLog.debug("Image tracking lost. Showing overlay and pausing video.")
            
            // Track tracking lost event
            AnalyticsManager.shared.pauseTrackingSession()
            AnalyticsManager.shared.pauseVideoPlayback()
            
            // Only perform actions if state has actually changed
            if self.isImageTracked {
                self.isImageTracked = false
                
                // Ensure UI updates happen first
                self.showOverlay()
                
                // Then handle video pause
                if self.isUsingTransparentVideo {
                    self.transparentVideoPlayer?.pause()
                    ARLog.debug("Transparent video paused")
                } else if let player = self.videoPlayer {
                    // Ensure smooth pause
                    player.rate = 0.0
                    player.pause()
                    ARLog.debug("Video paused")
                }
            }
        }
    }
    
    private func handleTrackingGained(imageAnchor: ARImageAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            ARLog.debug("Image detected/re-detected. Hiding overlay and playing video.")
            
            // Check if this is the first detection
            let isFirstDetection = !self.hasShownCTAButton && !self.isImageTracked
            
            // Track tracking gained event
            AnalyticsManager.shared.startTrackingSession()
            
            if isFirstDetection {
                // Track first image detection
                AnalyticsManager.shared.trackFirstImageDetection(folderID: self.initialFolderID)
            }
            
            // Only perform actions if state has actually changed
            if !self.isImageTracked {
                self.isImageTracked = true
                
                // Add a small delay before resuming playback to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Ensure loading view is hidden first
                    self.hideLoadingAnimation()
                    self.hideOverlay()
                    
                    // Resume video playback
                    if self.isUsingTransparentVideo {
                        AnalyticsManager.shared.startVideoPlayback()
                        // Ensure video plane exists
                        if self.videoPlaneNode == nil {
                            ARLog.debug("Recreating video plane for transparent video")
                            if let node = self.sceneView.node(for: imageAnchor) {
                                self.createVideoPlane(for: node, with: imageAnchor)
                            }
                        }
                        
                        // Only seek to start if this is first detection
                        if isFirstDetection {
                            self.transparentVideoPlayer?.play()
                        } else {
                            // Just resume from current position
                            self.transparentVideoPlayer?.resume()
                        }
                        ARLog.debug(isFirstDetection ? "Starting transparent video from beginning" : "Resuming transparent video from current position")
                    } else if let player = self.videoPlayer {
                        // Only seek to start if this is first detection
                        if isFirstDetection {
                            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                player.rate = 1.0
                                player.play()
                            }
                            ARLog.debug("First detection - starting video from beginning")
                        } else {
                            // Just resume from current position
                            player.rate = 1.0
                            player.play()
                            ARLog.debug("Image re-detected - resuming video from current position")
                        }
                        AnalyticsManager.shared.startVideoPlayback()
                    }
                    
                    // Show CTA button if needed
                    if !self.hasShownCTAButton {
                        self.showButtonWithDelay()
                    }
                }
            }
        }
    }

    // Optional method to handle anchor removal
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let imageAnchor = anchor as? ARImageAnchor else { continue }
            
            if imageAnchor.referenceImage.name == "targetImage" {
                // Track anchor removal with analytics
                AnalyticsManager.shared.trackEvent(name: "AR Image Anchor Removed", properties: [
                    "folder_id": initialFolderID
                ])
                
                DispatchQueue.main.async {
                    ARLog.debug("Image anchor removed. Image is no longer being tracked.")
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
        ctaView?.isHidden = true
        
        // Remove existing video plane
        videoPlaneNode?.removeFromParentNode()
        videoPlaneNode = nil
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        ARLog.debug("AR session reset.")
    }

    // MARK: - ARSCN View Delegate
    // This method is called when an anchor is detected and a node is added to the scene
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Only proceed if an image anchor was detected
        guard let imageAnchor = anchor as? ARImageAnchor else {
            ARLog.debug("Anchor detected but it's not an image anchor")
            return
        }
        
        // Check if video is ready
            if !isVideoReady {
            ARLog.debug("Image detected but video player not ready")
            // If the image is detected but video isn't ready, try reloading assets
            ARLog.debug("Attempting to reload assets")
            startAssetLoading()
            return
        }
        
        createVideoPlane(for: node, with: imageAnchor)
    }
    
    // Extract video plane creation to a separate method
    private func createVideoPlane(for node: SCNNode, with imageAnchor: ARImageAnchor) {
            // Remove previous video plane if it exists
            videoPlaneNode?.removeFromParentNode()
            videoPlaneNode = nil
        
        // Check if we're using transparent video
        if isUsingTransparentVideo, let transparentPlayer = self.transparentVideoPlayer {
            createTransparentVideoPlane(for: node, with: imageAnchor, using: transparentPlayer)
            return
        }

        // Standard video mode - HLS stream (non-transparent)
        guard let videoPlayer = self.videoPlayer else {
            ARLog.debug("Cannot create video plane: no video player")
            return
        }
        
        ARLog.debug("🎬 Creating video plane for HLS stream")
        
        // Configure video player to loop
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: videoPlayer.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: videoPlayer.currentItem)
            
            // 1) Compute final dimensions from config
            let baseSize = config?.actualTargetImageWidthMeters ?? 0.1
            let widthMeters = baseSize * (config?.videoPlaneWidth ?? 1.0)
            let heightMeters = baseSize * (config?.videoPlaneHeight ?? 1.0)
        
            // 2) Create a custom SCNPlane
            let videoPlane = SCNPlane(width: widthMeters, height: heightMeters)
            
        // Create a material for the plane with the video player
        let videoMaterial = SCNMaterial()
        videoMaterial.diffuse.contents = videoPlayer
        videoMaterial.isDoubleSided = true
        
        // Set transparency mode based on config
        if config?.videoWithTransparency == true {
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
        ARLog.debug("📐 Creating video plane with dimensions: \(widthMeters) x \(heightMeters)")
            ARLog.debug("📐 Base size: \(baseSize), multipliers: \(config?.videoPlaneWidth ?? 1.0) x \(config?.videoPlaneHeight ?? 1.0)")
        ARLog.debug("🎥 Setting video player as plane material contents, videoWithTransparency: \(config?.videoWithTransparency == true)")
        
        // Apply the material to the plane
        videoPlane.materials = [videoMaterial]
        
            // 3) Create and orient the node
        let planeNode = SCNNode(geometry: videoPlane)
        
        // Position the node at the anchor's center
        planeNode.eulerAngles.x = -.pi / 2  // Rotate to face the camera
                
            // Store the plane node reference
            videoPlaneNode = planeNode
        
        // Add the plane node to the anchor's node
        node.addChildNode(planeNode)
        
        // Handle video playback immediately if the image is being tracked
        handleVideoPlayback(imageAnchor: imageAnchor, player: videoPlayer)
    }

    private func createTransparentVideoPlane(for node: SCNNode, with imageAnchor: ARImageAnchor, using player: TransparentVideoPlayer) {
        ARLog.debug("🎬 Creating video plane with transparent RGB+Alpha video")
        
        // Remove previous video plane if it exists
        videoPlaneNode?.removeFromParentNode()
        videoPlaneNode = nil
        
        // 1) Compute final dimensions from config
        let baseSize = config?.actualTargetImageWidthMeters ?? 0.1
        let widthMeters = baseSize * (config?.videoPlaneWidth ?? 1.0)
        let heightMeters = baseSize * (config?.videoPlaneHeight ?? 1.0)
        
        // 2) Create a custom SCNPlane
        let videoPlane = SCNPlane(width: widthMeters, height: heightMeters)
        
        // Get material from transparent video player
        let videoMaterial = player.getMaterial()
    
        // Print debug info
        ARLog.debug("📐 Creating transparent video plane with dimensions: \(widthMeters) x \(heightMeters)")
        ARLog.debug("📐 Base size: \(baseSize), multipliers: \(config?.videoPlaneWidth ?? 1.0) x \(config?.videoPlaneHeight ?? 1.0)")
        
        // Apply the material to the plane
        videoPlane.materials = [videoMaterial]
        
        // 3) Create and orient the node
        let planeNode = SCNNode(geometry: videoPlane)
        
        // Position the node at the anchor's center
        planeNode.eulerAngles.x = -.pi / 2  // Rotate to face the camera
        
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
                
                // Check if we need to show the CTA button
                let needsToShowCTAButton = !self.hasShownCTAButton
                
                // Add a small delay to smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Ensure loading view is hidden
                    self.hideLoadingAnimation()
                    
                    // Start playing the video
                    player.play()
                    
                    // Hide overlay and show button
                    self.hideOverlay()
                    if needsToShowCTAButton {
                    self.showButtonWithDelay()
                    }
                    
                    ARLog.debug("✅ Transparent video playback resumed")
                }
            } else {
                // Image might not be tracked yet
                ARLog.debug("⚠️ Image anchor added but not yet tracked")
                player.pause()
                self.isImageTracked = false
                self.showOverlay()
        }
        }
    }

    // Set up the overlay image and label displayed initially
    func setupOverlay() {
        overlayView = OverlayView(frame: view.bounds)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set initial text from config using ConfigApplier
        // We'll apply the full config later, just initialize with empty state
        overlayView.hide() // Start hidden
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // Set up the CTA button view
    private func setupCTAView() {
        ctaView = CTAButtonView(frame: .zero)
        ctaView.translatesAutoresizingMaskIntoConstraints = false
        ctaView.isHidden = true
        view.addSubview(ctaView)

        NSLayoutConstraint.activate([
            ctaView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ctaView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            ctaView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            ctaView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Initial configuration will be applied later
    }

    // Set up the loading view
    private func setupLoadingView() {
        loadingView = LoadingView(frame: view.bounds)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = true
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.topAnchor.constraint(equalTo: view.topAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func showLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, 
                  let loadingView = self.loadingView else {
                ARLog.warning("Cannot show loading animation - UI components not initialized")
                return
            }
            
            // Apply loading text from config
            ConfigApplier.applyLoadingView(self.config, to: self)
            loadingView.start(with: self.config?.loadingText ?? "Loading...")
            ARLog.debug("Loading animation started")
        }
    }

    func hideLoadingAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let loadingView = self.loadingView else {
                ARLog.warning("Cannot hide loading animation - UI components not initialized")
                return
            }
            
            loadingView.stop()
            loadingView.isHidden = true
            ARLog.debug("Loading animation hidden")
        }
    }

    // Hide the overlay (used when the image is detected)
    func hideOverlay() {
        overlayView.hide()
        ARLog.debug("Overlay hidden.")
    }

    // Show the overlay (used when the image is lost)
    func showOverlay() {
        DispatchQueue.main.async {
            self.overlayView.show()
            ARLog.debug("Overlay shown.")
        }
    }

    // Show the button with a delay after the image is detected
    func showButtonWithDelay() {
        // Don't show button again if already shown
        guard !hasShownCTAButton else {
            ARLog.debug("🔘 CTA button already shown, not showing again")
            return
        }
        
        // Use delay from config
        ARLog.debug("🔘 Will show CTA button after \(config?.ctaDelayMs ?? 0) seconds with text: '\(config?.ctaButtonText ?? "No text")'")
        
        // Update button configuration with ConfigApplier
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Use ConfigApplier to apply just the button configuration
            ConfigApplier.applyCTAButton(self.config, to: self)
        }
        
        // Show button after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval((config?.ctaDelayMs ?? 0)/1000)) { [weak self] in
            guard let self = self else { return }
            self.hasShownCTAButton = true
            self.ctaView.show()
            
            // Track CTA button displayed
            AnalyticsManager.shared.trackCTAButtonDisplayed(
                buttonText: self.config?.ctaButtonText ?? "Unknown"
            )
            
            ARLog.debug("👆 Button displayed after delay: \(self.config?.ctaDelayMs ?? 0) seconds.")
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
                    ARLog.debug("Video is ready to play")
                case .failed:
                    ARLog.error("Video failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    ARLog.debug("Video status is unknown")
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
        // Clean up all video player resources
        videoPlayer?.pause()
        videoPlayer = nil
        transparentVideoPlayer?.pause()
        transparentVideoPlayer = nil
        networkMonitor?.cancel()
        loadingTimer?.invalidate()
        loadingTimeoutTimer?.invalidate()
    }

    // Process URL from QR code or App Clip launch
    func processLaunchURL(_ url: URL) {
        ARLog.debug("🌐 Processing launch URL: \(url.absoluteString)")
        
        // Debug: Log URL components
        logURLComponents(url)
        
        // Extract folderID using URL extension
        guard let folderID = url.extractFolderID() else {
            ARLog.error("Could not extract folderID from URL: \(url.absoluteString)")
            DispatchQueue.main.async {
                QRScannerHelper.openQRScanner(from: self)
            }
            return
        }
        
            ARLog.debug("🎯 FINAL FOLDER ID: \(folderID)")
            
            // Compare with our initial folderID
            if folderID != initialFolderID {
                ARLog.debug("⚠️ URL folderID (\(folderID)) doesn't match initial folderID (\(initialFolderID))")
                ARLog.debug("🔄 Will reload with correct folderID: \(folderID)")
                
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
            ARLog.debug("💾 Saved folderID to UserDefaults: \(folderID)")
            
            // Cancel any existing asset loading
            cancelAssetLoading()
            
            // Show loading animation only if UI is initialized
            if loadingView != nil {
                showLoadingAnimation()
            } else {
                ARLog.warning("Cannot show loading animation - UI not initialized yet")
            }
            
        // Clear caches and prepare for fresh load
        clearCachesAndPrepare(folderID)
        
        // Load new configuration directly with ConfigManager
        loadConfiguration(folderID)
    }
    
    private func logURLComponents(_ url: URL) {
        ARLog.debug("🔍 URL COMPONENTS:")
        ARLog.debug("🔍 scheme: \(url.scheme ?? "nil")")
        ARLog.debug("🔍 host: \(url.host ?? "nil")")
        ARLog.debug("🔍 path: \(url.path)")
        ARLog.debug("🔍 pathComponents: \(url.pathComponents)")
    }
    
    private func clearCachesAndPrepare(_ folderID: String) {
            // Force clear caches
            URLCache.shared.removeAllCachedResponses()
            UserDefaults.standard.removeObject(forKey: "config_cache_timestamp")
            UserDefaults.standard.removeObject(forKey: "cached_config")
        ARLog.debug("🧹 Cleared all caches")
            
            // Explicitly log the expected config URL
            let configURL = "\(Constants.baseCardURL)/\(folderID)/\(Constants.configFilename)"
            ARLog.debug("🔍 Will load configuration from \(configURL)")
            
            // Add cache-busting timestamp to URL
            let timestamp = Int(Date().timeIntervalSince1970)
            ARLog.debug("⏰ Added cache-busting timestamp: \(timestamp)")
    }
            
    private func loadConfiguration(_ folderID: String) {
            ConfigManager.shared.loadConfiguration(folderID: folderID) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let config):
                    ARLog.debug("✅ Received configuration:")
                    ARLog.debug("- targetImageUrl: \(config.targetImageUrl)")
                    ARLog.debug("- videoURL: \(config.videoURL)")
                    ARLog.debug("- ctaButtonText: '\(config.ctaButtonText ?? "nil")'")
                
                    if config.videoURL.contains("/ar/") && !config.videoURL.contains("/\(folderID)/") {
                        ARLog.warning("Config contains generic 'ar' URLs instead of '\(folderID)'!")
                }
                
                DispatchQueue.main.async {
                        self.config = config
                        self.logConfig()
                        ConfigApplier.apply(config, to: self)
                        
                        // Start asset loading if needed
                        if !self.areAssetsLoaded {
                            self.startAssetLoading()
                        }
                    }
                    
                case .failure(let error):
                    ARLog.error("Failed to load configuration: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        QRScannerHelper.openQRScanner(from: self)
                    }
        }
    }
    }
    
    private func logConfig() {
        ARLog.debug("📋 CURRENT CONFIG VALUES:")
        ARLog.debug("- targetImageUrl: \(config?.targetImageUrl.absoluteString ?? "nil")")
        ARLog.debug("- videoURL: \(config?.videoURL ?? "nil")")
        ARLog.debug("- videoWithTransparency: \(config?.videoWithTransparency == true)")
        if config?.videoWithTransparency == true {
            ARLog.debug("- videoRgbUrl: \(config?.videoRgbUrl?.absoluteString ?? "nil")")
            ARLog.debug("- videoAlphaUrl: \(config?.videoAlphaUrl?.absoluteString ?? "nil")")
        }
        ARLog.debug("- videoPlaneWidth: \(config?.videoPlaneWidth ?? 0.0)")
        ARLog.debug("- videoPlaneHeight: \(config?.videoPlaneHeight ?? 0.0)")
        ARLog.debug("- actualTargetImageWidthMeters: \(config?.actualTargetImageWidthMeters ?? 0.0)")
        ARLog.debug("- ctaButtonText: '\(config?.ctaButtonText ?? "No text")'")
        ARLog.debug("- ctaButtonColorHex: \(config?.ctaButtonColorHex ?? "No color")")
        ARLog.debug("- ctaButtonURL: \(config?.ctaButtonURL?.absoluteString ?? "No URL")")
        ARLog.debug("- ctaDelayMs: \(config?.ctaDelayMs ?? 0)")
        ARLog.debug("- overlayText: '\(config?.overlayText ?? "No overlay text")'")
        ARLog.debug("- loadingText: '\(config?.loadingText ?? "No loading text")'")
    }

    // MARK: - Asset Detection Notification
    private func processDetectedImage(anchor: ARImageAnchor, node: SCNNode) {
        ARLog.debug("🎯 Image detected and matched! Starting video...")
        
        isImageTracked = true
        
        // Hide the overlay now that we've detected the image
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayView.hide()
            }
            
        // Create a plane to display the video on
        createVideoPlane(for: node, with: anchor)
        
        // Play video based on the mode
        if isUsingTransparentVideo {
            ARLog.debug("Playing transparent video using Metal shader")
            transparentVideoPlayer?.play()
        } else if let player = videoPlayer {
            ARLog.debug("Playing standard video with AVPlayer")
            player.seek(to: .zero)
            player.play()
            }
            
        // Show button after delay
        showButtonWithDelay()
    }

    private func handleSuccessfulAssetLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.loadingTimer?.invalidate()
            self.retryCount = 0
            self.hideLoadingAnimation()
            self.noInternetView.hide()
            self.areAssetsLoaded = true
            
            if let referenceImage = self.referenceImage {
                let configuration = ARImageTrackingConfiguration()
                configuration.isAutoFocusEnabled = true
                configuration.trackingImages = [referenceImage]
                configuration.maximumNumberOfTrackedImages = 1
                
                self.sceneView.session.run(configuration, options: [.removeExistingAnchors])
                self.overlayView.show()
            }
        }
    }

    private func showNetworkErrorView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.hideLoadingAnimation()
            self.overlayView.hide()
            self.noInternetView.show()
            
            // Subscribe to network status changes
            NetworkMonitor.shared.onStatusChange = { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected {
                    // Network is back online
                    if let url = self.launchURL, let _ = url.extractFolderID() {
                        // Valid URL: retry AR
                        self.hideNetworkError()
                        self.processLaunchURL(url)
                    } else {
                        // Invalid URL: show QR scanner
                        QRScannerHelper.openQRScanner(from: self)
    }
}
            }
        }
    }

    // When video is loaded, track this event
    private func videoLoaded() {
        ARLog.debug("Video loaded and ready to play")
        
        // Track video loaded with analytics
        AnalyticsManager.shared.trackEvent(name: "AR Video Loaded", properties: [
            "folder_id": initialFolderID,
            "video_url": config?.videoURL ?? "none",
            "is_transparent": isUsingTransparentVideo,
            "video_format": isUsingTransparentVideo ? "transparent_alpha" : "standard_hls"
        ])
        
        isVideoReady = true
        
        // If already tracking an image, start playback immediately
        if isImageTracked {
            if isUsingTransparentVideo {
                transparentVideoPlayer?.play()
            } else {
                videoPlayer?.play()
            }
        }
    }
    
    // Add a tracking method for when a user taps the CTA button
    @objc private func ctaButtonTapped(url: URL) {
        // Track CTA button tap with enhanced analytics
        AnalyticsManager.shared.trackCTAButtonTapped(
            buttonText: config?.ctaButtonText ?? "unknown",
            url: url.absoluteString
        )
        
        // Open the URL
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func handleVideoPlayback(imageAnchor: ARImageAnchor, player: AVPlayer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if imageAnchor.isTracked {
                // Set tracking state
                self.isImageTracked = true
                
                // Check if this is the first detection
                let isFirstDetection = !self.hasShownCTAButton
                
                // Add a small delay to smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Ensure loading view is hidden
                    self.hideLoadingAnimation()
                    
                    // Only start from beginning if this is the first detection
                    if isFirstDetection {
                        player.seek(to: .zero)
                        ARLog.debug("First detection - starting video from beginning")
                    } else {
                        // Just resume from current position
                        ARLog.debug("Image re-detected - resuming video from current position")
                    }
                    
                    // Start playing the video
                    player.play()
                    
                    // Hide overlay and show button
                    self.hideOverlay()
                    self.showButtonWithDelay()
                    
                    ARLog.debug("✅ Video playback resumed")
                }
            } else {
                // Image might not be tracked yet
                ARLog.debug("⚠️ Image anchor added but not yet tracked")
                player.pause()
                self.isImageTracked = false
                self.showOverlay()
            }
        }
    }

    // Add a method to handle video looping for standard AVPlayer
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        ARLog.debug("🔄 Standard video reached end, looping from start")
        
        if let playerItem = notification.object as? AVPlayerItem, 
           let player = videoPlayer, 
           player.currentItem == playerItem,
           isImageTracked { // Only restart if we're still tracking the image
            player.seek(to: .zero)
            player.play()
        }
    }
}



