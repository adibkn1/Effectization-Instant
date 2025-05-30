import UIKit

/// A view that shows a "No Internet" error message with a retry button
class NoInternetView: UIView {
    private let imageView = UIImageView()
    private let messageLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let contentStack = UIStackView()
    
    /// Called when user taps retry
    var onRetry: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Set background color
        backgroundColor = .black
        
        // Set up image view
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "noInternetClip")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        // Create a gradient overlay for better text visibility
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gradientView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = bounds
        gradientView.layer.addSublayer(gradientLayer)
        
        // Set up labels
        messageLabel.text = "NO INTERNET"
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 24, weight: .bold)
        messageLabel.textAlignment = .center
        
        subtitleLabel.text = "You are not online"
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        subtitleLabel.textAlignment = .center
        
        // Set up content stack
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to stack
        contentStack.addArrangedSubview(messageLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        // Add stack to view
        addSubview(contentStack)
        
        // Set up retry button
        retryButton.setTitle("RETRY", for: .normal)
        retryButton.setTitleColor(.black, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        retryButton.backgroundColor = UIColor(red: 198/255, green: 255/255, blue: 0/255, alpha: 1.0)
        retryButton.layer.cornerRadius = 25
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        addSubview(retryButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Image view (full screen)
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Gradient view
            gradientView.topAnchor.constraint(equalTo: topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Content stack
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.bottomAnchor.constraint(equalTo: retryButton.topAnchor, constant: -24),
            
            // Retry button
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            retryButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient layer frame
        if let gradientView = subviews.first(where: { $0 != imageView && $0 != contentStack && $0 != retryButton }),
           let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = gradientView.bounds
        }
    }
    
    @objc private func retryTapped() {
        onRetry?()
    }
    
    /// Show the no internet view
    func show() {
        isHidden = false
    }
    
    /// Hide the no internet view
    func hide() {
        isHidden = true
    }
} 