import SwiftUI
import ARKit
import SceneKit
import AVFoundation

struct ARContentView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ARViewController {
        return ARViewController()
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // No updates required for now
    }
}

class ARViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    var sceneView: ARSCNView!
    var videoPlayer: AVPlayer? // Class-level video player instance
    var isVideoReady = false // Indicates if the video is ready
    var isImageTracked = false  // Tracks if the image is currently being detected

    var overlayImageView: UIImageView!
    var overlayLabel: UILabel!
    var actionButton: UIButton!
    var loadingIndicator: UIActivityIndicatorView!
    var loadingLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Check camera permission first
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.setupAR()
                } else {
                    self.showCameraPermissionAlert()
                }
            }
        }
    }

    private func setupAR() {
        // Configure the AVAudioSession to play audio even when the iPhone is on silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AVAudioSession configured for playback, audio will play even in silent mode.")
        } catch {
            print("Failed to set up AVAudioSession: \(error.localizedDescription)")
        }

        // Initialize ARSCNView
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene() // Start with an empty scene

        // Add ARSCNView to the main view
        view.addSubview(sceneView)

        // Set up the initial overlay, button, and loading elements
        setupOverlay()
        setupButton()
        setupLoadingIndicator()
        setupLoadingLabel()

        // Preload the video in the background
        preloadVideo()

        print("AR scene initialized, waiting for session to start.")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.runARSession()
            print("AR session started.")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        print("AR session paused.")
    }

    // Preload the video in the background when the app opens
    func preloadVideo() {
        DispatchQueue.global().async {
            let videoURLString = "https://github.com/adibkn1/FlappyBird/raw/refs/heads/main/113.mp4" // Replace with your actual video URL
            guard let videoURL = URL(string: videoURLString) else {
                print("Invalid video URL.")
                return
            }

            let videoPlayer = AVPlayer(url: videoURL)
            videoPlayer.volume = 1.0 // Ensure audio is active

            // Notify the main thread when the video is ready
            DispatchQueue.main.async {
                self.videoPlayer = videoPlayer
                self.isVideoReady = true
                print("Video is preloaded and ready.")
            }
        }
    }

    func runARSession() {
        let configuration = ARImageTrackingConfiguration()
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            configuration.trackingImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 1 // Adjust as needed
        }
        sceneView.session.run(configuration)
        print("AR session running with image tracking configuration.")
    }

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let imageAnchor = anchor as? ARImageAnchor else {
            print("No ARImageAnchor detected.")
            return nil
        }

        print("Image anchor detected: \(imageAnchor)")

        DispatchQueue.main.async {
            if !self.isImageTracked {
                self.isImageTracked = true
                self.hideOverlay()

                if self.isVideoReady {
                    // Video is ready, start playing
                    self.playVideoOnNode()
                } else {
                    // Video is not ready, show loading animation
                    self.showLoadingAnimation()
                }
                self.showButtonWithDelay()
            }
        }

        // Load the scene asset and find the video plane node
        let scene = SCNScene(named: "art.scnassets/videoScene.scn")!
        if let planeNode = scene.rootNode.childNode(withName: "videoPlane", recursively: true),
           let videoNode = planeNode.childNode(withName: "video", recursively: true) {

            planeNode.opacity = 0.0 // Initial opacity for fade-in effect

            if let videoPlayer = videoPlayer {
                let videoMaterial = SCNMaterial()
                videoMaterial.diffuse.contents = videoPlayer
                videoMaterial.isDoubleSided = true
                videoNode.geometry?.materials = [videoMaterial]

                // Observer to loop the video playback
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: videoPlayer.currentItem,
                    queue: .main
                ) { _ in
                    videoPlayer.seek(to: .zero)
                    videoPlayer.play()
                    print("Video restarted for loop.")
                }

                // Fade-in animation for the video plane
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.5
                SCNTransaction.completionBlock = {
                    videoPlayer.play()
                    DispatchQueue.main.async {
                        self.hideLoadingAnimation() // Hide loading animation when video starts
                    }
                    print("Video started playing.")
                }
                planeNode.opacity = 1.0 // Fade to full opacity
                SCNTransaction.commit()
            }

            return planeNode
        }

        return SCNNode() // Return empty node instead of nil if no plane node found
    }

    func playVideoOnNode() {
        guard let videoPlayer = videoPlayer else { return }
        videoPlayer.play()
        print("Video started playing.")
        self.hideLoadingAnimation()
    }

    // Called when the AR session updates anchors (used to check tracking status)
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor {
                if !imageAnchor.isTracked && self.isImageTracked {
                    // Image tracking is lost
                    DispatchQueue.main.async {
                        print("Image tracking lost. Showing overlay and pausing video.")
                        self.showOverlay()
                        self.videoPlayer?.pause() // Pause the video
                        self.isImageTracked = false
                    }
                } else if imageAnchor.isTracked && !self.isImageTracked {
                    // Image tracking is regained
                    DispatchQueue.main.async {
                        print("Image detected again. Hiding overlay and playing video.")
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
                    print("Image anchor removed. Image is no longer being tracked.")
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
        print("AR session reset.")
    }

    // Set up the overlay image and label displayed initially
    func setupOverlay() {
        if let imagePath = Bundle.main.path(forResource: "image", ofType: "png"),
           let placeholderImage = UIImage(contentsOfFile: imagePath) {
            overlayImageView = UIImageView(image: placeholderImage)
            overlayImageView.contentMode = .scaleAspectFit
            overlayImageView.alpha = 0.8
            overlayImageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(overlayImageView)
        }

        overlayLabel = UILabel()
        overlayLabel.text = "Scan this image"
        overlayLabel.textColor = .white
        overlayLabel.textAlignment = .center
        overlayLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayLabel)

        NSLayoutConstraint.activate([
            overlayImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlayImageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            overlayImageView.heightAnchor.constraint(equalTo: overlayImageView.widthAnchor, multiplier: 0.5625),

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
        actionButton.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
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

        let label = UILabel()
        label.text = "Book a Ride"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

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
        if let url = URL(string: "https://komaki.in/") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        print("Button tapped and URL opened.")
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
        loadingLabel.text = "Preparing your experience"
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.isHidden = true
        view.addSubview(loadingLabel)

        NSLayoutConstraint.activate([
            loadingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 16)
        ])
    }

    func showLoadingAnimation() {
        loadingLabel.isHidden = false
        loadingIndicator.startAnimating()
    }

    func hideLoadingAnimation() {
        loadingLabel.isHidden = true
        loadingIndicator.stopAnimating()
    }

    // Hide the overlay (used when the image is detected)
    func hideOverlay() {
        overlayImageView.isHidden = true
        overlayLabel.isHidden = true
        print("Overlay hidden.")
    }

    // Show the overlay (used when the image is lost)
    func showOverlay() {
        DispatchQueue.main.async {
            self.overlayImageView.isHidden = false
            self.overlayLabel.isHidden = false
            print("Overlay shown.")
        }
    }

    // Show the button with a delay after the image is detected
    func showButtonWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.actionButton.isHidden = false
            print("Button displayed after delay.")
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
}

