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
    var videoPlayer: AVPlayer?

    var overlayImageView: UIImageView!
    var overlayLabel: UILabel!

    var isImageTracked = false  // Tracks if the image is being detected

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize ARSCNView
        sceneView = ARSCNView(frame: self.view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()  // Empty scene for now

        view.addSubview(sceneView)

        // Add the image and text overlay
        setupOverlay()
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

    // Configure AR session for image tracking
    func runARSession() {
        let configuration = ARImageTrackingConfiguration()

        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            configuration.trackingImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 1
        }

        sceneView.session.run(configuration)
        print("AR session running with image tracking configuration.")
    }

    // ARSCNViewDelegate method to display content when an image is detected
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let imageAnchor = anchor as? ARImageAnchor else {
            print("No ARImageAnchor detected.")
            return nil
        }

        // Example usage of imageAnchor
        print("Image anchor detected: \(imageAnchor)")

        DispatchQueue.main.async {
            print("Image detected. Hiding overlay.")
            self.hideOverlay()
            self.isImageTracked = true
        }

        let scene = SCNScene(named: "art.scnassets/videoScene.scn")!

        if let planeNode = scene.rootNode.childNode(withName: "videoPlane", recursively: true),
           let videoNode = planeNode.childNode(withName: "video", recursively: true),
           let videoURL = Bundle.main.url(forResource: "yourVideo", withExtension: "mp4") {

            planeNode.opacity = 0

            videoPlayer = AVPlayer(url: videoURL)
            let videoMaterial = SCNMaterial()
            videoMaterial.diffuse.contents = videoPlayer
            videoNode.geometry?.materials = [videoMaterial]

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            planeNode.opacity = 1
            SCNTransaction.completionBlock = {
                self.videoPlayer?.play()
                print("Video started playing.")
            }
            SCNTransaction.commit()

            return planeNode
        }

        print("No video plane found in the scene.")
        return nil
    }

    // This method is called periodically to update tracking state
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let anchors = frame.anchors.compactMap { $0 as? ARImageAnchor }
        if anchors.isEmpty {
            // No images detected, re-show overlay and reset the session
            DispatchQueue.main.async {
                if self.isImageTracked {
                    print("Image lost. Showing overlay again.")
                    self.showOverlay()
                    self.isImageTracked = false
                    self.resetARSession()  // Reset session to remove previous anchor
                }
            }
        }
    }

    // Reset AR session to remove old anchors
    func resetARSession() {
        let configuration = ARImageTrackingConfiguration()

        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) {
            configuration.trackingImages = referenceImages
        }

        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        print("AR session reset.")
    }

    // Setup the image and label overlay
    func setupOverlay() {
        if let imagePath = Bundle.main.path(forResource: "image", ofType: "png"),
           let placeholderImage = UIImage(contentsOfFile: imagePath) {
            overlayImageView = UIImageView(image: placeholderImage)
            overlayImageView.contentMode = .scaleAspectFit
            overlayImageView.alpha = 0.5
            overlayImageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(overlayImageView)
            print("Overlay image loaded.")
        } else {
            print("Image not found in ARClip1 resources")
        }

        overlayLabel = UILabel()
        overlayLabel.text = "Scan this image"
        overlayLabel.textColor = .white
        overlayLabel.textAlignment = .center
        overlayLabel.font = UIFont.systemFont(ofSize: 18)
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayLabel)
        print("Overlay label added.")

        NSLayoutConstraint.activate([
            overlayImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlayImageView.widthAnchor.constraint(equalToConstant: 400),
            overlayImageView.heightAnchor.constraint(equalToConstant: 400),

            overlayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayLabel.topAnchor.constraint(equalTo: overlayImageView.bottomAnchor, constant: 20)
        ])
    }

    func hideOverlay() {
        overlayImageView.isHidden = true
        overlayLabel.isHidden = true
        print("Overlay hidden.")
    }

    func showOverlay() {
        overlayImageView.isHidden = false
        overlayLabel.isHidden = false
        print("Overlay shown.")
    }
}
