//
//  SeparatorView.swift
//  QR Scanner
//
//  Created by Swarup Panda on 05/10/24.
//

import UIKit

class SeparatorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white.withAlphaComponent(0.1)
    }
}

