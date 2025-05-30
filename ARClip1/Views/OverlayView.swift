import UIKit

/// A view that shows an image with a label underneath (e.g. "Scan this image").
class OverlayView: UIView {
  private let imageView = UIImageView()
  private let textLabel = UILabel()
  
  /// Current image (for external reference)
  var image: UIImage? {
    return imageView.image
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupViews()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupViews()
  }

  private func setupViews() {
    // Transparent background so you can still see the camera feed
    backgroundColor = .clear

    // Image view styling
    imageView.contentMode = .scaleAspectFit
    imageView.translatesAutoresizingMaskIntoConstraints = false

    // Label styling
    textLabel.font = .systemFont(ofSize: 22, weight: .semibold)
    textLabel.textColor = .white
    textLabel.textAlignment = .center
    textLabel.translatesAutoresizingMaskIntoConstraints = false

    // Stack them vertically
    let stack = UIStackView(arrangedSubviews: [imageView, textLabel])
    stack.axis = .vertical
    stack.spacing = 24
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)

    // Center stack in the view
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: centerYAnchor),
      imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9),
      imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
    ])
  }

  /// Configure the overlay's image, text, and opacity
  func configure(image: UIImage?, text: String, opacity: CGFloat = 1.0) {
    imageView.image = image
    textLabel.text = text
    imageView.alpha = opacity
  }
  
  /// Update just the image
  func updateImage(image: UIImage?) {
    imageView.image = image
  }
  
  /// Update just the text
  func updateText(text: String) {
    textLabel.text = text
  }
  
  /// Update just the opacity
  func updateOpacity(opacity: CGFloat) {
    imageView.alpha = opacity
  }

  /// Show the overlay
  func show() {
    isHidden = false
  }

  /// Hide the overlay
  func hide() {
    isHidden = true
  }
} 
 