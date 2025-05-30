import UIKit

class NoInternetViewController: UIViewController {
    private let initialLink: URL?
    
    init(initialLink: URL?) {
        self.initialLink = initialLink
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let view = NoInternetView(frame: self.view.bounds)
        view.onRetry = { [weak self] in
            guard let self = self else { return }
            if let url = self.initialLink, let folderID = url.extractFolderID() {
                // Valid link: retry AR
                if NetworkMonitor.shared.isConnected {
                    let ar = ARViewController(folderID: folderID)
                    ar.launchURL = url
                    
                    // Replace current view controller
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController = ar
                        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                    } else {
                        self.present(ar, animated: true)
                    }
                }
            } else {
                // Invalid link: retry QR
                if NetworkMonitor.shared.isConnected {
                    QRScannerHelper.openQRScanner(from: self)
                }
            }
        }
        self.view = view
    }
} 