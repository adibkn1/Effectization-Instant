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
        
        homeVC.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "house.fill"), tag: 0)
        qrVC.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "qrcode"), tag: 1)
        formVC.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "envelope.fill"), tag: 2)
        
        setViewControllers([homeVC, qrVC, formVC], animated: false)
        selectedIndex = 0
    }
    
    private func setupCustomTabBar() {
        view.addSubview(customTabBar)
        customTabBar.delegate = self
        
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            customTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            customTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            customTabBar.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        customTabBar.items = viewControllers?.map { $0.tabBarItem }
        customTabBar.selectedItem = customTabBar.items?[selectedIndex]
    }
}
