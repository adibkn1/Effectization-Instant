import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle any Universal Link passed during launch
        if let userActivity = connectionOptions.userActivities.first {
            handleUserActivity(userActivity)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL {
            print("App Clip invoked with URL: \(url.absoluteString)")

            // Handle App Clip logic based on the URL
            if url.host == "appclip.effectizationstudio.com" && url.path.starts(with: "/app-clip") {
                print("Launching App Clip experience for URL: \(url.absoluteString)")
                // Add your App Clip-specific handling here
            }
        }
    }


    private func handleUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }

        print("Incoming Universal Link: \(url.absoluteString)")

        // Check if the Universal Link is for the App Clip
        if url.host == "appclip.effectizationstudio.com" && url.path.starts(with: "/app-clip") {
            // Open the App Clip or redirect appropriately
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("App Clip launched successfully.")
                } else {
                    print("Failed to launch App Clip.")
                }
            }
        } else {
            // Handle other links (e.g., main app navigation)
            print("Handle main app navigation for the URL: \(url)")
            // Example: Navigate to a specific screen in the main app
        }
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
