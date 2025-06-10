import Foundation
import AVFoundation
import SceneKit
import Metal
import MetalKit

// Mark the class as @unchecked Sendable to fix the capture warning in Task
class TransparentVideoPlayer: NSObject, @unchecked Sendable {
    // MARK: - Properties
    private var rgbPlayer: AVPlayer?
    private var alphaPlayer: AVPlayer?
    private var rgbPlayerItem: AVPlayerItem?
    private var alphaPlayerItem: AVPlayerItem?
    
    private var isRGBReady = false
    private var isAlphaReady = false
    private var hasRGBFailed = false
    private var hasAlphaFailed = false
    private var arePlayersObserved = false
    
    // Video output for pixel buffer access
    private var rgbVideoOutput: AVPlayerItemVideoOutput?
    private var alphaVideoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    
    // Metal related properties
    private var device: MTLDevice?
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    
    // Output properties
    private var videoSize = CGSize(width: 1280, height: 720) // Default, will be updated
    private var outputTexture: MTLTexture?
    private var combinedTexture: Any? // This will be used for SceneKit material
    
    // Status callbacks
    var onReadyCallback: (() -> Void)?
    var onErrorCallback: ((Error) -> Void)?
    private var loadCompletion: ((Bool) -> Void)?
    
    // Observation tokens
    private var rgbPlayerObservation: NSKeyValueObservation?
    private var alphaPlayerObservation: NSKeyValueObservation?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMetal()
    }
    
    private func setupMetal() {
        // Set up Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            ARLog.error("Failed to create Metal device")
            return
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            ARLog.error("Failed to create command queue")
            return
        }
        self.commandQueue = commandQueue
        
        // Create texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        self.textureCache = textureCache
        
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            ARLog.error("Failed to create Metal library")
            return
        }
        
        // Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexPassthrough")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "combineRGBAlpha")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        
        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position attribute
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Texture coordinates attribute
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD4<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Define vertex buffer layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD4<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Set the vertex descriptor
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            ARLog.debug("Created Metal pipeline state successfully")
        } catch {
            ARLog.error("Failed to create pipeline state: \(error)")
        }
        
        // Create a simple SCNNode to hold the combined texture
        setupCombinedTexture()
    }
    
    private func setupCombinedTexture() {
        guard let device = self.device else { return }
        
        // Create texture descriptor for the combined texture
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: Int(videoSize.width),
            height: Int(videoSize.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        
        // Create output texture
        outputTexture = device.makeTexture(descriptor: textureDescriptor)
        
        // Create a SceneKit material with the output texture
        if let outputTexture = outputTexture {
            // Store this texture for the material
            combinedTexture = outputTexture
        }
    }
    
    // MARK: - Public Methods
    func loadVideos(rgbURL: URL, alphaURL: URL, completion: @escaping (Bool) -> Void) {
        ARLog.debug("📥 Loading RGB video from: \(rgbURL.absoluteString)")
        ARLog.debug("📥 Loading Alpha video from: \(alphaURL.absoluteString)")
        
        // Reset status
        isRGBReady = false
        isAlphaReady = false
        hasRGBFailed = false
        hasAlphaFailed = false
        loadCompletion = completion
        
        // Create asset options for better streaming
        let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        
        // Set up video output for RGB video
        let outputSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        rgbVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        alphaVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        
        // Setup RGB video
        let rgbAsset = AVURLAsset(url: rgbURL, options: assetOptions)
        rgbPlayerItem = AVPlayerItem(asset: rgbAsset)
        
        // Setup Alpha video
        let alphaAsset = AVURLAsset(url: alphaURL, options: assetOptions)
        alphaPlayerItem = AVPlayerItem(asset: alphaAsset)
        
        // Add video outputs to player items
        if let rgbVideoOutput = rgbVideoOutput {
            rgbPlayerItem?.add(rgbVideoOutput)
        }
        
        if let alphaVideoOutput = alphaVideoOutput {
            alphaPlayerItem?.add(alphaVideoOutput)
        }
        
        // Create players first
        rgbPlayer = AVPlayer(playerItem: rgbPlayerItem)
        alphaPlayer = AVPlayer(playerItem: alphaPlayerItem)
        
        // Mute the alpha video (it's just for the mask)
        alphaPlayer?.volume = 0
        
        // Set up direct player observations using KVO
        setupPlayerObservations()
        
        // Setup video looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: rgbPlayerItem
        )
    }
    
    // Set up KVO observations for player status
    private func setupPlayerObservations() {
        guard !arePlayersObserved, let rgbPlayer = rgbPlayer, let alphaPlayer = alphaPlayer else {
            return
        }
        
        // Remove any existing observations
        rgbPlayerObservation?.invalidate()
        alphaPlayerObservation?.invalidate()
        
        // Start fresh observations
        rgbPlayerObservation = rgbPlayer.observe(\.status, options: [.new, .initial]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.handlePlayerStatusChange(player: player, isRGB: true)
            }
        }
        
        alphaPlayerObservation = alphaPlayer.observe(\.status, options: [.new, .initial]) { [weak self] player, change in
            DispatchQueue.main.async {
                self?.handlePlayerStatusChange(player: player, isRGB: false)
            }
        }
        
        // Also observe player items for more detailed status
        rgbPlayerItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        alphaPlayerItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        arePlayersObserved = true
        ARLog.debug("👀 Set up KVO observations for both players")
    }
    
    // Handle player status changes
    private func handlePlayerStatusChange(player: AVPlayer, isRGB: Bool) {
        switch player.status {
        case .readyToPlay:
            if isRGB {
                ARLog.debug("✅ RGB player ready to play")
                isRGBReady = true
            } else {
                ARLog.debug("✅ Alpha player ready to play")
                isAlphaReady = true
            }
            
            // Check if both players are ready
            checkIfBothPlayersReady()
            
        case .failed:
            let errorMessage = player.error?.localizedDescription ?? "Unknown error"
            if isRGB {
                ARLog.error("RGB player failed: \(errorMessage)")
                hasRGBFailed = true
            } else {
                ARLog.error("Alpha player failed: \(errorMessage)")
                hasAlphaFailed = true
            }
            
            // Report failure
            if let completion = loadCompletion {
                loadCompletion = nil
                completion(false)
            }
            
            onErrorCallback?(player.error ?? NSError(
                domain: "TransparentVideoPlayer",
                code: isRGB ? 1 : 2,
                userInfo: [NSLocalizedDescriptionKey: "\(isRGB ? "RGB" : "Alpha") player failed to load"]
            ))
            
        default:
            if isRGB {
                ARLog.debug("🔄 RGB player status: \(player.status.rawValue)")
            } else {
                ARLog.debug("🔄 Alpha player status: \(player.status.rawValue)")
            }
        }
    }
    
    // Check if both players are ready and start playback if they are
    private func checkIfBothPlayersReady() {
        if isRGBReady && isAlphaReady {
            ARLog.debug("✅ Both RGB and Alpha players are ready to play")
            
            // Get video dimensions
            updateVideoSize()
            
            // Preroll both players to ensure smooth start
            rgbPlayer?.preroll(atRate: 1.0) { [weak self] finished in
                guard let self = self else { return }
                
                self.alphaPlayer?.preroll(atRate: 1.0) { [weak self] finished in
                    guard let self = self else { return }
                    
                    // Both players prerolled, now we can notify ready
                    DispatchQueue.main.async {
                        if let completion = self.loadCompletion {
                            self.loadCompletion = nil
                            completion(true)
                        }
                        self.onReadyCallback?()
                    }
                }
            }
        }
    }
    
    // Update video size from player item
    private func updateVideoSize() {
        // Use the modern iOS 16+ API since minimum deployment is iOS 16.6
        if let playerItem = rgbPlayerItem {
            Task.detached {
                if let track = try? await playerItem.asset.loadTracks(withMediaType: .video).first {
                    let size = try? await track.load(.naturalSize)
                    let videoSize = size ?? CGSize(width: 1280, height: 720)
                    ARLog.debug("📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                    
                    // Update on main thread
                    await MainActor.run {
                        self.videoSize = videoSize
                        // Recreate texture with new dimensions
                        self.setupCombinedTexture()
                    }
                }
            }
        }
    }
    
    func play() {
        // Only start if both players are ready
        guard isRGBReady && isAlphaReady else {
            ARLog.warning("Attempted to play before both players are ready")
            return
        }
        
        // Start display link for frame sync
        setupDisplayLink()
        
        // Don't seek to beginning unless it's the first time playing
        // This allows the video to resume from where it was paused
        
        // Start both videos in perfect sync
        rgbPlayer?.play()
        alphaPlayer?.play()
        
        ARLog.debug("▶️ Playing synchronized RGB and Alpha videos")
    }
    
    func pause() {
        // Stop display link
        displayLink?.invalidate()
        displayLink = nil
        
        // Pause videos
        rgbPlayer?.pause()
        alphaPlayer?.pause()
        ARLog.debug("⏸️ Paused RGB and Alpha videos")
    }
    
    func getMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        
        // If we have combined texture from shader, use it
        if let combinedTexture = self.combinedTexture {
            material.diffuse.contents = combinedTexture
        } else {
            // Otherwise just use the RGB video
            material.diffuse.contents = rgbPlayer
        }
        
        // Setup for transparency with correct blending
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.transparencyMode = .dualLayer  // Better for video transparency
        material.blendMode = .alpha
        material.lightingModel = .constant      // No lighting effects that could alter colors
        
        // Ensure no color adjustments happen
        material.diffuse.mappingChannel = 0
        material.diffuse.maxAnisotropy = 1
        material.diffuse.contentsTransform = SCNMatrix4Identity
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        
        return material
    }
    
    // MARK: - Display Link and Rendering
    private func setupDisplayLink() {
        // Clean up existing display link
        displayLink?.invalidate()
        
        // Create a new display link
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink?.preferredFramesPerSecond = 30 // Match video frame rate
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func displayLinkDidFire() {
        updateCombinedTexture()
    }
    
    private func updateCombinedTexture() {
        guard let rgbVideoOutput = rgbVideoOutput,
              let alphaVideoOutput = alphaVideoOutput,
              let device = device,
              let commandQueue = commandQueue,
              let pipelineState = pipelineState,
              let textureCache = textureCache,
              let outputTexture = outputTexture else {
            return
        }
        
        // Get the current time
        let rgbTime = rgbVideoOutput.itemTime(forHostTime: CACurrentMediaTime())
        let alphaTime = alphaVideoOutput.itemTime(forHostTime: CACurrentMediaTime())
        
        // Get pixel buffers for the current time
        guard let rgbPixelBuffer = rgbVideoOutput.copyPixelBuffer(forItemTime: rgbTime, itemTimeForDisplay: nil),
              let alphaPixelBuffer = alphaVideoOutput.copyPixelBuffer(forItemTime: alphaTime, itemTimeForDisplay: nil) else {
            return
        }
        
        // Create Metal textures from pixel buffers
        var rgbTextureRef: CVMetalTexture?
        var alphaTextureRef: CVMetalTexture?
        
        let width = CVPixelBufferGetWidth(rgbPixelBuffer)
        let height = CVPixelBufferGetHeight(rgbPixelBuffer)
        
        // Create RGB texture
        let rgbStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            rgbPixelBuffer,
            nil,
            .bgra8Unorm_srgb,
            width,
            height,
            0,
            &rgbTextureRef
        )
        
        // Create Alpha texture
        let alphaStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            alphaPixelBuffer,
            nil,
            .bgra8Unorm_srgb,
            CVPixelBufferGetWidth(alphaPixelBuffer),
            CVPixelBufferGetHeight(alphaPixelBuffer),
            0,
            &alphaTextureRef
        )
        
        // Check texture creation status
        guard rgbStatus == kCVReturnSuccess,
              alphaStatus == kCVReturnSuccess,
              let rgbTextureRef = rgbTextureRef,
              let alphaTextureRef = alphaTextureRef else {
            ARLog.error("Failed to create Metal textures from pixel buffers")
            return
        }
        
        // Get Metal textures from CV textures
        let rgbTexture = CVMetalTextureGetTexture(rgbTextureRef)
        let alphaTexture = CVMetalTextureGetTexture(alphaTextureRef)
        
        guard let rgbTexture = rgbTexture,
              let alphaTexture = alphaTexture else {
            ARLog.error("Failed to get Metal textures")
            return
        }
        
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            ARLog.error("Failed to create command buffer")
            return
        }
        
        // Create render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            ARLog.error("Failed to create render encoder")
            return
        }
        
        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Create a quad - FIXED: Corrected texture coordinates to flip vertically
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0, 0.0, 1.0, // bottom left
             1.0, -1.0, 0.0, 1.0, 1.0, 1.0, // bottom right
            -1.0,  1.0, 0.0, 1.0, 0.0, 0.0, // top left
             1.0,  1.0, 0.0, 1.0, 1.0, 0.0  // top right
        ]
        
        // Create vertex buffer
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            ARLog.error("Failed to create vertex buffer")
            renderEncoder.endEncoding()
            return
        }
        
        // Set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set fragment textures
        renderEncoder.setFragmentTexture(rgbTexture, index: 0)
        renderEncoder.setFragmentTexture(alphaTexture, index: 1)
        
        // Create a default sampler
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        if let sampler = device.makeSamplerState(descriptor: samplerDescriptor) {
            renderEncoder.setFragmentSamplerState(sampler, index: 0)
        }
        
        // Draw quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        // End encoding
        renderEncoder.endEncoding()
        
        // Commit command buffer
        commandBuffer.commit()
    }
    
    // MARK: - Observation
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let playerItem = object as? AVPlayerItem {
                DispatchQueue.main.async {
                    self.handlePlayerItemStatusChange(playerItem)
                }
            }
        }
    }
    
    private func handlePlayerItemStatusChange(_ playerItem: AVPlayerItem) {
        if playerItem == rgbPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                ARLog.debug("✅ RGB video ready to play")
                isRGBReady = true
                checkIfBothPlayersReady()
            case .failed:
                ARLog.error("RGB video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                hasRGBFailed = true
                // Immediately fail and call completion
                if let completion = loadCompletion {
                    loadCompletion = nil
                    completion(false)
                }
                onErrorCallback?(playerItem.error ?? NSError(domain: "TransparentVideoPlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "RGB video failed to load"]))
            default:
                break
            }
        } else if playerItem == alphaPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                ARLog.debug("✅ Alpha video ready to play")
                isAlphaReady = true
                checkIfBothPlayersReady()
            case .failed:
                ARLog.error("Alpha video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                hasAlphaFailed = true
                // Immediately fail and call completion
                if let completion = loadCompletion {
                    loadCompletion = nil
                    completion(false)
                }
                onErrorCallback?(playerItem.error ?? NSError(domain: "TransparentVideoPlayer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Alpha video failed to load"]))
            default:
                break
            }
        }
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        // Loop both videos when one reaches the end
        let currentTime = CMTime.zero
        rgbPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        alphaPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        // Restart playback if both are still ready and continue looping
        if isRGBReady && isAlphaReady {
            rgbPlayer?.play()
            alphaPlayer?.play()
            ARLog.debug("🔄 Video reached end, looping back to start automatically")
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Clean up display link
        displayLink?.invalidate()
        displayLink = nil
        
        // Clean up KVO observations
        rgbPlayerObservation?.invalidate()
        alphaPlayerObservation?.invalidate()
        
        // Clean up notifications
        rgbPlayerItem?.removeObserver(self, forKeyPath: "status")
        alphaPlayerItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
        
        // Clean up players
        rgbPlayer?.pause()
        alphaPlayer?.pause()
        rgbPlayer = nil
        alphaPlayer = nil
        
        ARLog.debug("🧹 Cleaned up all resources")
    }
} 