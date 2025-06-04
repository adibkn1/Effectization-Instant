import UIKit

/// A view that displays a Call-to-Action button with custom styling
class CTAButtonView: UIView {
    private let button = UIButton(type: .custom)
    private var tapAction: (() -> Void)?
    private var buttonText: String = ""
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Set up the button with default styling
        button.layer.cornerRadius = 25
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap handling
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        // Add to view hierarchy
        addSubview(button)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    /// Configure the button with text, color, and tap action
    func configure(text: String, colorHex: String, action: @escaping () -> Void) {
        // Store button text for analytics
        self.buttonText = text
        
        // Update button text
        button.setTitle(text, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        
        // Update button color
        let hexColor = colorHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if let buttonColor = UIColor(hexString: hexColor) {
            button.backgroundColor = buttonColor
        } else {
            // Default color if parsing fails
            button.backgroundColor = UIColor(red: 248/255, green: 75/255, blue: 7/255, alpha: 1.0)
        }
        
        // Store the tap action
        tapAction = action
    }
    
    @objc private func buttonTapped() {
        // Track button tap event with analytics
        AnalyticsManager.shared.trackButtonTap(buttonName: buttonText, screenName: "AR Experience")
        
        // Call the action
        tapAction?()
    }
    
    /// Show the button
    func show() {
        isHidden = false
    }
    
    /// Hide the button
    func hide() {
        isHidden = true
    }
} 