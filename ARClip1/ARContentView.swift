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
    // MARK: - URLs
    private let targetImageURL = "https://github.com/adibkn1/FlappyBird/blob/main/image.png?raw=true"
    private let videoURL = "https://github.com/adibkn1/FlappyBird/raw/refs/heads/main/113.mp4"
    
    // MARK: - Properties
    var sceneView: ARSCNView!
    var videoPlayer: AVPlayer?
    var isVideoReady = false
    var isImageTracked = false
    private var referenceImage: ARReferenceImage?
    
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
            guard let videoURL = URL(string: self.videoURL) else {
                print("Invalid video URL.")
                return
            }

            let videoPlayer = AVPlayer(url: videoURL)
            videoPlayer.volume = 1.0

            DispatchQueue.main.async {
                self.videoPlayer = videoPlayer
                self.isVideoReady = true
                print("Video is preloaded and ready.")
            }
        }
    }

    func runARSession() {
        guard ARImageTrackingConfiguration.isSupported else {
            print("AR Image tracking is not supported on this device")
            return
        }
        
        // Ensure sceneView is initialized
        guard let sceneView = self.sceneView else {
            print("ARSCNView not initialized")
            return
        }
        
        // Start basic AR session immediately to show camera feed
        let initialConfiguration = ARImageTrackingConfiguration()
        sceneView.session.run(initialConfiguration)
        
        // Show loading state while keeping camera feed visible
        DispatchQueue.main.async {
            self.showLoadingAnimation()
            self.loadingLabel.text = "Preparing your experience"
            // Make sure loading elements are on top of the camera feed
            self.view.bringSubviewToFront(self.loadingIndicator)
            self.view.bringSubviewToFront(self.loadingLabel)
        }
        
        // Load reference image, then update configuration
        loadReferenceImage { [weak self] success in
            guard let self = self else { return }
            
            if success, let referenceImage = self.referenceImage {
                let configuration = ARImageTrackingConfiguration()
                configuration.trackingImages = [referenceImage]
                configuration.maximumNumberOfTrackedImages = 1
                
                // Update existing session with new configuration
                sceneView.session.run(configuration, options: [.removeExistingAnchors])
                
                // Hide loading message after reference image is loaded
                DispatchQueue.main.async {
                    self.hideLoadingAnimation()
                }
                
                print("AR session updated with downloaded reference image")
            }
        }
    }

    private func loadReferenceImage(completion: @escaping (Bool) -> Void) {
        guard let imageURL = URL(string: targetImageURL) else {
            print("Invalid image URL")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                print("Failed to load image: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            // Create reference image with physical width of 2 meters
            let refImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 30.0)
            refImage.name = "targetImage"
            self.referenceImage = refImage
            
            // Also update the overlay image on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayImageView.image = uiImage
            }
            
            completion(true)
        }.resume()
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
                    self.playVideoOnNode()
                } else {
                    self.showLoadingAnimation()
                }
                self.showButtonWithDelay()
            }
        }

        // Create an empty node as fallback
        let rootNode = SCNNode()
        
        // Safely load the scene
        guard let scene = SCNScene(named: "art.scnassets/videoScene.scn"),
              let planeNode = scene.rootNode.childNode(withName: "videoPlane", recursively: true),
              let videoNode = planeNode.childNode(withName: "video", recursively: true) else {
            print("Failed to load scene or find required nodes")
            return rootNode
        }

        planeNode.opacity = 0.0

        if let videoPlayer = videoPlayer {
            let videoMaterial = SCNMaterial()
            videoMaterial.diffuse.contents = videoPlayer
            videoMaterial.isDoubleSided = true
            videoNode.geometry?.materials = [videoMaterial]

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: videoPlayer.currentItem,
                queue: .main
            ) { _ in
                videoPlayer.seek(to: .zero)
                videoPlayer.play()
                print("Video restarted for loop.")
            }

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            SCNTransaction.completionBlock = {
                videoPlayer.play()
                DispatchQueue.main.async {
                    self.hideLoadingAnimation()
                }
                print("Video started playing.")
            }
            planeNode.opacity = 1.0
            SCNTransaction.commit()
        }

        rootNode.addChildNode(planeNode)
        return rootNode
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
        // Create overlay image view without initial image
        overlayImageView = UIImageView()
        overlayImageView.contentMode = .scaleAspectFit
        overlayImageView.alpha = 0.8
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayImageView)
        
        // Download and set the overlay image
        if let imageURL = URL(string: targetImageURL) {
            URLSession.shared.dataTask(with: imageURL) { [weak self] data, response, error in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.overlayImageView.image = image
                    }
                }
            }.resume()
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
            overlayImageView.heightAnchor.constraint(equalTo: overlayImageView.widthAnchor, multiplier: 1.5), // Adjusted for 2:3 aspect ratio

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

