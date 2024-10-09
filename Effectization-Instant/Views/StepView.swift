//
//  StepView.swift
//  QR Scanner
//
//  Created by Swarup Panda on 05/10/24.
//

import UIKit

class StepView: UIView {
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    
    var step: Int = 1 {
        didSet {
            titleLabel.text = "STEP \(step)"
        }
    }
    
    var content: String = "" {
        didSet {
            contentLabel.text = content
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
        backgroundColor = .purple
        layer.cornerRadius = 10
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        
        contentLabel.font = UIFont.systemFont(ofSize: 16)
        contentLabel.textColor = .white
        contentLabel.numberOfLines = 0
        
        addSubview(titleLabel)
        addSubview(contentLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
}
