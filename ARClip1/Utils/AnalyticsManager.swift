import Foundation
import UIKit
import PostHog

/// Analytics manager for tracking app events with PostHog specifically for App Clips
class AnalyticsManager {
    
    static let shared = AnalyticsManager()
    
    private var isInitialized = false
    private let posthogApiKey = "phc_KjNdqInUTnkKGa8uuJ4RMdnFXAwGimavq9T4SzVI6Pp" // PostHog API key
    private let posthogHost = "https://eu.i.posthog.com" // PostHog host URL
    
    // Store the current folderID for segmentation
    private var currentFolderID: String?
    
    // Track session metrics
    private var sessionStartTime = Date()
    private var firstImageDetectionTime: Date?
    private var ctaDisplayTime: Date?
    private var totalTrackingTime: TimeInterval = 0
    private var lastTrackingStartTime: Date?
    private var videoPlayStartTime: Date?
    private var totalVideoPlayTime: TimeInterval = 0
    
    private init() {}
    
    func initialize(folderID: String? = nil, invokeSource: String? = nil) {
        guard !isInitialized else { return }
        
        // Store folderID if provided
        if let folderID = folderID {
            self.currentFolderID = folderID
        }
        
        // Initialize PostHog with the minimal configuration
        let config = PostHogConfig(apiKey: posthogApiKey, host: posthogHost)
        
        // Set custom flush rate: 1 event per 0.1 second
        config.flushAt = 1
        config.flushIntervalSeconds = 0.1
        
        PostHogSDK.shared.setup(config)
        
        isInitialized = true
        sessionStartTime = Date()
        
        // Track app launch event with folderID and invoke source
        var props: [String: Any] = [:]
        if let folderID = currentFolderID {
            props["folder_id"] = folderID
            props["experience_id"] = folderID
        }
        if let invokeSource = invokeSource {
            props["invoke_source"] = invokeSource
        }
        
        // Capture app launch event
        PostHogSDK.shared.capture("App Clip Launched", properties: props)
        
        // Set user properties using identify event
        var userProps: [String: Any] = [:]
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            userProps["device_id"] = deviceId
        }
        userProps["os_version"] = UIDevice.current.systemVersion
        userProps["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        userProps["is_app_clip"] = true
        
        if let folderID = currentFolderID {
            userProps["last_experience"] = folderID
        }
        if let invokeSource = invokeSource {
            userProps["last_invoke_source"] = invokeSource
        }
        
        // Use $set to set user properties
        PostHogSDK.shared.capture("$identify", properties: ["$set": userProps])
    }
    
    // Set the current folderID (call this when URL changes or new AR experience loads)
    func setCurrentExperience(folderID: String) {
        self.currentFolderID = folderID
        
        // Update user property
        PostHogSDK.shared.capture("$identify", properties: ["$set": ["last_experience": folderID]])
        
        // Track experience change event
        trackEvent(name: "Experience Changed", properties: [
            "folder_id": folderID,
            "experience_id": folderID
        ])
    }
    
    func trackEvent(name: String, properties: [String: Any]? = nil) {
        // Enhance event properties with app_clip marker and folderID
        var updatedProperties = properties ?? [:]
        updatedProperties["is_app_clip"] = true
        
        // Add current folderID to all events if available and not already set
        if let folderID = currentFolderID, updatedProperties["folder_id"] == nil {
            updatedProperties["folder_id"] = folderID
            updatedProperties["experience_id"] = folderID
        }
        
        PostHogSDK.shared.capture(name, properties: updatedProperties)
        
        // Debug logging
        print("Analytics event: \(name), properties: \(updatedProperties)")
    }
    
    // Force flush all queued events - use this when immediate data is needed
    func flushEvents() {
        PostHogSDK.shared.flush()
        print("Manually flushing analytics events")
    }
    
    func identifyUser(distinctId: String) {
        PostHogSDK.shared.identify(distinctId)
        
        // Debug logging
        print("Identifying user: \(distinctId)")
    }
    
    func reset() {
        PostHogSDK.shared.reset()
        currentFolderID = nil
        resetSessionMetrics()
        
        // Debug logging
        print("Resetting analytics user")
    }
    
    private func resetSessionMetrics() {
        sessionStartTime = Date()
        firstImageDetectionTime = nil
        ctaDisplayTime = nil
        totalTrackingTime = 0
        lastTrackingStartTime = nil
        videoPlayStartTime = nil
        totalVideoPlayTime = 0
    }
    
    // MARK: - Asset Download Tracking
    
