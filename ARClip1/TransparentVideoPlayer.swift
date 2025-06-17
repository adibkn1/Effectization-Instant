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
    
    // Add new property for frame duration
    private var frameDuration: Double = 1.0 / 30.0 // Default 30fps
    
    // Add state management
    private var isPlaying = false
    private var lastPauseTime: CMTime?
    private var isProcessingFrame = false
    private var frameQueue = DispatchQueue(label: "com.effectization.videoframe", qos: .userInteractive)
    private var renderingSemaphore = DispatchSemaphore(value: 1)
    
    // Track performance
    private var lastFrameTime: CFTimeInterval = 0
    private var frameDropCount = 0
    
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
        ARLog.debug("🔧 Metal device initialized: \(device.name)")
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            ARLog.error("Failed to create command queue")
            return
        }
        self.commandQueue = commandQueue
        ARLog.debug("✅ Command queue created")
        
        // Create texture cache
        var textureCache: CVMetalTextureCache?
        let textureCacheResult = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        if textureCacheResult != kCVReturnSuccess {
            ARLog.error("Failed to create texture cache: \(textureCacheResult)")
            return
        }
        self.textureCache = textureCache
        ARLog.debug("✅ Metal texture cache created")
        
        // Load shader library
        guard let library = device.makeDefaultLibrary() else {
            ARLog.error("Failed to create Metal library")
            return
        }
        ARLog.debug("📚 Metal shader library loaded")
        
        // Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexPassthrough")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "combineRGBAlphaWithTransparency")
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
            ARLog.debug("✅ Created Metal pipeline state with shader: combineRGBAlphaWithTransparency")
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
        
        // Setup video looping for both RGB and Alpha videos
        setupVideoLooping()
        
        // Setup display link for frame synchronization
        setupDisplayLink()
    }
    
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
    
    private func updateVideoSize() {
        // Use the modern iOS 16+ API since minimum deployment is iOS 16.6
        if let playerItem = rgbPlayerItem {
            Task.detached {
                if let track = try? await playerItem.asset.loadTracks(withMediaType: .video).first {
                    let size = try? await track.load(.naturalSize)
                    let videoSize = size ?? CGSize(width: 1280, height: 720)
                    ARLog.debug("📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                    
                    // Update frame duration using modern API
                    if let frameRate = try? await track.load(.nominalFrameRate) {
                        self.frameDuration = 1.0 / Double(frameRate)
                        ARLog.debug("📊 Frame rate: \(frameRate), frame duration: \(self.frameDuration)")
                    }
                    
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
    
    private func setupVideoLooping() {
        // Remove any existing observers
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Observe RGB video end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: rgbPlayerItem
        )
        
        // Observe Alpha video end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: alphaPlayerItem
        )
        
        // Set both players to loop mode
        rgbPlayer?.actionAtItemEnd = .none
        alphaPlayer?.actionAtItemEnd = .none
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        ARLog.debug("🔄 Video reached end, handling loop")
        
        // Determine which video ended
        let isRGBVideo = notification.object as? AVPlayerItem == rgbPlayerItem
        
        if isRGBVideo {
            ARLog.debug("RGB video reached end")
        } else {
            ARLog.debug("Alpha video reached end")
        }
        
        // Pause both videos
        rgbPlayer?.pause()
        alphaPlayer?.pause()
        
        // Reset both videos to start with precise timing
        let currentTime = CMTime.zero
        let tolerance = CMTime.zero
        
        // Ensure both videos are ready before restarting
        let group = DispatchGroup()
        
        group.enter()
        rgbPlayer?.seek(to: currentTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in
            group.leave()
        }
        
        group.enter()
        alphaPlayer?.seek(to: currentTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in
            group.leave()
        }
        
        // Wait for both seeks to complete before restarting
        group.notify(queue: .main) { [weak self] in
            guard let self = self,
                  self.isRGBReady && self.isAlphaReady else {
                ARLog.error("⚠️ Cannot restart videos - not all players ready")
                return
            }
            
            // Set rates for smooth restart
            self.rgbPlayer?.rate = 1.0
            self.alphaPlayer?.rate = 1.0
            
            ARLog.debug("▶️ Restarting both videos in sync")
            self.rgbPlayer?.play()
            self.alphaPlayer?.play()
        }
    }
    
    func play() {
        guard !isPlaying else { return }
        ARLog.debug("▶️ Play requested")
        
        // Reset frame processing state
        isProcessingFrame = false
        frameDropCount = 0
        lastFrameTime = 0
        
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wait for any pending operations
            _ = renderingSemaphore.wait(timeout: .now() + 0.1)
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.lastPauseTime = nil
                
                // Ensure we're in a clean state
                self.displayLink?.invalidate()
                self.displayLink = nil
                
                // Ensure we're at the start
                let currentTime = CMTime.zero
                self.rgbPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.alphaPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
                
                // Configure for smoother playback
                self.rgbPlayer?.automaticallyWaitsToMinimizeStalling = false
                self.alphaPlayer?.automaticallyWaitsToMinimizeStalling = false
                
                // Start display link for frame sync
                self.setupDisplayLink()
                
                // Set playback rate before playing
                self.rgbPlayer?.rate = 1.0
                self.alphaPlayer?.rate = 1.0
                
                // Start both videos in sync
                self.rgbPlayer?.play()
                self.alphaPlayer?.play()
                
                // Release the semaphore
                self.renderingSemaphore.signal()
                
                ARLog.debug("▶️ Playing synchronized RGB and Alpha videos from start")
            }
        }
    }
    
    func pause() {
        guard isPlaying else { return }
        ARLog.debug("⏸️ Pause requested")
        
        isPlaying = false
        lastPauseTime = rgbPlayer?.currentTime()
        
        // Stop display link first
        displayLink?.invalidate()
        displayLink = nil
        
        // Ensure clean pause with synchronized state
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wait for any in-flight frame processing
            _ = renderingSemaphore.wait(timeout: .now() + 0.1)
            
            DispatchQueue.main.async {
                // Ensure clean pause
                self.rgbPlayer?.rate = 0.0
                self.alphaPlayer?.rate = 0.0
                
                // Pause videos
                self.rgbPlayer?.pause()
                self.alphaPlayer?.pause()
                
                // Release the semaphore
                self.renderingSemaphore.signal()
                
                ARLog.debug("⏸️ Paused RGB and Alpha videos")
            }
        }
    }
    
    func resume() {
        guard !isPlaying else { return }
        ARLog.debug("▶️ Resume requested")
        
        // Reset frame processing state
        isProcessingFrame = false
        frameDropCount = 0
        lastFrameTime = 0
        
        // If we were at the end, restart from beginning
        if let lastTime = lastPauseTime,
           let duration = rgbPlayer?.currentItem?.duration,
           lastTime >= duration {
            play()
            return
        }
        
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wait for any pending operations
            _ = renderingSemaphore.wait(timeout: .now() + 0.1)
            
            DispatchQueue.main.async {
                self.isPlaying = true
                
                // Ensure we're in a clean state
                self.displayLink?.invalidate()
                self.displayLink = nil
                
                // Configure for smoother playback
                self.rgbPlayer?.automaticallyWaitsToMinimizeStalling = false
                self.alphaPlayer?.automaticallyWaitsToMinimizeStalling = false
                
                // Ensure both players are at the same position
                if let currentTime = self.lastPauseTime {
                    self.rgbPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    self.alphaPlayer?.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                // Start display link for frame sync
                self.setupDisplayLink()
                
                // Set playback rate before playing
                self.rgbPlayer?.rate = 1.0
                self.alphaPlayer?.rate = 1.0
                
                // Resume both videos
                self.rgbPlayer?.play()
                self.alphaPlayer?.play()
                
                // Release the semaphore
                self.renderingSemaphore.signal()
                
                ARLog.debug("▶️ Resumed synchronized RGB and Alpha videos")
            }
        }
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
        displayLink = nil
        
        // Only create display link if we're playing
        guard isPlaying else { return }
        
        // Create a new display link
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
        displayLink?.preferredFramesPerSecond = 30 // Match video frame rate
        displayLink?.add(to: .main, forMode: .common)
        ARLog.debug("Display link setup with 30fps")
    }
    
    @objc private func displayLinkDidFire() {
        // Skip if we're already processing a frame or not playing
        guard isPlaying, !isProcessingFrame else {
            frameDropCount += 1
            if frameDropCount % 30 == 0 {
                ARLog.warning("Dropped \(frameDropCount) frames due to backed up processing")
            }
            return
        }
        
        // Check frame timing
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let delta = currentTime - lastFrameTime
            if delta < (1.0 / 35.0) { // Allow slight variance above 30fps
                return // Skip this frame to maintain proper timing
            }
        }
        lastFrameTime = currentTime
        
        // Process frame on dedicated queue
        isProcessingFrame = true
        frameQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Try to acquire the rendering semaphore
            guard renderingSemaphore.wait(timeout: .now() + 0.1) == .success else {
                DispatchQueue.main.async {
                    self.isProcessingFrame = false
                }
                return
            }
            
            // Update textures
            self.updateCombinedTexture()
            
            // Release the semaphore and reset processing flag
            self.renderingSemaphore.signal()
            DispatchQueue.main.async {
                self.isProcessingFrame = false
            }
        }
    }
    
    private func updateCombinedTexture() {
        // Skip if we're not playing
        guard isPlaying else { return }
        
        // Get current video frame time
        let currentTime = CACurrentMediaTime()
        
        // Check if we have valid video outputs and Metal components
        guard let rgbVideoOutput = rgbVideoOutput,
              let alphaVideoOutput = alphaVideoOutput,
              let device = device,
              let commandQueue = commandQueue,
              let pipelineState = pipelineState,
              let textureCache = textureCache,
              let outputTexture = outputTexture else {
            ARLog.error("Missing required Metal components")
            return
        }
        
        // Get the next video frame with precise timing
        let rgbTime = rgbVideoOutput.itemTime(forHostTime: currentTime)
        let alphaTime = alphaVideoOutput.itemTime(forHostTime: currentTime)
        
        // Ensure we can get both pixel buffers
        guard let rgbPixelBuffer = rgbVideoOutput.copyPixelBuffer(forItemTime: rgbTime, itemTimeForDisplay: nil),
              let alphaPixelBuffer = alphaVideoOutput.copyPixelBuffer(forItemTime: alphaTime, itemTimeForDisplay: nil) else {
            return
        }
        
        // Get dimensions (assuming both are the same)
        let rgbWidth = CVPixelBufferGetWidth(rgbPixelBuffer)
        let rgbHeight = CVPixelBufferGetHeight(rgbPixelBuffer)
        let alphaWidth = CVPixelBufferGetWidth(alphaPixelBuffer)
        let alphaHeight = CVPixelBufferGetHeight(alphaPixelBuffer)
        
        // Verify dimensions match
        guard rgbWidth == alphaWidth, rgbHeight == alphaHeight else {
            ARLog.error("Mismatched video dimensions - RGB: \(rgbWidth)x\(rgbHeight), Alpha: \(alphaWidth)x\(alphaHeight)")
            return
        }
        
        // Create Metal textures from pixel buffers
        var rgbTextureRef: CVMetalTexture?
        var alphaTextureRef: CVMetalTexture?
        
        // Create RGB texture
        let rgbStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            rgbPixelBuffer,
            nil,
            .bgra8Unorm_srgb,
            rgbWidth,
            rgbHeight,
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
            alphaWidth,
            alphaHeight,
            0,
            &alphaTextureRef
        )
        
        // Check texture creation status
        guard rgbStatus == kCVReturnSuccess,
              alphaStatus == kCVReturnSuccess,
              let rgbTextureRef = rgbTextureRef,
              let alphaTextureRef = alphaTextureRef else {
            ARLog.error("Failed to create Metal textures")
            return
        }
        
        // Get Metal textures from CV textures
        guard let rgbTexture = CVMetalTextureGetTexture(rgbTextureRef),
              let alphaTexture = CVMetalTextureGetTexture(alphaTextureRef) else {
            ARLog.error("Failed to get Metal textures from CV textures")
            return
        }
        
        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            ARLog.error("Failed to create command buffer")
            return
        }
        
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        // Create render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            ARLog.error("Failed to create render encoder")
            return
        }
        
        // Create a quad with corrected texture coordinates
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  // Position for vertex 0
            0.0, 1.0,               // Texture coordinates for vertex 0
            1.0, -1.0, 0.0, 1.0,   // Position for vertex 1
            1.0, 1.0,               // Texture coordinates for vertex 1
            -1.0, 1.0, 0.0, 1.0,   // Position for vertex 2
            0.0, 0.0,               // Texture coordinates for vertex 2
            1.0, 1.0, 0.0, 1.0,    // Position for vertex 3
            1.0, 0.0                // Texture coordinates for vertex 3
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
        
        // Create sampler state
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.mipFilter = .linear
        
        guard let samplerState = device.makeSamplerState(descriptor: samplerDescriptor) else {
            ARLog.error("Failed to create sampler state")
            renderEncoder.endEncoding()
            return
        }
        
        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set fragment textures and sampler
        renderEncoder.setFragmentTexture(rgbTexture, index: 0)
        renderEncoder.setFragmentTexture(alphaTexture, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        // Draw quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        
        // End encoding and commit
        renderEncoder.endEncoding()
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
        
        // Clean up Metal resources
        outputTexture = nil
        pipelineState = nil
        commandQueue = nil
        
        // Clean up texture cache
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0)
            self.textureCache = nil
        }
        
        ARLog.debug("🧹 Cleaned up all resources")
    }
} 