import Foundation
import ARKit
import AVFoundation
import SceneKit

/// Result of video loading: either a standard AVPlayer or a transparent player wrapper.
enum VideoLoadingResult {
  case standard(player: AVPlayer)
  case transparent(player: TransparentVideoPlayer)
}

/// Loads AR assets (reference image + video) for a given ARConfig.
class ARAssetLoader: NSObject {

  private let config: ARConfig

  init(config: ARConfig) {
    self.config = config
    super.init()
  }

  /// Loads the ARReferenceImage from config.targetImageUrl
  func loadReferenceImage(completion: @escaping (Result<ARReferenceImage, Error>) -> Void) {
    ARLog.debug("Loading reference image from: \(config.targetImageUrl)")
    
    NetworkClient.get(from: config.targetImageUrl) { result in
      switch result {
      case .failure(let error):
        ARLog.error("Failed to load image: \(error.localizedDescription)")
        completion(.failure(error))
        
      case .success(let data):
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
          ARLog.error("Failed to process image data")
          completion(.failure(NSError(
            domain: "ARAssetLoader", 
            code: -2, 
            userInfo: [NSLocalizedDescriptionKey: "Failed to process image data"]
          )))
          return
        }
        
        // Use actualTargetImageWidthMeters directly for the reference image
        // This is the physical width of the actual target image in meters
        let physicalWidth = self.config.actualTargetImageWidthMeters
        
        ARLog.debug("📏 Using actualTargetImageWidthMeters = \(physicalWidth) for reference image")
        
        // Create reference image with the physical width
        let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalWidth)
        referenceImage.name = "targetImage"
        
        ARLog.debug("✅ Reference image loaded successfully")
        completion(.success(referenceImage))
      }
    }
  }

  /// Loads the appropriate video based on configuration
  func loadVideo(completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    // Check if we're in transparent mode with separate RGB+Alpha videos
    if config.videoWithTransparency == true && config.videoRgbUrl != nil && config.videoAlphaUrl != nil {
      // Use transparent video mode
      loadTransparentVideo(completion: completion)
    } else if !config.videoURL.isEmpty {
      // Show QR scanner instead of trying standard video
      ARLog.debug("Standard video not allowed - showing QR scanner as requested")
      showQRScanner()
      
      completion(.failure(NSError(
        domain: "ARAssetLoader",
        code: -9,
        userInfo: [NSLocalizedDescriptionKey: "Standard video not allowed, showing QR scanner"]
      )))
    } else {
      // No video URL at all
      ARLog.error("No video URL found in configuration")
      showQRScanner()
      
      completion(.failure(NSError(
        domain: "ARAssetLoader",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "No video URL found"]
      )))
    }
  }
  
  /// Loads transparent video with RGB+Alpha channels
  private func loadTransparentVideo(completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    ARLog.debug("🎬 Loading transparent video with separate RGB+Alpha videos")
    
    // Check for RGB and Alpha URLs
    guard let rgbURL = config.videoRgbUrl,
          let alphaURL = config.videoAlphaUrl else {
      ARLog.error("Missing RGB or Alpha URLs")
      
      // Show QR scanner instead of returning error
      showQRScanner()
      
      completion(.failure(NSError(
        domain: "ARAssetLoader",
        code: -3,
        userInfo: [NSLocalizedDescriptionKey: "Missing transparent video URLs"]
      )))
      return
    }
    
    // Create and set up transparent video player
    let transparentPlayer = TransparentVideoPlayer()
    
    // Set callback for when videos are ready
    transparentPlayer.onReadyCallback = {
      ARLog.debug("✅ Transparent video is ready with RGB+Alpha")
      completion(.success(.transparent(player: transparentPlayer)))
    }
    
    // Set callback for errors
    transparentPlayer.onErrorCallback = { error in
      ARLog.error("Transparent video error: \(error.localizedDescription)")
      ARLog.debug("🔄 Showing QR scanner as fallback")
      
      // Show QR scanner immediately without attempting standard video fallback
      self.showQRScanner()
      
      completion(.failure(error))
    }
    
    // Load RGB and Alpha videos
    transparentPlayer.loadVideos(rgbURL: rgbURL, alphaURL: alphaURL) { success in
      if !success {
        ARLog.error("Failed to load transparent videos, showing QR scanner")
        // Show QR scanner immediately
        self.showQRScanner()
        
        completion(.failure(NSError(
          domain: "ARAssetLoader",
          code: -4,
          userInfo: [NSLocalizedDescriptionKey: "Failed to load transparent videos"]
        )))
      }
    }
  }
  
  /// Loads standard video (non-transparent)
  private func loadStandardVideo(fallbackFromTransparent: Bool = false, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    // Standard video mode (non-transparent)
    let videoURLString = fallbackFromTransparent ? config.videoRgbUrl?.absoluteString : config.videoURL
    
    guard let videoURLString = videoURLString, let videoURL = URL(string: videoURLString) else {
      ARLog.error("Invalid video URL: \(fallbackFromTransparent ? String(describing: config.videoRgbUrl) : config.videoURL)")
      
      // Show QR scanner instead of returning error
      showQRScanner()
      
      completion(.failure(NSError(
        domain: "ARAssetLoader",
        code: -5,
        userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"]
      )))
      return
    }
    
    ARLog.debug("🎬 Using standard video mode: \(videoURL.absoluteString)")
    
    // Don't fall back to standard video, just show QR scanner
    ARLog.debug("Standard video not allowed - showing QR scanner as requested")
    showQRScanner()
    
    completion(.failure(NSError(
      domain: "ARAssetLoader",
      code: -8,
      userInfo: [NSLocalizedDescriptionKey: "Standard video not allowed, showing QR scanner"]
    )))
  }
  
  /// Set up HLS player
  private func setupHLSPlayer(with videoURL: URL, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    let asset = AVURLAsset(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
    
    // Add observer to check for loading errors
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak self] notification in
      guard let self = self else { return }
      
      if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
        ARLog.error("HLS video failed to play: \(error.localizedDescription)")
        self.showQRScanner()
        completion(.failure(error))
      }
    }
    
    // Monitor item status
    playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
    
    let player = AVPlayer(playerItem: playerItem)
    player.automaticallyWaitsToMinimizeStalling = false
    player.actionAtItemEnd = .none // For looping
    
    // Setup video looping
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak player] _ in
      ARLog.debug("Video reached end, looping back to start")
      player?.seek(to: .zero)
      player?.play()
    }
    
    // Give a short grace period to see if the video starts loading
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak playerItem] in
      guard let self = self, let playerItem = playerItem else { return }
      
      // Check if the item has started loading properly
      if playerItem.status == .failed {
        ARLog.error("HLS Video failed to load: \(playerItem.error?.localizedDescription ?? "Unknown error")")
        self.showQRScanner()
        completion(.failure(playerItem.error ?? NSError(domain: "ARAssetLoader", code: -6, userInfo: nil)))
      } else {
        ARLog.debug("✅ HLS Video player created and ready with looping enabled")
    completion(.success(.standard(player: player)))
      }
      
      // Clean up observation
      playerItem.removeObserver(self, forKeyPath: "status")
    }
  }
  
  /// Download video and set up player
  private func downloadAndSetupVideo(from videoURL: URL, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    ARLog.debug("📥 DOWNLOADING video from: \(videoURL.absoluteString)")
    
    // First, download the entire video to local storage
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // Create a uniquely named file based on the URL to avoid conflicts
    let folderID = URL.extractFolderID(from: config.videoURL) ?? "video"
    let destinationURL = documentsPath.appendingPathComponent("\(folderID)_cached_video.mov")
    
    // Always ensure we can write a new file
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      do {
        try FileManager.default.removeItem(at: destinationURL)
        ARLog.debug("🗑️ Removed existing video file to prevent conflicts")
      } catch {
        ARLog.warning("Could not remove existing file: \(error.localizedDescription)")
        // Try to use the existing file if it exists
        self.setupVideoPlayer(with: destinationURL, completion: completion)
        return
      }
    }
    
    // Create download task to get the entire video file
    let downloadTask = URLSession.shared.downloadTask(with: videoURL) { [weak self] (tempURL, response, error) in
      guard let self = self else {
        completion(.failure(NSError(
          domain: "ARAssetLoader",
          code: -6,
          userInfo: [NSLocalizedDescriptionKey: "Self reference lost during download"]
        )))
        return
      }
      
      if let error = error {
        ARLog.error("VIDEO DOWNLOAD FAILED: \(error.localizedDescription)")
        // Show QR scanner immediately
        DispatchQueue.main.async {
          self.showQRScanner()
        }
        completion(.failure(error))
        return
      }
      
      guard let tempURL = tempURL else {
        ARLog.error("VIDEO DOWNLOAD FAILED: No temporary URL")
        // Show QR scanner immediately
        DispatchQueue.main.async {
          self.showQRScanner()
        }
        completion(.failure(NSError(
          domain: "ARAssetLoader",
          code: -7,
          userInfo: [NSLocalizedDescriptionKey: "No temporary URL for downloaded video"]
        )))
        return
      }
      
      // Move the downloaded file to our documents directory
      do {
        // If file exists, remove it first
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          try FileManager.default.removeItem(at: destinationURL)
          ARLog.debug("🔄 Removed existing cached video before saving new one")
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        ARLog.debug("✅ Video downloaded successfully to: \(destinationURL.path)")
        
        // Set up video player with the cached file
        self.setupVideoPlayer(with: destinationURL, completion: completion)
      } catch {
        ARLog.error("ERROR saving downloaded video: \(error.localizedDescription)")
        
        // Show QR scanner immediately instead of trying existing file
        DispatchQueue.main.async {
          self.showQRScanner()
        }
          completion(.failure(error))
      }
    }
    
    downloadTask.resume()
  }
  
  /// Set up standard video player from local file
  private func setupVideoPlayer(with videoURL: URL, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    let asset = AVURLAsset(url: videoURL)
    
    // Create player item
    let playerItem = AVPlayerItem(asset: asset)
    
    // Create player with an explicit rate to ensure it plays
    let player = AVPlayer(playerItem: playerItem)
    player.automaticallyWaitsToMinimizeStalling = false
    player.actionAtItemEnd = .none // Needed for proper looping
    
    // Set up video looping
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main
    ) { [weak player] _ in
      ARLog.debug("Video reached end, looping back to start")
      player?.seek(to: .zero)
      player?.play()
    }
    
    ARLog.debug("✅ Video is FULLY LOADED and ready with looping enabled")
    completion(.success(.standard(player: player)))
  }
  
  /// Helper method to show QR scanner
  private func showQRScanner() {
    DispatchQueue.main.async {
      ARLog.debug("🔄 Showing QR scanner as fallback")
      QRScannerHelper.replaceRootWithQRScanner()
    }
  }

  // MARK: - KVO Observation
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
    if keyPath == "status", let playerItem = object as? AVPlayerItem {
      switch playerItem.status {
      case .failed:
        // Handle failure
        ARLog.error("Video player item failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
        // No need to call showQRScanner() here as it's handled in the setupHLSPlayer completion
      case .readyToPlay:
        ARLog.debug("Video player item ready to play")
      default:
        break
      }
    }
  }
} 