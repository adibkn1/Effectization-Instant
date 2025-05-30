import UIKit

/// A view that shows an activity spinner with a descriptive label
class LoadingView: UIView {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [spinner, messageLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Initially hide the view
        isHidden = true
    }

    /// Updates the text displayed in the label
    func updateText(text: String) {
        messageLabel.text = text
    }
    
    /// Shows the view without animation
    func show() {
        spinner.startAnimating()
        isHidden = false
    }
    
    /// Hides the view without animation
    func hide() {
        spinner.stopAnimating()
        isHidden = true
    }

    /// Starts animating and shows the view
    func start(with message: String) {
        messageLabel.text = message
        spinner.startAnimating()
        isHidden = false
    }

    /// Stops animating and hides the view
    func stop() {
        spinner.stopAnimating()
        isHidden = true
    }
} 