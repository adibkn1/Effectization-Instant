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
    
    var topLabel = UILabel()
    var bottomLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        upperLabel()
        lowerLabel()
        addCloseButton()
        
        self.hidesBottomBarWhenPushed = false

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

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0) // Insert as the background layer

        addScannerOverlay()

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
                        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissViewController)
            )
    }

    @objc private func dismissViewController() {
        if presentingViewController != nil {
                dismiss(animated: true, completion: nil)
            } else {
                navigationController?.popViewController(animated: true)
            }
    }

    func addScannerOverlay() {
            let scannerWidth: CGFloat = 200
            let scannerHeight: CGFloat = 200

            scannerFrame = UIView(frame: CGRect(x: 0, y: 0, width: scannerWidth, height: scannerHeight))
            scannerFrame.center = view.center
            scannerFrame.backgroundColor = .clear
            view.addSubview(scannerFrame)

            let cornerImageView = UIImageView(image: UIImage(named: "QRScanner"))  // Your QR Scanner Image
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
   

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()

        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }

            found(code: stringValue)
        }
    }

    func found(code: String) {
        print("Scanned QR Code: \(code)")
        
        var formattedCode = code
        
        if !formattedCode.lowercased().hasPrefix("http://") && !formattedCode.lowercased().hasPrefix("https://") {
            formattedCode = "https://\(formattedCode)"
        }
        
        if let url = URL(string: formattedCode) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            print("Failed to create URL: \(formattedCode)")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    
    func upperLabel() {
        let text = "Scan QR Code"
        let attributedText = NSMutableAttributedString(string: text)
        let lightYellow = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
        
        attributedText.addAttribute(.foregroundColor, value: lightYellow, range: (text as NSString).range(of: "QR Code"))
        attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: (text as NSString).range(of: "Scan"))
        
        topLabel.attributedText = attributedText
        topLabel.textAlignment = .left
        topLabel.numberOfLines = 1
        topLabel.font = UIFont.systemFont(ofSize: 24)
        topLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(topLabel)
        
        NSLayoutConstraint.activate([
            topLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            topLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    func lowerLabel() {
        bottomLabel.text = "Align with scanner to scan"
        bottomLabel.textColor = .white
        bottomLabel.textAlignment = .left
        bottomLabel.numberOfLines = 2
        bottomLabel.font = UIFont.systemFont(ofSize: 18, weight: .light)
        bottomLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomLabel)
        
        NSLayoutConstraint.activate([
            bottomLabel.topAnchor.constraint(equalTo: topLabel.bottomAnchor, constant: 10),
            bottomLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
        ])
    }
    
    func addCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal) // Use SF Symbol for the cross icon
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
        
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
}
