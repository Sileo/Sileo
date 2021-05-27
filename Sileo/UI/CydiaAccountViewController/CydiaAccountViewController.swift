//
//  CydiaAccountViewController.swift
//  Sileo
//
//  Created by CoolStar on 4/17/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

// This is the only section that gets to use deprecated APIs

#if !targetEnvironment(macCatalyst)
import Foundation

class CydiaAccountViewController: UIViewController, UIWebViewDelegate {
    @IBOutlet var webView: UIWebView?
    private var backButton: UIBarButtonItem?
    private var forwardButton: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let leftArrow = UIImage.kitImageNamed("UIButtonBarArrowLeft")
        let rightArrow = UIImage.kitImageNamed("UIButtonBarArrowRight")
        
        let backButton = UIBarButtonItem(image: leftArrow, style: .plain, target: self, action: #selector(CydiaAccountViewController.back(_:)))
        let forwardButton = UIBarButtonItem(image: rightArrow, style: .plain, target: self, action: #selector(CydiaAccountViewController.forward(_:)))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss(_:)))
        let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(CydiaAccountViewController.reload(_:)))
        
        self.backButton = backButton
        self.forwardButton = forwardButton
        self.navigationItem.leftBarButtonItems = [doneButton, backButton, forwardButton]
        self.navigationItem.rightBarButtonItem = refreshButton
        
        webView?.loadRequest(URLRequest(url: URL(string: "https://cydia.saurik.com/account/")!))
    }
    
    @objc func back(_: Any?) {
        webView?.goBack()
    }
    
    @objc func forward(_: Any?) {
        webView?.goForward()
    }
    
    @objc func reload(_: Any?) {
        webView?.reload()
    }
    
    @objc func stop(_: Any?) {
        webView?.stopLoading()
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
        let button = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(CydiaAccountViewController.stop(_:)))
        self.navigationItem.rightBarButtonItem = button
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
        let button = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(CydiaAccountViewController.reload(_:)))
        self.navigationItem.rightBarButtonItem = button
        
        if webView.request?.mainDocumentURL?.absoluteString.hasPrefix("https://cydia.saurik.com/account") ?? false {
            guard var uRLRequest = webView.request else {
                return
            }
            uRLRequest.url = URL(string: "https://cydia.saurik.com/account/purchases")
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let task = session.dataTask(with: uRLRequest) { data, response, _ in
                guard let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200,
                    let data = data else {
                    return
                }
                
                guard let html = String(data: data, encoding: .utf8) else {
                    return
                }
                
                let rawPurchased = CydiaScraper.parsePurchaseList(rawHTML: html)
                var existingPurchased: [String] = (UserDefaults.standard.array(forKey: "cydia-purchased") as? [String]) ?? [] 
                for packageID in rawPurchased {
                    if !existingPurchased.contains(packageID) {
                        existingPurchased.append(packageID)
                    }
                }
                
                UserDefaults.standard.set(existingPurchased, forKey: "cydia-purchased")
            }
            task.resume()
        }
    }
    
    @objc func dismiss(_: Any?) {
        self.dismiss(animated: true, completion: nil)
    }
}
#endif
