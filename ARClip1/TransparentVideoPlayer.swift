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
    
    // Video output for pixel buffer access
    private var rgbVideoOutput: AVPlayerItemVideoOutput?
    private var alphaVideoOutput: AVPlayerItemVideoOutput?
    private var displayLink: CADisplayLink?
    
    // Metal related properties
    private var device: MTLDevice?
    private var pipelineState: MTLRenderPipelineState?
    private var commandQueue: MTLCommandQueue?
    private var textureCache: CVMetalTextureCache?
    private var rgbTexture: MTLTexture?
    private var alphaTexture: MTLTexture?
    
    // Output properties
    private var videoSize = CGSize(width: 1280, height: 720) // Default, will be updated
    private var outputTexture: MTLTexture?
    private var combinedTexture: Any? // This will be used for SceneKit material
    
    // Status callbacks
    var onReadyCallback: (() -> Void)?
    var onErrorCallback: ((Error) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupMetal()
    }
    
    private func setupMetal() {
        // Set up Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[TransparentVideo] ❌ Failed to create Metal device")
            ARLog.error("Failed to create Metal device")
            return
        }
        self.device = device
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("[TransparentVideo] ❌ Failed to create command queue")
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
            print("[TransparentVideo] ❌ Failed to create Metal library")
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
            print("[TransparentVideo] ✅ Created Metal pipeline state successfully")
            ARLog.debug("Created Metal pipeline state successfully")
        } catch {
            print("[TransparentVideo] ❌ Failed to create pipeline state: \(error)")
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
        print("[TransparentVideo] 📥 Loading RGB video from: \(rgbURL.absoluteString)")
        print("[TransparentVideo] 📥 Loading Alpha video from: \(alphaURL.absoluteString)")
        ARLog.debug("📥 Loading RGB video from: \(rgbURL.absoluteString)")
        ARLog.debug("📥 Loading Alpha video from: \(alphaURL.absoluteString)")
        
        // Reset status
        isRGBReady = false
        isAlphaReady = false
        
        // Create asset options for better streaming
        let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        
        // Set up video output for RGB video
        let rgbOutputSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        rgbVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: rgbOutputSettings)
        
        // Set up video output for Alpha video
        let alphaOutputSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        alphaVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: alphaOutputSettings)
        
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
        
        // Add observers for status AFTER creating players
        rgbPlayerItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        alphaPlayerItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        // Setup video looping
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: rgbPlayerItem
        )
        
        // Do NOT preroll immediately, wait for status to be readyToPlay
        // We'll complete in the observer when both videos are ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if !self.isRGBReady || !self.isAlphaReady {
                print("[TransparentVideo] ⚠️ Timeout waiting for videos to load")
                ARLog.warning("Timeout waiting for videos to load")
                completion(false)
            }
        }
    }
    
    func play() {
        // Start display link for frame sync if needed
        setupDisplayLink()
        
        // Start both videos in sync
        rgbPlayer?.play()
        alphaPlayer?.play()
        print("[TransparentVideo] ▶️ Playing synchronized RGB and Alpha videos")
        ARLog.debug("▶️ Playing synchronized RGB and Alpha videos")
    }
    
    func pause() {
        // Stop display link
        displayLink?.invalidate()
        displayLink = nil
        
        // Pause videos
        rgbPlayer?.pause()
        alphaPlayer?.pause()
        print("[TransparentVideo] ⏸️ Paused RGB and Alpha videos")
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
            print("[TransparentVideo] ❌ Failed to create Metal textures from pixel buffers")
            ARLog.error("Failed to create Metal textures from pixel buffers")
            return
        }
        
        // Get Metal textures from CV textures
        let rgbTexture = CVMetalTextureGetTexture(rgbTextureRef)
        let alphaTexture = CVMetalTextureGetTexture(alphaTextureRef)
        
        guard let rgbTexture = rgbTexture,
              let alphaTexture = alphaTexture else {
            print("[TransparentVideo] ❌ Failed to get Metal textures")
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
            print("[TransparentVideo] ❌ Failed to create command buffer")
            ARLog.error("Failed to create command buffer")
            return
        }
        
        // Create render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            print("[TransparentVideo] ❌ Failed to create render encoder")
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
            print("[TransparentVideo] ❌ Failed to create vertex buffer")
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
                print("[TransparentVideo] ✅ RGB video ready to play")
                ARLog.debug("✅ RGB video ready to play")
                isRGBReady = true
                // Only preroll when it's ready to play
                rgbPlayer?.preroll(atRate: 1.0)
                checkIfBothVideosReady()
            case .failed:
                print("[TransparentVideo] ❌ RGB video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                ARLog.error("RGB video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                onErrorCallback?(playerItem.error ?? NSError(domain: "TransparentVideoPlayer", code: 1, userInfo: nil))
            default:
                break
            }
        } else if playerItem == alphaPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                print("[TransparentVideo] ✅ Alpha video ready to play")
                ARLog.debug("✅ Alpha video ready to play")
                isAlphaReady = true
                // Only preroll when it's ready to play
                alphaPlayer?.preroll(atRate: 1.0)
                checkIfBothVideosReady()
            case .failed:
                print("[TransparentVideo] ❌ Alpha video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                ARLog.error("Alpha video failed: \(playerItem.error?.localizedDescription ?? "Unknown error")")
                onErrorCallback?(playerItem.error ?? NSError(domain: "TransparentVideoPlayer", code: 2, userInfo: nil))
            default:
                break
            }
        }
    }
    
    private func checkIfBothVideosReady() {
        if isRGBReady && isAlphaReady {
            print("[TransparentVideo] ✅ Both RGB and Alpha videos are ready")
            ARLog.debug("✅ Both RGB and Alpha videos are ready")
            // Update video size from the actual asset
            if let playerItem = rgbPlayerItem, #available(iOS 16.0, *) {
                // Using a non-capturing async Task with the new API
                Task.detached {
                    if let track = try? await playerItem.asset.loadTracks(withMediaType: .video).first {
                        let size = try? await track.load(.naturalSize)
                        let videoSize = size ?? CGSize(width: 1280, height: 720)
                        print("[TransparentVideo] 📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                        ARLog.debug("📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                        
                        // Update on main thread
                        await MainActor.run {
                            self.videoSize = videoSize
                            // Recreate texture with new dimensions
                            self.setupCombinedTexture()
                            self.onReadyCallback?()
                        }
                    } else {
                        await MainActor.run {
                            self.onReadyCallback?()
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                #if compiler(>=5.7)
                if #available(iOS 16.0, *) {
                    // This code should not be reached, but compiler needs it
                    // for full coverage of if/else branch
                    Task.detached {
                        await MainActor.run {
                            self.onReadyCallback?()
                        }
                    }
                } else {
                    // Old API for iOS 15 and below
                    if let track = rgbPlayerItem?.asset.tracks(withMediaType: .video).first {
                        videoSize = track.naturalSize
                        print("[TransparentVideo] 📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                        ARLog.debug("📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                        
                        // Recreate texture with new dimensions
                        setupCombinedTexture()
                    }
                    // Notify ready
                    onReadyCallback?()
                }
                #else
                // Older Swift compiler needs a different approach
                if let track = rgbPlayerItem?.asset.tracks(withMediaType: .video).first {
                    videoSize = track.naturalSize
                    print("[TransparentVideo] 📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                    ARLog.debug("📐 Video dimensions: \(videoSize.width) x \(videoSize.height)")
                    
                    // Recreate texture with new dimensions
                    setupCombinedTexture()
                }
                // Notify ready
                onReadyCallback?()
                #endif
            }
        }
    }
    
    @objc private func playerItemDidReachEnd(notification: Notification) {
        // Loop both videos when one reaches the end
        rgbPlayer?.seek(to: .zero)
        alphaPlayer?.seek(to: .zero)
        rgbPlayer?.play()
        alphaPlayer?.play()
        print("[TransparentVideo] 🔄 Video reached end, looping back to start")
        ARLog.debug("🔄 Video reached end, looping back to start")
    }
    
    // MARK: - Cleanup
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        
        rgbPlayerItem?.removeObserver(self, forKeyPath: "status")
        alphaPlayerItem?.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
        
        rgbPlayer?.pause()
        alphaPlayer?.pause()
        rgbPlayer = nil
        alphaPlayer = nil
    }
} 