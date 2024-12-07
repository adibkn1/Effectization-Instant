//
//  Custom Tab Bar view.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit

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
        let formVC = FormViewController()
        
        homeVC.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "globe"), tag: 0)
        formVC.tabBarItem = UITabBarItem(title: nil, image: UIImage(systemName: "ellipsis.message"), tag: 1)
        
        homeVC.tabBarItem.imageInsets = UIEdgeInsets(top: -10, left: 0, bottom: 100, right: 0)
        formVC.tabBarItem.imageInsets = UIEdgeInsets(top: -10, left: 0, bottom: 100, right: 0)
        
        setViewControllers([homeVC, formVC], animated: false)
        selectedIndex = 0
    }
    
    private func setupCustomTabBar() {
        view.addSubview(customTabBar)
        customTabBar.delegate = self
        
        customTabBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customTabBar.centerXAnchor.constraint(equalTo: view.centerXAnchor), // Center horizontally
            customTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor), // Align to the bottom
            customTabBar.heightAnchor.constraint(equalToConstant: 60), // Set fixed height
            customTabBar.widthAnchor.constraint(equalToConstant: 200) // Set fixed width
        ])
        
        customTabBar.items = viewControllers?.map { $0.tabBarItem }
        customTabBar.selectedItem = customTabBar.items?[selectedIndex]
    }
}
