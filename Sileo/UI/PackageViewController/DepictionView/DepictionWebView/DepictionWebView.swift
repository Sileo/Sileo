//
//  DepictionWebView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import SafariServices
import WebKit
import Evander

class DepictionWebView: DepictionBaseView {
    let alignment: Int

    let webView: WKWebView?

    let width: CGFloat
    let height: CGFloat

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let urlStr = dictionary["URL"] as? String else {
            return nil
        }
        guard let width = dictionary["width"] as? CGFloat else {
            return nil
        }
        guard let height = dictionary["height"] as? CGFloat else {
            return nil
        }
        self.width = width
        self.height = height
        alignment = (dictionary["alignment"] as? Int) ?? 0

        guard viewController is PackageViewController else {
            return nil
        }

        guard let url = URL(string: urlStr) else {
            return nil
        }

        var urlAllowed = false
        let host = url.host ?? ""

        if host.hasSuffix("youtube.com") {
            urlAllowed = true
        }
        if host.hasSuffix("vimeo.com") {
            urlAllowed = true
        }
        guard urlAllowed else {
            return nil
        }

        webView = WKWebView(frame: .zero)

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        webView?.load(URLRequest(url: url))
        webView?.scrollView.isScrollEnabled = false
        webView?.navigationDelegate = self
        webView?.uiDelegate = self
        self.addSubview(webView!)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        height
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var width = self.width
        if width > self.bounds.width {
            width = self.bounds.width
        }

        var x = CGFloat(0)
        switch alignment {
        case 2: do {
            x = self.bounds.width - width
            break
            }
        case 1: do {
            x = (self.bounds.width - width)/2.0
            break
            }
        default: do {
            x = 0
            break
            }
        }
        webView?.frame = CGRect(x: x, y: 0, width: width, height: height)
    }
}

extension DepictionWebView: WKUIDelegate {
    func webView(_ webView: WKWebView, previewingViewControllerForElement elementInfo: WKPreviewElementInfo, defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        guard let url = elementInfo.linkURL,
            let scheme = url.scheme else {
            return nil
        }
        if scheme == "http" || scheme == "https" {
            let viewController = SFSafariViewController(url: url)
            viewController.preferredControlTintColor = UINavigationBar.appearance().tintColor
            return viewController
        }
        return nil
    }

    func webView(_ webView: WKWebView, commitPreviewingViewController previewingViewController: UIViewController) {
        if previewingViewController.isKind(of: SFSafariViewController.self) {
            parentViewController?.present(previewingViewController, animated: true, completion: nil)
        } else {
            parentViewController?.navigationController?.pushViewController(previewingViewController, animated: true)
        }
    }
}

extension DepictionWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated || navigationAction.navigationType == .formSubmitted {
            var presentModally = false
            guard let newViewController = URLManager.viewController(url: navigationAction.request.url,
                                                                    isExternalOpen: false,
                                                                    presentModally: &presentModally) else {
                decisionHandler(.cancel)
                return
            }
            if presentModally {
                parentViewController?.present(newViewController, animated: true, completion: nil)
            } else {
                parentViewController?.navigationController?.pushViewController(newViewController, animated: true)
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
