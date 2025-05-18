import SwiftUI
import ARKit
import SceneKit
import AVFoundation
import Network

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
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

struct ARContentView: UIViewControllerRepresentable {
    var launchURL: URL?
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController()
        if let url = launchURL {
            controller.processLaunchURL(url)
        }
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
    
    // MARK: - Configuration
    private var config: ARConfig = ARConfig.defaultConfig(folderID: "ar") // Default folderID
    
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

    var launchURL: URL?

    private var loadingTimeoutTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = [.top, .bottom, .left, .right]
        
        // Parse folderID from launchURL if available
        var folderID = "ar" // Default to "ar" folder ID
        if let url = launchURL, let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            print("[AR] URL path components: \(pathComponents)")
            if pathComponents.count >= 2 && pathComponents[0] == "card" {
                folderID = pathComponents[1]
                print("[AR] Extracted folderID from URL: \(folderID)")
            } else if pathComponents.count == 1 && pathComponents[0] == "card" {
                print("[AR] Path only contains 'card', using /ar folderID")
                } else {
                print("[AR] Path format not recognized, using /ar folderID")
            }
        } else {
            print("[AR] No URL available, using /ar folderID")
        }
        
        print("[AR] Initializing AR view with folderID: \(folderID)")
        
        // Use the extracted folderID, or "ar" as fallback
        config = ARConfig.defaultConfig(folderID: folderID)
        print("[AR] Initial config set with targetImageURL: \(config.targetImageURL)")
        
        // Log initial config values
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
        
        // Set up a debug check to verify config values after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            print("[AR] 🔍 DEBUG CHECK - Config values after 3 seconds:")
            self?.logConfig()
        }
        
        checkCameraPermission()
    }
    
    @objc private func configLoaded(_ notification: Notification) {
        if let config = notification.userInfo?["config"] as? ARConfig {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let isNewConfig = self.config.targetImageURL != config.targetImageURL
                print("[AR] Config loaded: \(config.targetImageURL) (new config: \(isNewConfig))")
                print("[AR] 📋 Config details: overlayText='\(config.overlayText)', ctaButtonText='\(config.ctaButtonText)', addedWidth=\(config.addedWidth ?? 1.0), addedHeight=\(config.addedHeight ?? 1.0)")
                
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
                    let hexColor = config.ctaButtonColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    if let buttonColor = UIColor(hex: hexColor) {
                        button.backgroundColor = buttonColor
                        print("[AR] 🎨 Updated button color: \(config.ctaButtonColor)")
                    }
                } else {
                    print("[AR] ⚠️ Button not yet initialized")
                }
                
                // Load overlay image from config URL
                if let imageURL = URL(string: config.targetImageURL) {
                    print("[AR] Loading overlay image from: \(config.targetImageURL)")
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
            
            // Clear any existing video
            videoPlayer?.pause()
            videoPlayer = nil
            
            // Force reset AR session
            if let sceneView = self.sceneView {
                sceneView.session.pause()
                let configuration = ARImageTrackingConfiguration()
                sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                print("[AR] Reset AR session for new config")
            }
            
            // Show loading animation
            showLoadingAnimation()
            
            // Use the provided folderID from notification 
            config = ARConfig.defaultConfig(folderID: folderID)
            print("[AR] Updated config with new folderID: \(folderID), targetImageURL: \(config.targetImageURL)")
            
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

    private func cancelAssetLoading() {
        // Cancel any ongoing downloads
        self.videoPlayer?.pause()
        self.videoPlayer = nil
        self.isVideoReady = false
        self.referenceImage = nil
        
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
        print("[AR] Starting asset loading with config: \(config.targetImageURL)")
        
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
        guard let imageURL = URL(string: config.targetImageURL) else {
            print("[AR] Invalid image URL: \(config.targetImageURL)")
            completion(false)
            return
        }
        
        print("[AR] Loading reference image from: \(config.targetImageURL)")
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
        guard let videoURL = URL(string: self.config.videoURL) else {
            print("[AR] Invalid video URL: \(config.videoURL)")
            completion()
            return
        }

        print("[AR] 📥 DOWNLOADING video from: \(config.videoURL)")
        
        // First, download the entire video to local storage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("cached_video.mov")
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: destinationURL)
        
        // Create download task to get the entire video file
        let downloadTask = URLSession.shared.downloadTask(with: videoURL) { [weak self] (tempURL, response, error) in
            guard let self = self, let tempURL = tempURL, error == nil else {
                print("[AR] ❌ VIDEO DOWNLOAD FAILED: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion()
                }
                return
            }
            
            // Move the downloaded file to our documents directory
            do {
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("[AR] ✅ Video downloaded successfully to: \(destinationURL.path)")
                
                // Now create asset from the local file
                let asset = AVURLAsset(url: destinationURL)
                
                if #available(iOS 16.0, *) {
                    // iOS 16+ approach
                    Task {
                        do {
                            // Load key properties
                            let _ = try await asset.load(.tracks)
                            let duration = try await asset.load(.duration)
                            
                            await MainActor.run {
                                // Create player with loaded asset
                                let playerItem = AVPlayerItem(asset: asset)
        playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        let player = AVPlayer(playerItem: playerItem)
                                player.automaticallyWaitsToMinimizeStalling = false
                                
                                // Preload by seeking to near the end
                                player.seek(to: CMTimeSubtract(duration, CMTime(seconds: 0.1, preferredTimescale: 600)))
                                
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
                                
                                // After seeking, return to beginning
                                player.seek(to: .zero)
                                
                                // Store player and mark as ready
                                self.videoPlayer = player
                                self.isVideoReady = true
                                
                                print("[AR] ✅ Video is FULLY LOADED and ready with looping enabled")
                                completion()
                            }
                        } catch {
                            print("[AR] ❌ ERROR loading video asset: \(error.localizedDescription)")
                            completion()
                        }
                    }
                } else {
                    // Pre-iOS 16 approach
                    asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
                        guard let self = self else { return }
                        
                        var error: NSError? = nil
                        let status = asset.statusOfValue(forKey: "tracks", error: &error)
                        
                        if status == .loaded {
        DispatchQueue.main.async {
                                let playerItem = AVPlayerItem(asset: asset)
                                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
                                
                                let player = AVPlayer(playerItem: playerItem)
                                player.automaticallyWaitsToMinimizeStalling = false
                                
                                // Set up video looping
                                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                                NotificationCenter.default.addObserver(
                                    forName: .AVPlayerItemDidPlayToEndTime,
                                    object: playerItem,
                                    queue: .main
                                ) { [weak player] _ in
                                    player?.seek(to: .zero)
                                    player?.play()
                                }
                                
                                // Store player and mark as ready
            self.videoPlayer = player
            self.isVideoReady = true
                                
                                print("[AR] ✅ Video is FULLY LOADED and ready with looping enabled")
                                completion()
                            }
                        } else {
                            print("[AR] ❌ ERROR loading video asset: \(error?.localizedDescription ?? "Unknown error")")
                            DispatchQueue.main.async {
                                completion()
                            }
                        }
                    }
                }
            } catch {
                print("[AR] ❌ ERROR saving downloaded video: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
        
        downloadTask.resume()
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
                self?.showLoadingAnimation()
                self?.loadingLabel.text = "Preparing AR experience..."
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
            self.overlayLabel.text = self.config.overlayText
            print("[AR] 📝 Set overlay text to: '\(self.config.overlayText)'")
            
            // Show scan overlay with appropriate text
                    self.overlayImageView.isHidden = false
                    self.overlayLabel.isHidden = false
            
            print("[AR] 👁️ Showing 'Scan this image' overlay")
            
            // Add small delay before updating AR session to prevent lag
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Update session configuration
                self.sceneView.session.run(configuration, options: [.removeExistingAnchors])
                self.areAssetsLoaded = true
                print("[AR] 🎯 AR session started and ready for tracking")
            }
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Only show network error if we have a config with valid URLs but can't load them
                let hasValidConfig = !self.config.targetImageURL.isEmpty && !self.config.videoURL.isEmpty
                
                if path.status == .satisfied {
                    print("[AR] Network connection available")
                    // If we have a config and aren't showing assets yet, retry loading
                    if hasValidConfig && !self.areAssetsLoaded {
                        print("[AR] Retry loading assets with valid config")
                        self.hideNetworkError()
                        self.retryLoadingAssets()
                    }
                } else if hasValidConfig {
                    // Only show the error if we have a valid config but no network
                    print("[AR] Network connection unavailable")
                    if !self.areAssetsLoaded {
                        self.showNetworkError()
                    }
                } else {
                    print("[AR] Waiting for configuration before checking network requirement")
                    // Show loading state if we don't have a config yet
                    self.hideNetworkError()
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
        
        // Try loading config again
        if let url = launchURL {
            print("[AR] Re-processing launch URL: \(url)")
            processLaunchURL(url)
        } else {
            // If no URL available, try with current config
            if !config.targetImageURL.isEmpty && !config.videoURL.isEmpty {
                retryLoadingAssets()
            } else {
                // Post a notification to reload config
                print("[AR] Requesting config reload")
                NotificationCenter.default.post(
                    name: NSNotification.Name("RequestConfigReloadNotification"),
                    object: nil
                )
            }
        }
    }

    private func retryLoadingAssets() {
        guard !areAssetsLoaded else { return }
        
        // Ensure we're showing the loading state
        hideNetworkError()
        
        print("[AR] Retrying asset loading with config: \(config.targetImageURL)")
        
        // First check if we have valid config
        if config.targetImageURL.isEmpty || config.videoURL.isEmpty {
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
        showNetworkError()
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
            self?.showNetworkError()
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
            if let imageAnchor = anchor as? ARImageAnchor {
                if !imageAnchor.isTracked && self.isImageTracked {
                    // Image tracking is lost
                    DispatchQueue.main.async {
                        print("[AR] Image tracking lost. Showing overlay and pausing video.")
                        self.showOverlay()
                        self.videoPlayer?.pause() // Pause the video
                        self.isImageTracked = false
                    }
                } else if imageAnchor.isTracked && !self.isImageTracked {
                    // Image tracking is regained
                    DispatchQueue.main.async {
                        print("[AR] Image detected again. Hiding overlay and playing video.")
                        self.hideOverlay()
                        self.videoPlayer?.play() // Play the video
                        self.isImageTracked = true
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
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("[AR] AR session reset.")
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
        let hexColor = config.ctaButtonColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let buttonColor = UIColor(hex: hexColor) {
            actionButton.backgroundColor = buttonColor
            print("[AR] Initial button color set: \(config.ctaButtonColor)")
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
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.loadingLabel.alpha = 1.0
            }
            self.loadingIndicator.startAnimating()
            print("[AR] Loading animation started")
        }
    }

    func hideLoadingAnimation() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.loadingLabel.alpha = 0.0
            } completion: { _ in
                self.loadingIndicator.stopAnimating()
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
        // Use delay from config
        print("[AR] 🔘 Will show CTA button after \(config.ctaButtonDelay) seconds with text: '\(config.ctaButtonText)'")
        
        // Ensure button text is updated with config value
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update button label with config text
            if let label = self.actionButton.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = self.config.ctaButtonText
                print("[AR] 📝 Updated button text to: '\(self.config.ctaButtonText)'")
            }
            
            // Update button color
            let hexColor = self.config.ctaButtonColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if let buttonColor = UIColor(hex: hexColor) {
                self.actionButton.backgroundColor = buttonColor
                print("[AR] 🎨 Updated button color to: \(self.config.ctaButtonColor)")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.ctaButtonDelay) { [weak self] in
            self?.actionButton.isHidden = false
            print("[AR] 👆 Button displayed after delay: \(self?.config.ctaButtonDelay ?? 0) seconds.")
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
        print("[AR] AR Experience processing launch URL: \(url.absoluteString)")
        print("[AR] URL COMPONENTS: scheme=\(url.scheme ?? "nil"), host=\(url.host ?? "nil"), path=\(url.path)")
        
        // Store the URL in case we need to retry
        self.launchURL = url
        
        // Always ensure we're showing the loading state first
        DispatchQueue.main.async { [weak self] in
            self?.hideNetworkError()
            self?.showLoadingAnimation()
        }
        
        // Extract folder ID and config ID from path (e.g., /card/ar)
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            let path = urlComponents.path
            print("[AR] URL Path: \(path)")
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            print("[AR] Path components: \(pathComponents)")
            
            // Check if path contains "card" followed by an ID
            if pathComponents.count >= 2 && pathComponents[0] == "card" {
                let folderID = pathComponents[1]
                print("[AR] Extracted folderID: \(folderID)")
                print("[AR] Will use direct path: /card/\(folderID)/")
                
                // Use sample_config by default
                let configID = "sample_config"
                print("[AR] Using configID: \(configID)")
                
                // Load config directly
                print("[AR] Loading configuration for folderID: \(folderID)")
                loadConfigFromURL(folderID: folderID, configID: configID)
            } else if pathComponents.count == 1 && pathComponents[0] == "card" {
                // Handle case where URL is just /card with no folderID
                let folderID = "ar" // Always use ar when no folder ID is specified
                let configID = "sample_config"
                print("[AR] Path only contains 'card', using /ar folderID")
                print("[AR] Will use direct path: /card/\(folderID)/")
                
                // Load config with ar folderID
                loadConfigFromURL(folderID: folderID, configID: configID)
            } else {
                print("[AR] URL path doesn't match expected format: \(path)")
                
                // Use /ar folder as fallback
                loadConfigFromURL(folderID: "ar", configID: "sample_config")
                
                // Display feedback to the user that this QR code isn't supported
                DispatchQueue.main.async { [weak self] in
                    self?.showLoadingAnimation()
                    self?.loadingLabel.text = "Unsupported QR code format, using default experience"
                }
            }
        } else {
            print("[AR] Could not create URLComponents from URL: \(url.absoluteString)")
            
            // Use /ar folder as fallback
            loadConfigFromURL(folderID: "ar", configID: "sample_config")
            
            DispatchQueue.main.async { [weak self] in
                self?.loadingLabel.text = "Invalid QR code URL format, using default experience"
            }
        }
    }
    
    // Load configuration from URL
    private func loadConfigFromURL(folderID: String, configID: String) {
        // Add timestamp to prevent caching
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let configURLString = "https://adagxr.com/card/\(folderID)/\(configID).json?t=\(timestamp)"
        print("[AR] Loading direct config from: \(configURLString)")
        
        guard let configURL = URL(string: configURLString) else {
            print("[AR] Invalid config URL")
            
            // Show error to user
            DispatchQueue.main.async { [weak self] in
                self?.loadingLabel.text = "Configuration error"
            }
            return
        }
        
        // Schedule a timeout handler using a method
        self.startConfigLoadingTimeout()
        
        // Create a URLRequest with cache policy to always load from origin
        var request = URLRequest(url: configURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Cancel the timeout timer
            DispatchQueue.main.async {
                self?.cancelConfigLoadingTimeout()
            }
            
            if let error = error {
                print("[AR] Failed to load config: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.loadingLabel.text = "Network error. Try again."
                    // Show retry option if the network is available but request failed
                    if let self = self, let monitor = self.networkMonitor, monitor.currentPath.status == .satisfied {
                        // Add retry button if not already added
                        if self.retryButton == nil {
                            self.setupRetryButton()
                        }
                        self.retryButton?.isHidden = false
                    } else {
                        self?.showNetworkError()
                    }
                }
                return
            }
            
            guard let data = data else {
                print("[AR] No data received from server")
                DispatchQueue.main.async {
                    self?.loadingLabel.text = "Empty response. Try again."
                    if let self = self, self.retryButton == nil {
                        self.setupRetryButton()
                    }
                    self?.retryButton?.isHidden = false
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let config = try decoder.decode(ARConfig.self, from: data)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("[AR] Successfully loaded config: \(config.targetImageURL)")
                    
                    // Apply the loaded configuration
                    self.config = config
                    
                    // Update UI with new config
                    self.loadingLabel.text = config.loadingText
                    self.overlayLabel.text = config.overlayText
                    
                    // Update button if it exists
                    if let button = self.actionButton {
                        let label = button.subviews.compactMap({ $0 as? UILabel }).first
                        label?.text = config.ctaButtonText
                        
                        let hexColor = config.ctaButtonColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                        if let buttonColor = UIColor(hex: hexColor) {
                            button.backgroundColor = buttonColor
                        }
                    }
                    
                    // Reload assets if needed
                    if !self.areAssetsLoaded {
                        self.startAssetLoading()
                    }
                }
            } catch {
                print("[AR] Failed to decode config: \(error.localizedDescription)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("[AR] Raw config data: \(dataString)")
                }
                
                // If we failed to decode with the current version of ARConfig,
                // try to manually extract the critical fields and create a valid config
                if let dataString = String(data: data, encoding: .utf8) {
                    print("[AR] Attempting to create valid config from partial data")
                    self?.createConfigFromPartialJSON(jsonString: dataString, folderID: folderID)
                } else {
                    DispatchQueue.main.async {
                        self?.loadingLabel.text = "Invalid configuration data"
                        if let self = self, self.retryButton == nil {
                            self.setupRetryButton()
                        }
                        self?.retryButton?.isHidden = false
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // Create a valid config object from partial JSON data
    private func createConfigFromPartialJSON(jsonString: String, folderID: String) {
        // Always use "ar" as fallback folder - we'll trigger an HTTP request to this folder
        let safeFolder = "ar"
        
        // Remote URLs only - no hardcoded fallbacks
        let targetImageURL = extractJSONString(from: jsonString, key: "targetImageURL") ?? "https://adagxr.com/card/\(safeFolder)/image.png"
        let videoURL = extractJSONString(from: jsonString, key: "videoURL") ?? "https://adagxr.com/card/\(safeFolder)/video.mov"
        
        // These should be populated from the remote config only
        // If we can't parse them, let the remote config load handle it
        let ctaButtonText = extractJSONString(from: jsonString, key: "ctaButtonText") ?? ""
        let ctaButtonColor = extractJSONString(from: jsonString, key: "ctaButtonColor") ?? ""
        let ctaButtonURL = extractJSONString(from: jsonString, key: "ctaButtonURL") ?? ""
        let overlayText = extractJSONString(from: jsonString, key: "overlayText") ?? ""
        let loadingText = extractJSONString(from: jsonString, key: "loadingText") ?? ""
        
        // Extract numerical values
        let videoPlaneWidth = extractJSONNumber(from: jsonString, key: "videoPlaneWidth") ?? 1.0
        let videoPlaneHeight = extractJSONNumber(from: jsonString, key: "videoPlaneHeight") ?? 1.41431
        let addedWidth = extractJSONNumber(from: jsonString, key: "addedWidth") ?? 1.0
        let addedHeight = extractJSONNumber(from: jsonString, key: "addedHeight") ?? 1.0
        let ctaButtonDelay = extractJSONNumber(from: jsonString, key: "ctaButtonDelay") ?? 1.0
        
        // Create a valid config using the extracted values and fallbacks
        let config = ARConfig(
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("[AR] Created valid config from partial data")
            self.config = config
            
            // Update UI with the new config
            self.loadingLabel.text = config.loadingText
            self.overlayLabel.text = config.overlayText
            
            // Update button if it exists
            if let button = self.actionButton {
                let label = button.subviews.compactMap({ $0 as? UILabel }).first
                label?.text = config.ctaButtonText
                
                let hexColor = config.ctaButtonColor.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                if let buttonColor = UIColor(hex: hexColor) {
                    button.backgroundColor = buttonColor
                }
            }
            
            // Reload assets if needed
            if !self.areAssetsLoaded {
                self.startAssetLoading()
            }
        }
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

    private func startConfigLoadingTimeout() {
        // Cancel any existing timer first
        cancelConfigLoadingTimeout()
        
        // Start a new timer on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.loadingTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                print("[AR] Config loading timeout reached")
                self?.loadingLabel.text = "Network timeout. Try again."
                
                // If we also have a network connection, show the retry button
                if let self = self, let monitor = self.networkMonitor, monitor.currentPath.status == .satisfied {
                    // Add retry button if not already added
                    if self.retryButton == nil {
                        self.setupRetryButton()
                    }
                    self.retryButton?.isHidden = false
                } else {
                    // If we don't have network connection, the network monitor will show error
                    self?.showNetworkError()
                }
            }
        }
    }
    
    private func cancelConfigLoadingTimeout() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingTimeoutTimer?.invalidate()
            self?.loadingTimeoutTimer = nil
        }
    }
    
    // MARK: - AR Delegate Methods
    
    // This is a critical method that gets called when ARKit detects a reference image
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("[AR] Renderer didAdd node for anchor: \(anchor)")
        
        // Check if the detected anchor is an ARImageAnchor
        guard let imageAnchor = anchor as? ARImageAnchor,
              let referenceImage = imageAnchor.referenceImage.name
        else {
            print("[AR] Not an image anchor or no valid reference image")
            return
        }
        
        print("[AR] Detected reference image: \(referenceImage)")
        
        // First check if video player is ready - if not, set up a wait mechanism
        if self.videoPlayer == nil || !self.isVideoReady {
            print("[AR] ⏳ Video player not ready yet, waiting for video to load...")
            // Wait for video player to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkVideoAndCreateNode(node: node, imageAnchor: imageAnchor, referenceImage: referenceImage)
            }
            return
        }
        
        // If video is ready, proceed immediately
        createVideoNode(node: node, imageAnchor: imageAnchor, referenceImage: referenceImage)
    }
    
    // Helper method to check if video is ready and create node
    private func checkVideoAndCreateNode(node: SCNNode, imageAnchor: ARImageAnchor, referenceImage: String) {
        if self.videoPlayer != nil && self.isVideoReady {
            print("[AR] ✅ Video is now ready, creating video node")
            createVideoNode(node: node, imageAnchor: imageAnchor, referenceImage: referenceImage)
        } else {
            print("[AR] ⏳ Still waiting for video to load, checking again...")
            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkVideoAndCreateNode(node: node, imageAnchor: imageAnchor, referenceImage: referenceImage)
            }
        }
    }
    
    // Extracted method to create the video node
    private func createVideoNode(node: SCNNode, imageAnchor: ARImageAnchor, referenceImage: String) {
        // Create a video plane
        let plane = SCNPlane(width: videoPlaneWidth, height: videoPlaneHeight)
        let videoNode = SCNNode(geometry: plane)
        
        // Position the video plane correctly - it should be centered on the detected image
        videoNode.eulerAngles.x = -.pi / 2  // Rotate plane to be horizontal
        
        // Make sure the AR plane is created with the right size
        print("[AR] Creating video plane with width: \(videoPlaneWidth), height: \(videoPlaneHeight)")
        
        // Set up video material
        if let videoPlayer = self.videoPlayer {
            print("[AR] Configuring video material for plane")
            
            let videoMaterial = SCNMaterial()
            videoMaterial.diffuse.contents = videoPlayer
            plane.materials = [videoMaterial]
            
            // Play the video
            DispatchQueue.main.async {
                videoPlayer.seek(to: .zero)
                videoPlayer.play()
                print("[AR] Video player started")
            }
            
            // Show the CTA button with a delay
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Hide the overlay
                self.hideOverlay()
                
                // Ensure button has the right text before showing
                if let label = self.actionButton.subviews.compactMap({ $0 as? UILabel }).first {
                    label.text = self.config.ctaButtonText
                    print("[AR] 📝 Confirmed button text before showing: \(self.config.ctaButtonText)")
                }
                
                // Now show button with delay
                self.showButtonWithDelay()
                
                self.isImageTracked = true
                print("[AR] AR image tracked, UI updated")
            }
        } else {
            print("[AR] ❌ Video player is nil, cannot create video material")
            return
        }
        
        // Add the video node to the scene
        node.addChildNode(videoNode)
        print("[AR] Added video node to AR scene")
    }

    private func logConfig() {
        print("[AR] 📋 CURRENT CONFIG VALUES:")
        print("[AR] - targetImageURL: \(config.targetImageURL)")
        print("[AR] - videoURL: \(config.videoURL)")
        print("[AR] - videoPlaneWidth: \(config.videoPlaneWidth)")
        print("[AR] - videoPlaneHeight: \(config.videoPlaneHeight)")
        print("[AR] - addedWidth: \(config.addedWidth ?? 1.0)")
        print("[AR] - addedHeight: \(config.addedHeight ?? 1.0)")
        print("[AR] - ctaButtonText: '\(config.ctaButtonText)'")
        print("[AR] - ctaButtonColor: \(config.ctaButtonColor)")
        print("[AR] - ctaButtonURL: \(config.ctaButtonURL)")
        print("[AR] - ctaButtonDelay: \(config.ctaButtonDelay)")
        print("[AR] - overlayText: '\(config.overlayText)'")
        print("[AR] - loadingText: '\(config.loadingText)'")
    }
}


