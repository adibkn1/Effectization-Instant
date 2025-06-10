//
//  HomeViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit
import AVFoundation

class HomeViewController: UIViewController, UIScrollViewDelegate {
    
    let logoImageView = UIImageView()
    let scrollView = UIScrollView()
    
    let contentView = UIView()
    let squareView = UIView()
    let videoContainerView = UIView()
    
    let descriptionLabel = UILabel()
    
    let step1View = StepView()
    let step2View = StepView()
    
    let featuresContainerView = UIView()
    
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    
    let label1 = UILabel()
    let label2 = UILabel()
    let label3 = UILabel()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addGradientWithBlackBackground()
        setupScrollView()
        setupContentView()
        companyLogo()
        companyName()
        middleLabelWithSquare()
        description()
        setupStepViews()
        setupFeaturesView()
        setupVideoPlayer()
        endingLabels()
        
        // Add bottom constraint after all views are set up
        if let lastView = contentView.subviews.last {
            NSLayoutConstraint.activate([
                lastView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
            ])
        }
        
        scrollView.delegate = self
    }
    
    func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false  // Hide vertical scroll indicator
        scrollView.showsHorizontalScrollIndicator = false  // Hide horizontal scroll indicator
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -88),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    private func companyLogo() {
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.alpha = 0.9
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoImageView.heightAnchor.constraint(equalToConstant: 44),
            logoImageView.widthAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func companyName() {
        let label = UILabel()
        label.text = "Effectization Studio"
        label.textColor = .white
        label.textAlignment = .left
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        let sublabel = UILabel()
        sublabel.text = "AI-Powered Mixed Reality"
        sublabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0) // Soft blue accent
        sublabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sublabel)
        
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 12),
            
            sublabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2),
            sublabel.leadingAnchor.constraint(equalTo: label.leadingAnchor)
        ])
    }
    
    func middleLabelWithSquare() {
        squareView.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1.0)
        squareView.layer.cornerRadius = 24
        squareView.layer.borderWidth = 1
        squareView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        squareView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(squareView)
        
        let label = UILabel()
        let attributedString = NSMutableAttributedString(string: "Transform\nPrint Media\ninto ", attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 44, weight: .regular)
        ])
        
        // Add "Interactive" with accent color
        attributedString.append(NSAttributedString(string: "Interactive\n", attributes: [
            .foregroundColor: UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 44, weight: .semibold)
        ]))
        
        // Add "Experiences" with regular weight
        attributedString.append(NSAttributedString(string: "Experiences", attributes: [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 44, weight: .regular)
        ]))
        
        label.attributedText = attributedString
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        squareView.addSubview(label)
        
        NSLayoutConstraint.activate([
            squareView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            squareView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            squareView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 32),
            squareView.heightAnchor.constraint(equalToConstant: 320),
            
            label.leadingAnchor.constraint(equalTo: squareView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: squareView.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: squareView.centerYAnchor)
        ])
        
        addFloatingShapes(to: squareView)
    }
    
    
    func addTinySquares(to squareView: UIView) {
        let tinySquareSize: CGFloat = 8.0
        
        // Top-left corner square
        let topLeftSquare = createTinySquare()
        squareView.addSubview(topLeftSquare)
        NSLayoutConstraint.activate([
            topLeftSquare.topAnchor.constraint(equalTo: squareView.topAnchor, constant: -tinySquareSize / 2),
            topLeftSquare.leadingAnchor.constraint(equalTo: squareView.leadingAnchor, constant: -tinySquareSize / 2),
            topLeftSquare.widthAnchor.constraint(equalToConstant: tinySquareSize),
            topLeftSquare.heightAnchor.constraint(equalToConstant: tinySquareSize)
        ])
        
        // Top-right corner square
        let topRightSquare = createTinySquare()
        squareView.addSubview(topRightSquare)
        NSLayoutConstraint.activate([
            topRightSquare.topAnchor.constraint(equalTo: squareView.topAnchor, constant: -tinySquareSize / 2),
            topRightSquare.trailingAnchor.constraint(equalTo: squareView.trailingAnchor, constant: tinySquareSize / 2),
            topRightSquare.widthAnchor.constraint(equalToConstant: tinySquareSize),
            topRightSquare.heightAnchor.constraint(equalToConstant: tinySquareSize)
        ])
        
        // Bottom-left corner square
        let bottomLeftSquare = createTinySquare()
        squareView.addSubview(bottomLeftSquare)
        NSLayoutConstraint.activate([
            bottomLeftSquare.bottomAnchor.constraint(equalTo: squareView.bottomAnchor, constant: tinySquareSize / 2),
            bottomLeftSquare.leadingAnchor.constraint(equalTo: squareView.leadingAnchor, constant: -tinySquareSize / 2),
            bottomLeftSquare.widthAnchor.constraint(equalToConstant: tinySquareSize),
            bottomLeftSquare.heightAnchor.constraint(equalToConstant: tinySquareSize)
        ])
        
        // Bottom-right corner square
        let bottomRightSquare = createTinySquare()
        squareView.addSubview(bottomRightSquare)
        NSLayoutConstraint.activate([
            bottomRightSquare.bottomAnchor.constraint(equalTo: squareView.bottomAnchor, constant: tinySquareSize / 2),
            bottomRightSquare.trailingAnchor.constraint(equalTo: squareView.trailingAnchor, constant: tinySquareSize / 2),
            bottomRightSquare.widthAnchor.constraint(equalToConstant: tinySquareSize),
            bottomRightSquare.heightAnchor.constraint(equalToConstant: tinySquareSize)
        ])
    }
    
    func createTinySquare() -> UIView {
        let tinySquare = UIView()
        tinySquare.backgroundColor = .white
        tinySquare.translatesAutoresizingMaskIntoConstraints = false
        return tinySquare
    }
    
    func description() {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        container.layer.cornerRadius = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        
        descriptionLabel.text = "Experience print media like never before with our AI-powered Mixed Reality solution. Watch your ads transform into interactive experiences - no apps, no browsers, just pure innovation."
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: squareView.bottomAnchor, constant: 32),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            descriptionLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])
    }
    
    
    func setupStepViews() {
        let stepViewsContainer = UIView()
        stepViewsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stepViewsContainer)
        
        step1View.step = 1
        step1View.content = "User scans the QR code on the print ad or creative."
        step1View.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        step1View.layer.cornerRadius = 16
        stepViewsContainer.addSubview(step1View)
        
        step2View.step = 2
        step2View.content = "Follow on screen instructions, point to the key visual on the print ad and see it come to life."
        step2View.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        step2View.layer.cornerRadius = 16
        stepViewsContainer.addSubview(step2View)
        
        step1View.translatesAutoresizingMaskIntoConstraints = false
        step2View.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stepViewsContainer.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            stepViewsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stepViewsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            step1View.topAnchor.constraint(equalTo: stepViewsContainer.topAnchor),
            step1View.leadingAnchor.constraint(equalTo: stepViewsContainer.leadingAnchor),
            step1View.trailingAnchor.constraint(equalTo: stepViewsContainer.trailingAnchor),
            
            step2View.topAnchor.constraint(equalTo: step1View.bottomAnchor, constant: 16),
            step2View.leadingAnchor.constraint(equalTo: stepViewsContainer.leadingAnchor),
            step2View.trailingAnchor.constraint(equalTo: stepViewsContainer.trailingAnchor),
            step2View.bottomAnchor.constraint(equalTo: stepViewsContainer.bottomAnchor)
        ])
    }
    
    
    func setupFeaturesView() {
        featuresContainerView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        featuresContainerView.layer.cornerRadius = 20
        contentView.addSubview(featuresContainerView)
        
        featuresContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            featuresContainerView.topAnchor.constraint(equalTo: step2View.bottomAnchor, constant: 32),
            featuresContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            featuresContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        
        let features = [
            ("xmark.circle.fill", "No app download"),
            ("safari", "No web browser"),
            ("clock", "Frictionless & quick"),
            ("bolt.fill", "Instant experience")
        ]
        
        var previousView: UIView?
        
        for (index, (iconName, text)) in features.enumerated() {
            let featureRow = FeatureRowView()
            featureRow.iconName = iconName
            featureRow.text = text
            featuresContainerView.addSubview(featureRow)
            
            featureRow.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                featureRow.leadingAnchor.constraint(equalTo: featuresContainerView.leadingAnchor, constant: 16),
                featureRow.trailingAnchor.constraint(equalTo: featuresContainerView.trailingAnchor, constant: -16),
                featureRow.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            if let previousView = previousView {
                featureRow.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 16).isActive = true
            } else {
                featureRow.topAnchor.constraint(equalTo: featuresContainerView.topAnchor, constant: 16).isActive = true
            }
            
            if index == features.count - 1 {
                featureRow.bottomAnchor.constraint(equalTo: featuresContainerView.bottomAnchor, constant: -16).isActive = true
            }
            
            previousView = featureRow
        }
    }
    
    
    func setupVideoPlayer() {
        let videoContainer = UIView()
        videoContainer.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        videoContainer.layer.cornerRadius = 20
        videoContainer.clipsToBounds = true
        videoContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(videoContainer)
        
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(videoContainerView)

        NSLayoutConstraint.activate([
            videoContainer.topAnchor.constraint(equalTo: featuresContainerView.bottomAnchor, constant: 32),
            videoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            videoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            videoContainer.heightAnchor.constraint(equalToConstant: 500),
            
            videoContainerView.topAnchor.constraint(equalTo: videoContainer.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: videoContainer.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: videoContainer.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: videoContainer.bottomAnchor)
        ])

        // Add loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        videoContainer.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: videoContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: videoContainer.centerYAnchor)
        ])
        
        loadingIndicator.startAnimating()

        // Configure audio session first
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }

        guard let videoURL = URL(string: "https://adagxr.com/app_data/assets/homeVideo.mp4") else {
            print("Invalid video URL")
            return
        }

        // Create asset options for better loading
        let assetOptions = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let asset = AVURLAsset(url: videoURL, options: assetOptions)
        
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let isPlayable = try await asset.load(.isPlayable)
                    guard isPlayable else {
                        await MainActor.run {
                            print("Asset is not playable")
                            loadingIndicator.stopAnimating()
                            handleVideoError()
                        }
                        return
                    }
                    
                    await MainActor.run {
                        setupPlayerWithAsset(asset, loadingIndicator: loadingIndicator)
                    }
                } catch {
                    await MainActor.run {
                        print("Failed to load video asset: \(error.localizedDescription)")
                        loadingIndicator.stopAnimating()
                        handleVideoError()
                    }
                }
            }
        } else {
            // Fallback for iOS 15 and earlier
            asset.loadValuesAsynchronously(forKeys: ["playable"]) { [weak self] in
                DispatchQueue.main.async {
                    self?.setupPlayerWithAsset(asset, loadingIndicator: loadingIndicator)
                }
            }
        }
    }
    
    private func setupPlayerWithAsset(_ asset: AVURLAsset, loadingIndicator: UIActivityIndicatorView) {
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.isMuted = true
        
        self.playerLayer = AVPlayerLayer(player: self.player)
        self.playerLayer?.videoGravity = .resizeAspectFill
        self.playerLayer?.frame = self.videoContainerView.bounds
        
        if let playerLayer = self.playerLayer {
            self.videoContainerView.layer.addSublayer(playerLayer)
        }
        
        // Add observers after successful loading
        self.addPlayerObservers()
        self.player?.play()
        loadingIndicator.stopAnimating()
    }
    
    private func addPlayerObservers() {
        // Add observer for item status
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(replayVideo),
                                             name: .AVPlayerItemDidPlayToEndTime,
                                             object: player?.currentItem)
                                             
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleEnterBackground),
                                             name: UIApplication.didEnterBackgroundNotification,
                                             object: nil)
                                             
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleEnterForeground),
                                             name: UIApplication.willEnterForegroundNotification,
                                             object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            if let player = object as? AVPlayer {
                handlePlayerStatus(player)
            } else if let playerItem = object as? AVPlayerItem {
                handlePlayerItemStatus(playerItem)
            }
        }
    }
    
    private func handlePlayerStatus(_ player: AVPlayer) {
        DispatchQueue.main.async {
            if player.status == .readyToPlay {
                player.play()
            } else if player.status == .failed {
                print("Player failed: \(String(describing: player.error?.localizedDescription))")
                self.handleVideoError()
            }
        }
    }
    
    private func handlePlayerItemStatus(_ playerItem: AVPlayerItem) {
        DispatchQueue.main.async {
            if playerItem.status == .failed {
                print("PlayerItem failed: \(String(describing: playerItem.error?.localizedDescription))")
                self.handleVideoError()
            }
        }
    }
    
    private func handleVideoError() {
        // Implement retry logic or show error UI
        print("Video playback error occurred")
    }
    
    @objc private func handleEnterBackground() {
        player?.pause()
    }
    
    @objc private func handleEnterForeground() {
        player?.play()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let player = player {
            player.removeObserver(self, forKeyPath: "status")
        }
        if let playerItem = player?.currentItem {
            playerItem.removeObserver(self, forKeyPath: "status")
        }
    }

    
    
    func endingLabels() {
        let endingContainer = UIView()
        endingContainer.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1.0)
        endingContainer.layer.cornerRadius = 20
        endingContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(endingContainer)
        
        // Title
        label1.text = "Bring any of your print\ncollaterals to life"
        label1.textColor = .white
        label1.textAlignment = .left
        label1.numberOfLines = 2
        label1.font = UIFont.systemFont(ofSize: 32, weight: .regular)
        label1.translatesAutoresizingMaskIntoConstraints = false
        endingContainer.addSubview(label1)
        
        // Subtitle with examples
        label2.text = "Newspaper ads, magazine ads, brochures, collaterals, hoardings, standees and more."
        label2.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        label2.textAlignment = .left
        label2.numberOfLines = 0
        label2.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label2.translatesAutoresizingMaskIntoConstraints = false
        endingContainer.addSubview(label2)
        
        // Footer text
        label3.text = "Adagxr Instant AR on print is powered by technology, built by Effectization Studio"
        label3.textColor = UIColor.white.withAlphaComponent(0.6)
        label3.textAlignment = .left
        label3.numberOfLines = 0
        label3.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label3.translatesAutoresizingMaskIntoConstraints = false
        endingContainer.addSubview(label3)
        
        NSLayoutConstraint.activate([
            endingContainer.topAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: 24),
            endingContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            endingContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            endingContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),
            
            label1.topAnchor.constraint(equalTo: endingContainer.topAnchor, constant: 32),
            label1.leadingAnchor.constraint(equalTo: endingContainer.leadingAnchor, constant: 24),
            label1.trailingAnchor.constraint(equalTo: endingContainer.trailingAnchor, constant: -24),
            
            label2.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 16),
            label2.leadingAnchor.constraint(equalTo: endingContainer.leadingAnchor, constant: 24),
            label2.trailingAnchor.constraint(equalTo: endingContainer.trailingAnchor, constant: -24),
            
            label3.topAnchor.constraint(equalTo: label2.bottomAnchor, constant: 24),
            label3.leadingAnchor.constraint(equalTo: endingContainer.leadingAnchor, constant: 24),
            label3.trailingAnchor.constraint(equalTo: endingContainer.trailingAnchor, constant: -24),
            label3.bottomAnchor.constraint(equalTo: endingContainer.bottomAnchor, constant: -32)
        ])
    }
    
    
    private func addGradientWithBlackBackground() {
        view.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1.0)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = view.bounds
        gradientLayer.colors = [
            UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func addFloatingShapes(to view: UIView) {
        // Create floating circles
        let circle1 = UIView()
        circle1.backgroundColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.1)
        circle1.layer.cornerRadius = 20
        circle1.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(circle1)
        
        let circle2 = UIView()
        circle2.backgroundColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.05)
        circle2.layer.cornerRadius = 15
        circle2.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(circle2)
        
        // Create floating rectangles
        let rect1 = UIView()
        rect1.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        rect1.layer.cornerRadius = 8
        rect1.transform = CGAffineTransform(rotationAngle: .pi / 6)
        rect1.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(rect1, at: 0)
        
        NSLayoutConstraint.activate([
            circle1.widthAnchor.constraint(equalToConstant: 40),
            circle1.heightAnchor.constraint(equalToConstant: 40),
            circle1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            circle1.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            
            circle2.widthAnchor.constraint(equalToConstant: 30),
            circle2.heightAnchor.constraint(equalToConstant: 30),
            circle2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            circle2.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            
            rect1.widthAnchor.constraint(equalToConstant: 50),
            rect1.heightAnchor.constraint(equalToConstant: 50),
            rect1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            rect1.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40)
        ])
        
        // Add subtle animation
        UIView.animate(withDuration: 2.0, delay: 0, options: [.autoreverse, .repeat], animations: {
            circle1.transform = CGAffineTransform(translationX: 0, y: 10)
            circle2.transform = CGAffineTransform(translationX: 0, y: -10)
            rect1.transform = CGAffineTransform(rotationAngle: .pi / 4)
        })
    }

    @objc func replayVideo() {
        player?.seek(to: .zero)
        player?.play()
    }
}



