//
//  StepView.swift
//  QR Scanner
//
//  Created by Swarup Panda on 05/10/24.
//

import UIKit

class StepView: UIView {
    var step: Int = 1 {
        didSet {
            updateStepLabel()
        }
    }
    
    var content: String = "" {
        didSet {
            contentLabel.text = content
        }
    }
    
    private let stepLabel = UILabel()
    private let contentLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Step label styling
        stepLabel.textColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        stepLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        stepLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stepLabel)
        
        // Content label styling
        contentLabel.textColor = .white
        contentLabel.font = .systemFont(ofSize: 17, weight: .regular)
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            stepLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stepLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            contentLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }
    
    private func updateStepLabel() {
        stepLabel.text = "STEP \(step)"
    }
}
