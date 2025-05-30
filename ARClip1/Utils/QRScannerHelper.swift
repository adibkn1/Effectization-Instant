import UIKit
import SwiftUI

/// Helper for presenting QR scanner views
struct QRScannerHelper {
    
    /// Present QR scanner full screen from any view controller
    static func openQRScanner(from viewController: UIViewController) {
        let qrViewController = QRViewController()
        qrViewController.modalPresentationStyle = .fullScreen
        viewController.present(qrViewController, animated: true)
    }
    
    /// Opens QR scanner when root view controller is a UIHostingController
    static func openQRScanner() {
        // Use scene-based window access instead of deprecated windows property
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            ARLog.error("Cannot access root view controller to present QR scanner")
            return
        }
        
        // Handle presenting controller if it's in a navigation stack or modal
        let presentingController = rootViewController.presentedViewController ?? rootViewController
        
        let qrViewController = QRViewController()
        qrViewController.modalPresentationStyle = .fullScreen
        
        presentingController.present(qrViewController, animated: true)
    }
    
    /// Replace the current root view controller with QR scanner
    static func replaceRootWithQRScanner() {
        // Use scene-based window access instead of deprecated windows property
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            ARLog.error("Cannot access key window to replace root view controller")
            return
        }
        
        let qrViewController = QRViewController()
        window.rootViewController = qrViewController
        
        // Animate the transition
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }
} 