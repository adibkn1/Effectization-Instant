// This file defines the entry point for the app clip
import SwiftUI

@main
struct ARClip1App: App {
    @State private var launchURL: URL?
    @State private var folderID: String = "ar" // Default folderID
    
    init() {
        // Check environment variable at launch time
        if let envURLString = ProcessInfo.processInfo.environment["_XCAppClipURL"],
           let envURL = URL(string: envURLString) {
            print("[App] Found environment URL at startup: \(envURLString)")
            
            // Pre-extract folderID
            if let extractedID = extractFolderIDFromURL(envURL) {
                print("[App] Pre-extracted folderID from environment: \(extractedID)")
                
                // We can't set @State variables directly in init,
                // but we can set initial values for these properties
                _folderID = State(initialValue: extractedID)
                _launchURL = State(initialValue: envURL)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ARContentView(launchURL: launchURL)
                .edgesIgnoringSafeArea(.all)
                .statusBar(hidden: true)
                .onAppear {
                    print("[App] onAppear with launchURL: \(launchURL?.absoluteString ?? "nil")")
                    print("[App] Current folderID: \(folderID)")
                    
                    // Check environment again if needed
                    if launchURL == nil, 
                       let envURLString = ProcessInfo.processInfo.environment["_XCAppClipURL"],
                       let envURL = URL(string: envURLString) {
                        print("[App] Using environment URL: \(envURLString)")
                        
                        // Important: Wait until next run loop to set the URL
                        // This prevents a race condition during initialization
                        DispatchQueue.main.async {
                            self.launchURL = envURL
                        }
                    }
                }
                .onOpenURL { url in
                    // Handle URL when app is opened via URL
                    print("[App] Received URL: \(url.absoluteString)")
                    
                    // Extract folderID from URL
                    if let extractedID = extractFolderIDFromURL(url) {
                        folderID = extractedID
                        print("[App] Extracted folderID: \(folderID)")
                    } else {
                        folderID = "ar" // Default
                        print("[App] Could not extract folderID, using default: ar")
                    }
                    
                    launchURL = url
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
}
