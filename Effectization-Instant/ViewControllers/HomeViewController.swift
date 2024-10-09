//
//  HomeViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit
import AVFoundation

class HomeViewController: UIViewController {
    
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
    }
    
    func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        contentView.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor).isActive = true
    }
    
    private func companyLogo() {
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 70),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            logoImageView.heightAnchor.constraint(equalToConstant: 65),
            logoImageView.widthAnchor.constraint(equalToConstant: 65)
        ])
    }
    
    private func companyName() {
        let label = UILabel()
        label.text = "Effectization\nStudio"
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 24)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 70),
            label.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 13),
        ])
    }
    
    func middleLabelWithSquare() {
        squareView.layer.borderColor = UIColor.white.cgColor
        squareView.layer.borderWidth = 0.6
        squareView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(squareView)
        
        let label = UILabel()
        label.text = "Connecting brands to\npeople using\nMixed Reality"
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 5
        label.font = UIFont.boldSystemFont(ofSize: 40)
        label.translatesAutoresizingMaskIntoConstraints = false
        squareView.addSubview(label)
        
        NSLayoutConstraint.activate([
            squareView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            squareView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            squareView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 50),
            squareView.heightAnchor.constraint(equalToConstant: 270)
        ])
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: squareView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: squareView.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: squareView.centerYAnchor)
        ])
        
        addTinySquares(to: squareView)
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
        descriptionLabel.text = "Instantly bring print ad to life to play a\nvideo, see a 3D object, play an audio or\nmore, WITHOUT the need to download\nany app or open a web browser. Watch\nthe video below to see how it works"
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 5
        descriptionLabel.font = UIFont.systemFont(ofSize: 17)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: squareView.bottomAnchor, constant: 40),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        ])
    }
    
    
    func setupStepViews() {
        step1View.step = 1
        step1View.content = "User scans the QR code on the print ad or creative."
        contentView.addSubview(step1View)
        
        step2View.step = 2
        step2View.content = "Follow on screen instructions, point to the key visual on the print ad and see it come to life."
        contentView.addSubview(step2View)
        
        step1View.translatesAutoresizingMaskIntoConstraints = false
        step2View.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            step1View.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            step1View.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            step1View.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            step2View.topAnchor.constraint(equalTo: step1View.bottomAnchor, constant: 20),
            step2View.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            step2View.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    
    func setupFeaturesView() {
        featuresContainerView.backgroundColor = .clear
        contentView.addSubview(featuresContainerView)
        
        featuresContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            featuresContainerView.topAnchor.constraint(equalTo: step2View.bottomAnchor, constant: 40),
            featuresContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuresContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
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
                featureRow.leadingAnchor.constraint(equalTo: featuresContainerView.leadingAnchor),
                featureRow.trailingAnchor.constraint(equalTo: featuresContainerView.trailingAnchor),
                featureRow.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            if let previousView = previousView {
                featureRow.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 16).isActive = true
            } else {
                featureRow.topAnchor.constraint(equalTo: featuresContainerView.topAnchor).isActive = true
            }
            
            if index < features.count - 1 {
                let separator = SeparatorView()
                featuresContainerView.addSubview(separator)
                separator.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    separator.topAnchor.constraint(equalTo: featureRow.bottomAnchor, constant: 8),
                    separator.leadingAnchor.constraint(equalTo: featuresContainerView.leadingAnchor),
                    separator.trailingAnchor.constraint(equalTo: featuresContainerView.trailingAnchor),
                    separator.heightAnchor.constraint(equalToConstant: 1)
                ])
                
                previousView = separator
            } else {
                featureRow.bottomAnchor.constraint(equalTo: featuresContainerView.bottomAnchor).isActive = true
            }
            
            previousView = featureRow
        }
    }
    
    
    func setupVideoPlayer() {
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(videoContainerView)

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: featuresContainerView.bottomAnchor, constant: 20),
            videoContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            videoContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            videoContainerView.heightAnchor.constraint(equalToConstant: 450) // Set the desired height for the video view
        ])

        // Replace this with your remote video URL
        guard let videoURL = URL(string: "https://effectizationstudio.com/iosHomePage") else {
            return
        }

        player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = videoContainerView.bounds
        playerLayer.masksToBounds = true

        videoContainerView.layer.addSublayer(playerLayer)
        videoContainerView.layer.layoutIfNeeded()

        // Observe when the video finishes playing to replay it
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(replayVideo),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)

        player?.play()

        videoContainerView.layer.masksToBounds = true
        self.playerLayer = playerLayer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = videoContainerView.bounds
    }

    @objc func replayVideo() {
        playerLayer?.player?.seek(to: .zero)
        playerLayer?.player?.play()
    }

        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    
    
    func endingLabels() {
        
        label1.text = "Bring any of your print\ncollaterals to life -"
        label1.textColor = .white
        label1.textAlignment = .left
        label1.numberOfLines = 2
        label1.font = UIFont.systemFont(ofSize: 30, weight: .thin)
        label1.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label1)
        
        label2.text = "Newspaper ads, magazine ads, brochures, collaterals, hoardings, standees and more."
        label2.textColor = .white
        label2.textAlignment = .left
        label2.numberOfLines = 4
        label2.font = UIFont.boldSystemFont(ofSize: 30)
        label2.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label2)
        
        label3.text = "Instant AR on print is powered by technology,\nbuilt by Effectization Studio"
        label3.textColor = .white
        label3.textAlignment = .left
        label3.numberOfLines = 4
        label3.font = UIFont.boldSystemFont(ofSize: 16)
        label3.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label3)
        
        NSLayoutConstraint.activate([
            label1.topAnchor.constraint(equalTo: videoContainerView.bottomAnchor, constant: 40),
            label1.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            label1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            label2.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 10),
            label2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            label2.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            label3.topAnchor.constraint(equalTo: label2.bottomAnchor, constant: 40),
            label3.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            label3.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            label3.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -85)
        ])
    }
    
    
    private func addGradientWithBlackBackground() {
        let gradientLayer = CAGradientLayer()
        
        gradientLayer.colors = [
            UIColor.systemPink.withAlphaComponent(0.7).cgColor,
            UIColor.black.cgColor,
            UIColor.black.cgColor,
            UIColor.purple.withAlphaComponent(0.7).cgColor
        ]
        
        gradientLayer.locations = [0.0, 0.2, 0.8, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        gradientLayer.frame = view.bounds
        
        view.layer.addSublayer(gradientLayer)
    }
}



