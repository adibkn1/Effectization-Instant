//
//  HorizontalButtonCell.swift
//  QR Scanner
//
//  Created by Swarup Panda on 19/11/24.
//

import UIKit

class HorizontalButtonCell: UICollectionViewCell {
    
    private let buttonLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(buttonLabel)
        
        contentView.backgroundColor = UIColor(red: 35/255, green: 45/255, blue: 60/255, alpha: 1.0)
        contentView.layer.cornerRadius = 22.5
        contentView.clipsToBounds = true
        contentView.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0).cgColor
        contentView.layer.borderWidth = 0.6
        
        NSLayoutConstraint.activate([
            buttonLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            buttonLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            buttonLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 8),
            buttonLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    required init?(coder: NSCoder) { nil }
    
    func configure(with title: String, isSelected: Bool) {
        buttonLabel.text = title
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 60/255, green: 60/255, blue: 60/255, alpha: 1).cgColor,
            UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1).cgColor,
            UIColor.black.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.2, y: 0.4)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.frame = contentView.bounds
        gradientLayer.cornerRadius = contentView.layer.cornerRadius
        gradientLayer.name = "ShinyGradient"
        
        if isSelected {
            contentView.backgroundColor = UIColor(red: 35/255, green: 45/255, blue: 60/255, alpha: 1)
            buttonLabel.textColor = .white
            contentView.layer.borderWidth = 1.0
            contentView.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0).cgColor
            gradientLayer.colors = [
                UIColor(red: 60/255, green: 60/255, blue: 40/255, alpha: 1).cgColor,
                UIColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1).cgColor,
                UIColor.black.cgColor
            ]
            
            removeExistingGradientLayer()
            contentView.layer.insertSublayer(gradientLayer, at: 0)
        } else {
            contentView.backgroundColor = UIColor(red: 35/255, green: 45/255, blue: 60/255, alpha: 0.5)
            buttonLabel.textColor = .white
            contentView.layer.borderWidth = 1.0
            contentView.layer.borderColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 0.4).cgColor
            
            removeExistingGradientLayer()
            contentView.layer.insertSublayer(gradientLayer, at: 0)
        }
    }

    private func removeExistingGradientLayer() {
        if let sublayers = contentView.layer.sublayers {
            for layer in sublayers where layer.name == "ShinyGradient" {
                layer.removeFromSuperlayer()
            }
        }
    }
}

