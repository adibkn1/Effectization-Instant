//
//  SeparatorView.swift
//  QR Scanner
//
//  Created by Swarup Panda on 05/10/24.
//

import UIKit

class FeatureRowView: UIView {
    private let iconImageView = UIImageView()
    private let label = UILabel()
    
    var iconName: String = "" {
        didSet {
            iconImageView.image = UIImage(systemName: iconName)
        }
    }
    
    var text: String = "" {
        didSet {
            label.text = text
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        addSubview(iconImageView)
        addSubview(label)
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            label.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
