//
//  QRViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit
import AVFoundation
import SwiftUI

// Add URL parameter support to ARContentView
struct ARContentViewWithParams: UIViewControllerRepresentable {
    var launchURL: URL?
    
    func makeUIViewController(context: Context) -> ARViewController {
        // Extract folderID from URL or use default
        var folderID = "ar" // Default
        
        if let url = launchURL, let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
            let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
            if pathComponents.count >= 2 && pathComponents[0] == "card" {
                folderID = pathComponents[1]
                print("[QR] Extracted folderID from URL: \(folderID)")
            }
        }
        
        // Create controller with folderID
        let controller = ARViewController(folderID: folderID)
        controller.launchURL = launchURL
        return controller
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // No updates required for now
    }
}

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var scannerFrame: UIView!
    
    override func loadView() {
        super.loadView()
        // Remove black background to prevent flash
        view.backgroundColor = .clear
        setupCamera()
    }
    
    private func setupCamera() {
        // Initialize capture session
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        
        // Set up the video input (camera)
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("[QR] Your device doesn't support scanning a QR code.")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("[QR] Error creating video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("[QR] Couldn't add video input to session.")
            return
        }
        
        // Set up the metadata output (QR Code detection)
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("[QR] Couldn't add metadata output to session.")
            return
        }
        
        captureSession.commitConfiguration()
        
        // Set up the preview layer to display the camera feed
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Start the session immediately
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hidesBottomBarWhenPushed = false
        addScannerOverlay()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Remove fade-in animation
        previewLayer?.opacity = 1.0
        
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Fade out before stopping the session
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        previewLayer?.opacity = 0
        CATransaction.commit()
        
        // Only stop the session if we're actually leaving the view controller
        // This prevents freezing when switching between tabs
        if isMovingFromParent || isBeingDismissed {
            if captureSession?.isRunning == true {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.captureSession?.stopRunning()
                }
            }
        }
    }
    
    // Add an animated scanner overlay
    func addScannerOverlay() {
        let scannerWidth: CGFloat = 200
        let scannerHeight: CGFloat = 200
        
        scannerFrame = UIView(frame: CGRect(x: 0, y: 0, width: scannerWidth, height: scannerHeight))
        scannerFrame.center = view.center
        scannerFrame.backgroundColor = .clear
        view.addSubview(scannerFrame)
        
        let cornerImageView = UIImageView(image: UIImage(named: "QRScanner"))
        cornerImageView.frame = scannerFrame.bounds
        cornerImageView.contentMode = .scaleAspectFit
        scannerFrame.addSubview(cornerImageView)
        
        let scanLabel = UILabel()
        scanLabel.text = "Scan the QR code"
        scanLabel.textColor = .white
        scanLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        scanLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanLabel)
        
        NSLayoutConstraint.activate([
            scanLabel.topAnchor.constraint(equalTo: scannerFrame.bottomAnchor, constant: 32),
            scanLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        startScannerAnimation()
    }
    
    // Add scaling animation for scanner effect
    func startScannerAnimation() {
        UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.scannerFrame.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.scannerFrame.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
                self.startScannerAnimation()
            })
        })
    }

    // Delegate method for metadata output (QR code detection)
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            // Process the detected QR code
            handleDetectedCode(code: stringValue)
        }
    }

    func handleDetectedCode(code: String) {
        print("[QR] Scanned QR Code: \(code)")

        var formattedCode = code

        // Ensure the scanned code is a valid URL, prepend "https://" if necessary
        if !formattedCode.lowercased().hasPrefix("http://") && !formattedCode.lowercased().hasPrefix("https://") {
            formattedCode = "https://\(formattedCode)"
        }

        // Check if the code is valid or unsupported
        if let url = URL(string: formattedCode) {
            // Check for adagxr.com URLs with card paths
            if url.host == "adagxr.com" && url.path.contains("/card/") {
                print("[QR] Matched adagxr.com AR trigger: \(url.absoluteString)")
                presentARView(with: url)
            } else if url.absoluteString == "https://appclip.apple.com/id?p=Effectization-Studio.Effectization-Instant.Clip" {
                print("[QR] Matched App Clip URL.")
                presentARView(with: url)
            } else {
                print("[QR] Scanned URL is unsupported: \(formattedCode)")
                showUnsupportedQRCodeMessage()
            }
        } else {
            print("[QR] Invalid URL format: \(formattedCode)")
            showUnsupportedQRCodeMessage()
        }
    }

    func presentARView(with url: URL? = nil) {
        DispatchQueue.main.async {
            // Stop the QR scanner first
            if self.captureSession?.isRunning == true {
                self.captureSession?.stopRunning()
            }
            print("[QR] QR scanner stopped.")
            
            // Create AR content view with the scanned URL
            let arContentView = ARContentViewWithParams(launchURL: url)
                .edgesIgnoringSafeArea(.all)
                .statusBar(hidden: true)
            
            let hostingController = UIHostingController(rootView: arContentView)
            hostingController.modalPresentationStyle = .fullScreen
            hostingController.modalTransitionStyle = .crossDissolve
            
            // First, dismiss any currently presented view controller
            if let presentedVC = self.presentedViewController {
                presentedVC.dismiss(animated: false) {
                    // Then present the AR view
                    self.present(hostingController, animated: true)
                }
            } else {
                // No presented view controller, present directly
                self.present(hostingController, animated: true)
            }
        }
    }
    
    // Handle scanned QR code URLs
    func handleScannedQRCode(url: URL) {
        print("[QR] Handling Scanned URL: \(url.absoluteString)")

        if url.host == "adagxr.com" && url.path.contains("/card/") {
            print("[QR] Matched adagxr.com AR trigger: \(url.absoluteString)")
            presentARView(with: url)
        } else if url.absoluteString == "https://appclip.apple.com/id?p=Effectization-Studio.Effectization-Instant.Clip" {
            print("[QR] Matched App Clip URL.")
            presentARView(with: url)
        } else {
            print("[QR] Scanned URL is unsupported: \(url.absoluteString)")
            showUnsupportedQRCodeMessage()
            restartScanner()
        }
    }
    
    // Show unsupported QR code message
    func showUnsupportedQRCodeMessage() {
        let messageLabel = UILabel()
        messageLabel.text = "Please scan an acceptable QR code."
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        messageLabel.layer.cornerRadius = 12
        messageLabel.layer.masksToBounds = true
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -view.bounds.height * 0.2),
            messageLabel.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Animate to fade out and remove after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            UIView.animate(withDuration: 0.5, animations: {
                messageLabel.alpha = 0
            }, completion: { _ in
                messageLabel.removeFromSuperview()
            })
        }
    }

    
    // Restart scanner
    func restartScanner() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self, let captureSession = self.captureSession else { return }
            
            // Only restart if the session isn't already running
            if !captureSession.isRunning {
                print("[QR] Restarting scanner.")
                captureSession.startRunning()
            }
        }
    }
}
