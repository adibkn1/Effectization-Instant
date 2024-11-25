//
//  CustomTabBar.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit

class CustomTabBar: UITabBar {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTabBar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTabBar()
    }
    
    private func setupTabBar() {
        backgroundColor = .black
        
        backgroundImage = UIImage()
        shadowImage = UIImage()
        
        layer.cornerRadius = 30
        layer.masksToBounds = true
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]

        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.yellow
        ]

        let appearance = UITabBarAppearance()
        
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -5)
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -5)
        
        appearance.stackedLayoutAppearance.selected.iconColor = .yellow
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
}

