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
        
        layer.cornerRadius = 20
        layer.masksToBounds = true
        
        layer.borderWidth = 2
        layer.borderColor = UIColor.clear.cgColor
        
        let appearance = UITabBarAppearance()
        appearance.stackedLayoutAppearance.normal.iconColor = .white
        appearance.stackedLayoutAppearance.selected.iconColor = .yellow
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
    }
}