    func trackAssetDownloadStart(folderID: String, assetTypes: [String]) {
        trackEvent(name: "Asset Download Started", properties: [
            "folder_id": folderID,
            "asset_types": assetTypes,
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func trackAssetDownloadComplete(folderID: String, assetTypes: [String], duration: TimeInterval, success: Bool, errorMessage: String? = nil) {
        var props: [String: Any] = [
            "folder_id": folderID,
            "asset_types": assetTypes,
            "download_duration_seconds": duration,
            "success": success
        ]
        
        if let errorMessage = errorMessage {
            props["error_message"] = errorMessage
        }
        
        trackEvent(name: "Asset Download Completed", properties: props)
    }
    
    // MARK: - Image Tracking Events
    
    func trackFirstImageDetection(folderID: String) {
        firstImageDetectionTime = Date()
        
        let timeSinceAppLaunch = firstImageDetectionTime!.timeIntervalSince(sessionStartTime)
        
        trackEvent(name: "First Image Detection", properties: [
            "folder_id": folderID,
            "time_since_app_launch_seconds": timeSinceAppLaunch
        ])
    }
    
    func startTrackingSession() {
        lastTrackingStartTime = Date()
    }
    
    func pauseTrackingSession() {
        guard let startTime = lastTrackingStartTime else { return }
        
        let trackingDuration = Date().timeIntervalSince(startTime)
        totalTrackingTime += trackingDuration
        lastTrackingStartTime = nil
        
        trackEvent(name: "Tracking Session Paused", properties: [
            "session_duration_seconds": trackingDuration,
            "total_tracking_time_seconds": totalTrackingTime
        ])
    }
    
    // MARK: - Video Playback Tracking
    
    func startVideoPlayback() {
        videoPlayStartTime = Date()
        
        var props: [String: Any] = [:]
        if let firstDetectionTime = firstImageDetectionTime {
            props["time_since_first_detection"] = Date().timeIntervalSince(firstDetectionTime)
        }
        
        trackEvent(name: "Video Playback Started", properties: props)
    }
    
    func pauseVideoPlayback() {
        guard let startTime = videoPlayStartTime else { return }
        
        let playbackDuration = Date().timeIntervalSince(startTime)
        totalVideoPlayTime += playbackDuration
        videoPlayStartTime = nil
        
        trackEvent(name: "Video Playback Paused", properties: [
            "playback_duration_seconds": playbackDuration,
            "total_playback_time_seconds": totalVideoPlayTime
        ])
    }
    
    // MARK: - CTA Button Tracking
    
    func trackCTAButtonDisplayed(buttonText: String) {
        ctaDisplayTime = Date()
        
        var props: [String: Any] = [
            "button_text": buttonText
        ]
        
        if let firstDetection = firstImageDetectionTime {
            props["time_since_first_detection_seconds"] = ctaDisplayTime!.timeIntervalSince(firstDetection)
        }
        
        trackEvent(name: "CTA Button Displayed", properties: props)
    }
    
    func trackCTAButtonTapped(buttonText: String, url: String) {
        var props: [String: Any] = [
            "button_text": buttonText,
            "destination_url": url
        ]
        
        if let displayTime = ctaDisplayTime {
            props["time_since_cta_display_seconds"] = Date().timeIntervalSince(displayTime)
        }
        
        if let firstDetection = firstImageDetectionTime {
            props["time_since_first_detection_seconds"] = Date().timeIntervalSince(firstDetection)
        }
        
        trackEvent(name: "CTA Button Tapped", properties: props)
    }
    
    // MARK: - Session End Tracking
    
    func trackSessionEnd() {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        
        var props: [String: Any] = [
            "session_duration_seconds": sessionDuration,
            "total_tracking_time_seconds": totalTrackingTime,
            "total_video_playback_seconds": totalVideoPlayTime
        ]
        
        if let firstDetection = firstImageDetectionTime {
            props["had_image_detection"] = true
            props["time_to_first_detection_seconds"] = firstDetection.timeIntervalSince(sessionStartTime)
        } else {
            props["had_image_detection"] = false
        }
        
        trackEvent(name: "Session Ended", properties: props)
    }
    
    // MARK: - Helper Methods
    
    func trackScreenView(screenName: String, screenClass: String? = nil) {
        var props: [String: Any] = ["screen_name": screenName]
        if let screenClass = screenClass {
            props["screen_class"] = screenClass
        }
        trackEvent(name: "Screen View", properties: props)
    }
    
    func trackButtonTap(buttonName: String, screenName: String) {
        trackEvent(name: "Button Tap", properties: [
            "button_name": buttonName,
            "screen_name": screenName
        ])
    }
    
    func trackARSceneLoaded(folderID: String, success: Bool, loadTime: TimeInterval) {
        // Update current experience ID when AR scene loads
        self.currentFolderID = folderID
        
        trackEvent(name: "AR Scene Loaded", properties: [
            "folder_id": folderID,
            "experience_id": folderID,
            "success": success,
            "load_time_seconds": loadTime
        ])
    }
} 