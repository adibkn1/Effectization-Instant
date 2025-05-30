// This file defines the entry point for the app clip
import SwiftUI

@main
struct ARClip1App: App {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var launchURL: URL?
    @State private var showQRScanner: Bool = false
    @State private var showNoInternet: Bool = false
    @State private var pendingURL: URL?
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showNoInternet {
                    // Wrap NoInternetViewController in UIViewControllerRepresentable
                    NoInternetViewControllerWrapper(initialLink: pendingURL)
                        .edgesIgnoringSafeArea(.all)
                } else if showQRScanner {
                    // Wrap QRViewController in UIViewControllerRepresentable
                    QRViewControllerWrapper()
                        .edgesIgnoringSafeArea(.all)
                } else if launchURL != nil {
                    // Only show AR if we have a valid URL
            ARContentView(launchURL: launchURL)
                .edgesIgnoringSafeArea(.all)
                .statusBar(hidden: true)
                } else {
                    // Fallback view while deciding what to show
                    Color.black
                        .edgesIgnoringSafeArea(.all)
                }
            }
            .onAppear {
                    print("[App] onAppear with launchURL: \(launchURL?.absoluteString ?? "nil")")
                
                // Set up network status change handler
                setupNetworkMonitoring()
            }
            // 1️⃣ Handle "Open URL" events at runtime
            .onOpenURL { url in
                print("[App] Received URL: \(url.absoluteString)")
                handleIncomingURL(url)
            }
            // 2️⃣ Handle initial App Clip invocation via universal link
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL {
                    print("[App] Received URL from user activity: \(url.absoluteString)")
                    handleIncomingURL(url)
                }
            }
            // 3️⃣ As a fallback, when the scene becomes active, pick up the XCAppClipURL env var
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active, launchURL == nil,
                   let env = ProcessInfo.processInfo.environment["_XCAppClipURL"],
                   let url = URL(string: env) {
                    print("[App] Found environment URL: \(env)")
                    handleIncomingURL(url)
                } else if newPhase == .active, launchURL == nil, !showNoInternet, !showQRScanner {
                    // If we have no URL and aren't showing any screens yet, check status
                    checkStatus()
                }
            }
        }
    }
    
    private func setupNetworkMonitoring() {
        // Enable logging
        ARLog.isEnabled = true
        
        // Store a reference to self in a local variable
        NetworkMonitor.shared.onStatusChange = { isConnected in
            // Use a separate method that will be called with self as the receiver
            if isConnected {
                // Network just came back online
                if let url = pendingURL, url.extractFolderID() != nil {
                    // We have a valid pending URL, show AR
                    launchURL = url
                    showNoInternet = false
                    showQRScanner = false
                } else if showNoInternet {
                    // We were showing no internet screen with invalid/no URL
                    showQRScanner = true
                    showNoInternet = false
                }
            } else {
                // Network just went offline
                if launchURL != nil {
                    // We were showing AR, save URL and show no internet
                    pendingURL = launchURL
                    launchURL = nil
                    showNoInternet = true
                } else if showQRScanner {
                    // We were showing QR scanner, show no internet
                    showQRScanner = false
                    showNoInternet = true
                }
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if url.extractFolderID() != nil {
            // Valid URL with folderID
            if NetworkMonitor.shared.isConnected {
                // Network up + valid link -> AR
                launchURL = url
                showQRScanner = false
                showNoInternet = false
            } else {
                // Network down + valid link -> Delay showing No Internet
                pendingURL = url
                showQRScanner = false
                launchURL = nil
                
                // Delay 200ms before showing No-Internet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        showNoInternet = true
                    } else {
                        // Network came back online during delay
                        launchURL = url
                    }
                }
            }
        } else {
            // Invalid URL without folderID
            if NetworkMonitor.shared.isConnected {
                // Network up + invalid link -> QR scanner
                showQRScanner = true
                showNoInternet = false
                launchURL = nil
            } else {
                // Network down + invalid link -> Delay showing No Internet
                showQRScanner = false
                launchURL = nil
                pendingURL = nil
                
                // Delay 200ms before showing No-Internet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        showNoInternet = true
                    } else {
                        // Network came back online during delay
                        showQRScanner = true
                }
        }
    }
        }
    }
    
    private func checkStatus() {
        // Called during onAppear to make sure we're showing the right view
        if let url = pendingURL, let _ = url.extractFolderID() {
            // We have a valid pending URL
            if NetworkMonitor.shared.isConnected {
                // Network is up, show AR
                launchURL = url
                showNoInternet = false
                showQRScanner = false
            } else {
                // Network is down, delay showing No Internet
                showQRScanner = false
                
                // Delay 200ms before showing No-Internet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        showNoInternet = true
                    }
                }
            }
        } else {
            // No valid URL
            if NetworkMonitor.shared.isConnected {
                // Network is up, show QR scanner
                showQRScanner = true
                showNoInternet = false
            } else {
                // Network is down, delay showing No Internet
                showQRScanner = false
                
                // Delay 200ms before showing No-Internet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // If network still offline after delay
                    if !NetworkMonitor.shared.isConnected {
                        showNoInternet = true
                    }
                }
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable Wrappers

// Wrapper for NoInternetViewController
struct NoInternetViewControllerWrapper: UIViewControllerRepresentable {
    let initialLink: URL?
    
    func makeUIViewController(context: Context) -> NoInternetViewController {
        return NoInternetViewController(initialLink: initialLink)
    }
    
    func updateUIViewController(_ uiViewController: NoInternetViewController, context: Context) {
        // No updates needed
    }
}

// Wrapper for QRViewController
struct QRViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> QRViewController {
        return QRViewController()
    }
    
    func updateUIViewController(_ uiViewController: QRViewController, context: Context) {
        // No updates needed
    }
}
