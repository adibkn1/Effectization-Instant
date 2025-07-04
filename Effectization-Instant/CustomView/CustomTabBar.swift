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
        // Set background color to match theme
        backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 0.95)
        
        // Remove default border
        backgroundImage = UIImage()
        shadowImage = UIImage()
        
        // Remove corner radius for full-width design
        layer.cornerRadius = 0
        layer.masksToBounds = true
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(blurView, at: 0)
        
        // Add subtle top border
        let topBorder = UIView()
        topBorder.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        topBorder.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        topBorder.autoresizingMask = [.flexibleWidth]
        addSubview(topBorder)
        
        // Configure appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
        
        // Selected state - using theme blue color
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        
        standardAppearance = appearance
        scrollEdgeAppearance = appearance
        
        // Adjust item positioning
        itemPositioning = .centered
        itemSpacing = 80 // Increased spacing between items
    }
    
    // Handle tab item taps
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else { return nil }
        
        // If we tapped on the tab bar
        if result == self {
            // Find the index of the tapped item
            if let items = items {
                let tabBarWidth = bounds.width
                let itemCount = CGFloat(items.count)
                let itemWidth = tabBarWidth / itemCount
                
                let index = Int(point.x / itemWidth)
                if index >= 0 && index < items.count {
                    // Notify about tab selection
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TabSelectionChanged"),
                        object: self,
                        userInfo: ["selectedIndex": index]
                    )
                    
                    // Update selected item
                    selectedItem = items[index]
                    
                    // Delegate will handle the actual tab change
                }
            }
        }
        
        return result
    }
}
