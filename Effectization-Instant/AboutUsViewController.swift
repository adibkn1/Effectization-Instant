import UIKit
import WebKit

class AboutUsViewController: UIViewController, WKUIDelegate {
    
    @IBOutlet weak var aboutUsWebView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the "About Us" page
        if let url = URL(string: "https://forms.fillout.com/t/svJujGT7CEus") {
            let request = URLRequest(url: url)
            aboutUsWebView.load(request)
        }
    }
}
