import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle any URLs that were used to launch the app
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URLs when app is already running
        if let url = URLContexts.first?.url {
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // Check if it's our App Clip URL
        if url.absoluteString == "https://appclip.apple.com/id?p=Effectization-Studio.Effectization-Instant.Clip" ||
           url.host == "appclip.effectizationstudio.com" ||
           url.absoluteString.contains("adagxr.com/card/") {
            
            print("[Main App] Processing AR URL: \(url.absoluteString)")
            
            // Extract folderID from URL
            let folderID = extractFolderIDFromURL(url) ?? "ar"
            print("[Main App] Using folderID: \(folderID)")
            
            // Present AR view
            DispatchQueue.main.async {
                let arContentView = ARContentView(launchURL: url)
                    .edgesIgnoringSafeArea(.all)
                    .statusBar(hidden: true)
                
                let hostingController = UIHostingController(rootView: arContentView)
                hostingController.modalPresentationStyle = .fullScreen
                hostingController.modalTransitionStyle = .crossDissolve
                
                // Get the current view controller and present AR view
                if let rootViewController = self.window?.rootViewController {
                    rootViewController.present(hostingController, animated: true)
                }
            }
        }
    }
    
    // Helper method to extract folderID from URL
    private func extractFolderIDFromURL(_ url: URL) -> String? {
        // Try path component extraction
        let pathComponents = url.pathComponents.filter { !$0.isEmpty }
        if pathComponents.contains("card") {
            if let cardIndex = pathComponents.firstIndex(of: "card"), cardIndex + 1 < pathComponents.count {
                return pathComponents[cardIndex + 1]
            }
        }
        
        // Try URL path extraction
        if let path = URLComponents(url: url, resolvingAgainstBaseURL: true)?.path {
            let pathComps = path.components(separatedBy: "/").filter { !$0.isEmpty }
            if pathComps.count >= 2 && pathComps[0] == "card" {
                return pathComps[1]
            }
        }
        
        // Try subdomain extraction
        if let host = url.host, host.contains(".") {
            let hostComponents = host.components(separatedBy: ".")
            if hostComponents.count >= 3 && hostComponents[1] == "adagxr" {
                return hostComponents[0]
            }
        }
        
        return nil
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks paused when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene moves from active to inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo changes made when entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save data and release shared resources when entering the background.
    }
}
