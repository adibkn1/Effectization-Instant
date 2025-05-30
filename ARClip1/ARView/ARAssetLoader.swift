import Foundation
import ARKit
import AVFoundation

/// Result of video loading: either a standard AVPlayer or a transparent player wrapper.
enum VideoLoadingResult {
  case standard(player: AVPlayer)
  case transparent(player: TransparentVideoPlayer)
}

/// Loads AR assets (reference image + video) for a given ARConfig.
class ARAssetLoader {

  private let config: ARConfig

  init(config: ARConfig) {
    self.config = config
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

  /// Loads the video(s) according to config.videoWithTransparency
  func loadVideo(completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    if config.videoWithTransparency {
      loadTransparentVideo(completion: completion)
    } else {
      loadStandardVideo(completion: completion)
    }
  }
  
  /// Loads transparent video using separate RGB+Alpha streams
  private func loadTransparentVideo(completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    ARLog.debug("🎬 Loading transparent video with separate RGB+Alpha videos")
    
    // Check for RGB and Alpha URLs
    guard let rgbURL = config.videoRgbUrl,
          let alphaURL = config.videoAlphaUrl else {
      ARLog.error("Missing RGB or Alpha URLs")
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
      ARLog.debug("🔄 Falling back to standard video mode")
      
      // Fall back to standard video if available
      self.loadStandardVideo(fallbackFromTransparent: true, completion: completion)
    }
    
    // Load RGB and Alpha videos
    transparentPlayer.loadVideos(rgbURL: rgbURL, alphaURL: alphaURL) { success in
      if !success {
        ARLog.error("Failed to load transparent videos, falling back to standard video")
        // Fall back to standard video
        self.loadStandardVideo(fallbackFromTransparent: true, completion: completion)
      }
    }
  }
  
  /// Loads standard video (non-transparent)
  private func loadStandardVideo(fallbackFromTransparent: Bool = false, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    // Standard video mode (non-transparent)
    let videoURLString = fallbackFromTransparent ? config.videoRgbUrl?.absoluteString : config.videoURL
    
    guard let videoURLString = videoURLString, let videoURL = URL(string: videoURLString) else {
      ARLog.error("Invalid video URL: \(fallbackFromTransparent ? String(describing: config.videoRgbUrl) : config.videoURL)")
      completion(.failure(NSError(
        domain: "ARAssetLoader",
        code: -5,
        userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"]
      )))
      return
    }
    
    ARLog.debug("🎬 Using standard video mode: \(videoURL.absoluteString)")
    
    // If HLS stream (.m3u8), use AVPlayer directly
    if videoURL.pathExtension.lowercased() == "m3u8" {
      ARLog.debug("Detected HLS stream (.m3u8), using AVPlayer directly")
      setupHLSPlayer(with: videoURL, completion: completion)
      return
    }
    
    // Otherwise download the file
    downloadAndSetupVideo(from: videoURL, completion: completion)
  }
  
  /// Set up HLS player
  private func setupHLSPlayer(with videoURL: URL, completion: @escaping (Result<VideoLoadingResult, Error>) -> Void) {
    let asset = AVURLAsset(url: videoURL)
    let playerItem = AVPlayerItem(asset: asset)
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
    
    ARLog.debug("✅ HLS Video player created and ready")
    completion(.success(.standard(player: player)))
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
        completion(.failure(error))
        return
      }
      
      guard let tempURL = tempURL else {
        ARLog.error("VIDEO DOWNLOAD FAILED: No temporary URL")
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
        
        // Try to use existing file if available
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          ARLog.debug("🔄 Using existing cached video file")
          self.setupVideoPlayer(with: destinationURL, completion: completion)
        } else {
          completion(.failure(error))
        }
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
} 