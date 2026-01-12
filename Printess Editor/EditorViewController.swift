//
//  ViewController.swift
//  Printess Editor
//
//  Created by Bastian Kröger on 30.04.21.
//  Copyright © 2021 Bastian Kröger. All rights reserved.
//

import UIKit
import WebKit

class EditorViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler {
    var templateName: String = ""
    var templateToken: String?
    var bearerToken: String = ""

    var exitCallback: ((_ token: String) -> ())?
    var addToBasketCallback: ((_ token: String, _ thumbnail: String) -> ())?

    @IBOutlet
    var webView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let webView = webView else { return }

        let productionUrlString = "https://resource.printess.com/customers/panel-ui-ios.html"

        if let url = URL(string: productionUrlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        // Set up message handlers for Swift callbacks (JavaScript -> Swift communication)
        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "backButtonCallback")
        contentController.add(self, name: "addToBasketCallback")
        contentController.add(self, name: "printessReady") // NEW: Listen for JS ready signal

        // Set delegates
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    // Handles alerts triggered by JavaScript (e.g., alert("message"))
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> ())
    {
        let alertController = UIAlertController(title: message, message: nil,
                                                preferredStyle: UIAlertController.Style.alert)

        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel) {
            _ in completionHandler()
        }
        )
        alertController.addAction(UIAlertAction(title: "Back to list", style: UIAlertAction.Style.default) {
            _ in completionHandler()
            self.dismiss(animated: true, completion: nil)
        }
        )

        present(alertController, animated: true, completion: {})
    }

    // Receives messages posted from JavaScript via window.webkit.messageHandlers
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "printessReady" {
            // JavaScript module has loaded, now safe to call startPrintessPanel
            startPrintess()
        } else if message.name == "backButtonCallback" {
            guard let saveToken = message.body as? String else { return }
            if let callback = exitCallback {
                callback(saveToken)
            }
        } else if message.name == "addToBasketCallback" {
            guard let dict = message.body as? [String: String] else { return }
            guard let saveToken = dict["token"] else { return }
            guard let imageUrl = dict["imageUrl"] else { return }
            if let callback = addToBasketCallback {
                callback(saveToken, imageUrl)
            }
        }
    }

    //  Extracted method to start Printess - called when JS signals it's ready
    private func startPrintess() {
        guard let webView = webView else { return }

        var usedTemplateName = templateName.replacingOccurrences(of: "'", with: "\\'")
        if let token = templateToken {
            usedTemplateName = token
        }

        // TODO: basket id does it need to be set?
        let js = """
        startPrintessPanel({
          token: "\(bearerToken)",
          templateName: "\(usedTemplateName)",
          basketId: "someBasketId"
        });
        """

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("Error evaluating JavaScript to start Printess: \(error)")
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension EditorViewController: WKNavigationDelegate {
    // This removes the security bypass necessary for self-signed localhost certificates.
    // This only for local testing

//    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
//        // 1. Check if the challenge is for SSL/TLS server trust
//        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
//            // 2. OPTIONAL: Restrict this trust bypass only to your localhost
//            if challenge.protectionSpace.host == "localhost" {
//                // CRITICAL BYPASS: Tell the OS to trust the self-signed certificate.
//                // NOTE: ONLY use this for development on known hosts like 'localhost'.
//                if let serverTrust = challenge.protectionSpace.serverTrust {
//                    completionHandler(.useCredential, URLCredential(trust: serverTrust))
//                    return
//                }
//            }
//        }
//
//        // For all other challenges or if the check fails, use the default handling
//        completionHandler(.performDefaultHandling, nil)
//    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Page has loaded, but we wait for the "printessReady" message
        // before calling startPrintessPanel to avoid race condition
    }
}
