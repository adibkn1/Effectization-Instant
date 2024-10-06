import Foundation
import WebKit

class CustomURLSchemeHandler: NSObject, WKURLSchemeHandler {

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url {
            // Block any media-related URLs (like .mp4, .mov, etc.)
            if url.absoluteString.contains(".mp4") || url.absoluteString.contains(".mov") || url.absoluteString.contains(".webm") {
                print("Blocking media content: \(url.absoluteString)")
                urlSchemeTask.didFailWithError(NSError(domain: "MediaBlocked", code: 999, userInfo: nil))
            } else {
                // Allow other requests to proceed as normal
                let session = URLSession(configuration: .default)
                let task = session.dataTask(with: urlSchemeTask.request) { data, response, error in
                    if let data = data, let response = response {
                        urlSchemeTask.didReceive(response)
                        urlSchemeTask.didReceive(data)
                        urlSchemeTask.didFinish()
                    } else if let error = error {
                        urlSchemeTask.didFailWithError(error)
                    }
                }
                task.resume()
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Implement this to handle stopping of the URL scheme task if needed
    }
}
