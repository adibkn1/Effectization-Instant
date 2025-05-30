import UIKit
import SceneKit

/// Applies an ARConfig's values to the ARViewController's UI components.
struct ConfigApplier {
    /// Apply all UI updates based on the config.
    static func apply(_ config: ARConfig?, to controller: ARViewController) {
        guard let config = config else {
            ARLog.warning("Cannot apply nil config to UI components")
            return
        }
        
        ARLog.debug("Applying configuration to UI components")
        
        applyLoadingView(config, to: controller)
        applyOverlayView(config, to: controller)
        applyCTAButton(config, to: controller)
        applyVideoDimensions(config, to: controller)
    }
    
    /// Apply just the loading view configuration
    static func applyLoadingView(_ config: ARConfig?, to controller: ARViewController) {
        guard let config = config else {
            ARLog.warning("Cannot apply nil config to loading view")
            return
        }
        
        if let loadingView = controller.loadingView {
            loadingView.updateText(text: config.loadingText)
            ARLog.debug("Updated loading text: \(config.loadingText)")
        }
    }
    
    /// Apply just the overlay view configuration
    static func applyOverlayView(_ config: ARConfig?, to controller: ARViewController) {
        guard let config = config else {
            ARLog.warning("Cannot apply nil config to overlay view")
            return
        }
        
        if let overlayView = controller.overlayView {
            overlayView.updateText(text: config.overlayText)
            overlayView.updateOpacity(opacity: config.overlayOpacity)
            ARLog.debug("Updated overlay text: \(config.overlayText) with opacity: \(config.overlayOpacity)")
            
            // Load overlay image from config URL
            ARLog.debug("Loading overlay image from: \(config.targetImageUrl)")
            
            // Use NetworkClient instead of direct URLSession call
            NetworkClient.get(from: config.targetImageUrl) { result in
                switch result {
                case .success(let data):
                    if let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            overlayView.updateImage(image: image)
                            overlayView.updateOpacity(opacity: config.overlayOpacity)
                            ARLog.debug("Successfully loaded overlay image with opacity: \(config.overlayOpacity)")
                        }
                    }
                case .failure(let error):
                    ARLog.error("Failed to load overlay image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Apply just the CTA button configuration
    static func applyCTAButton(_ config: ARConfig?, to controller: ARViewController) {
        guard let config = config else {
            ARLog.warning("Cannot apply nil config to CTA button")
            return
        }
        
        if let ctaView = controller.ctaView {
            // Handle optional properties
            let buttonText = config.ctaButtonText ?? ""
            let buttonColorHex = config.ctaButtonColorHex ?? "#F84B07"
            
            ctaView.configure(
                text: buttonText,
                colorHex: buttonColorHex
            ) {
                if let url = config.ctaButtonURL {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    ARLog.debug("CTA button tapped and URL opened: \(url)")
                }
            }
            ARLog.debug("Updated button configuration with text: \(buttonText) and color: \(buttonColorHex)")
        }
    }
    
    /// Apply just the video plane dimensions configuration
    static func applyVideoDimensions(_ config: ARConfig?, to controller: ARViewController) {
        guard let config = config else {
            ARLog.warning("Cannot apply nil config to video dimensions")
            return
        }
        
        let baseSize = config.actualTargetImageWidthMeters
        controller.videoPlaneWidth = baseSize * config.videoPlaneWidth
        controller.videoPlaneHeight = baseSize * config.videoPlaneHeight
        ARLog.debug("Updated video plane dimensions: \(controller.videoPlaneWidth) x \(controller.videoPlaneHeight) with base size: \(baseSize)")
    }
} 