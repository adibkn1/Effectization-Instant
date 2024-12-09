//
//  Custom Tab Bar view.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit
//import SwiftUI

class MainTabBarController: UITabBarController {
    
    private let customTabBar = CustomTabBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupCustomTabBar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBar.isHidden = true
    }
    
    private func setupViewControllers() {
        let homeVC = HomeViewController()
        let qrVC = QRViewController()
        let formVC = FormViewController()
        
        // Configure tab bar items with standard iOS size (20pt)
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        
        homeVC.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "house.fill", withConfiguration: configuration),
            tag: 0
        )
        qrVC.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "qrcode", withConfiguration: configuration),
            tag: 1
        )
        formVC.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "envelope.fill", withConfiguration: configuration),
            tag: 2
        )
        
        setViewControllers([homeVC, qrVC, formVC], animated: false)
        selectedIndex = 0
    }
    
    private func setupCustomTabBar() {
        view.addSubview(customTabBar)
        customTabBar.delegate = self
        
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            customTabBar.heightAnchor.constraint(equalToConstant: 88) // Height including safe area
        ])
        
        customTabBar.items = viewControllers?.map { $0.tabBarItem }
        customTabBar.selectedItem = customTabBar.items?[selectedIndex]
    }
}
