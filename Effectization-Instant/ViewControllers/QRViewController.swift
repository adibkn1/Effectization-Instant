//
//  QRViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit
import AVFoundation

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var scannerFrame: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ensure tab bar is not hidden when the scanner is active
        self.hidesBottomBarWhenPushed = false

        // Set up the QR code scanner session
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("Your device doesn't support scanning a QR code.")
            return
        }

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error creating video input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Couldn't add video input to session.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Couldn't add metadata output to session.")
            return
        }

        // Set up the preview layer to show what the camera sees
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Add the scanner overlay with animated scanning corners
        addScannerOverlay()

        // Start the capture session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    // Function to add the animated scanner overlay with only the corners visible
    func addScannerOverlay() {
            let scannerWidth: CGFloat = 200
            let scannerHeight: CGFloat = 200

            // Create a view that represents the scanner frame
            scannerFrame = UIView(frame: CGRect(x: 0, y: 0, width: scannerWidth, height: scannerHeight))
            scannerFrame.center = view.center
            scannerFrame.backgroundColor = .clear
            view.addSubview(scannerFrame)

            // Add the image overlay for the corners
            let cornerImageView = UIImageView(image: UIImage(named: "QRScanner"))  // Your QR Scanner Image
            cornerImageView.frame = scannerFrame.bounds
            cornerImageView.contentMode = .scaleAspectFit
            scannerFrame.addSubview(cornerImageView)

            // Add a label below the scanner frame to prompt the user
            let scanLabel = UILabel()
            scanLabel.text = "Scan the QR code"
            scanLabel.textColor = .white
            scanLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            scanLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(scanLabel)

            // Set constraints for the label to place it below the scanner frame
            NSLayoutConstraint.activate([
                scanLabel.topAnchor.constraint(equalTo: scannerFrame.bottomAnchor, constant: 32), // Adjust the constant to move the text lower
                scanLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            ])

            // Add scaling animation to simulate a scanning effect
            startScannerAnimation()
        }

        // Function to start the scaling animation
    func startScannerAnimation() {
        UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.scannerFrame.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.scannerFrame.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
                self.startScannerAnimation()  // Recursive call for continuous animation
            })
        })
    }
   

    // Restart the session when the view reappears
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    // Stop the session when the view disappears
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    // Handle when a QR code is found
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            // Handle the scanned QR code value
            found(code: stringValue)
        }
    }

    // Function to handle found QR code
    func found(code: String) {
        print("Scanned QR Code: \(code)")
        
        var formattedCode = code
        
        // Check if the URL starts with "http" or "https", if not, prepend "https://"
        if !formattedCode.lowercased().hasPrefix("http://") && !formattedCode.lowercased().hasPrefix("https://") {
            formattedCode = "https://\(formattedCode)"
        }
        
        // Open the scanned URL
        if let url = URL(string: formattedCode) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("Failed to create URL: \(formattedCode)")
        }

        // Optionally, restart the session when you come back from the external app
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

}
