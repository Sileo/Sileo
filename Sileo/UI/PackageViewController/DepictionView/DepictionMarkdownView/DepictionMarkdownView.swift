//
//  DepictionMarkdownView.swift
//  Sileo
//
//  Created by CoolStar on 7/6/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Down
import WebKit
import SafariServices

class DepictionMarkdownView: DepictionBaseView {

    private static let webViewConfiguration: WKWebViewConfiguration = {
        // Configures the web view to restrict all but the primary purpose of this feature.
        // - No network requests are allowed. Resources can only be loaded from data: URLs, or
        //   inline CSS.
        // - Caching and data storage is in-memory only, in a unique data store per web view.
        // - Navigation within the web view is not allowed.
        // - JavaScript can only be executed by code injected by Sileo.
        // Note: The CSP has "allow-scripts", which might seem contradictory, but this is only to
        // allow our own injected JavaScript to execute. The webpage still can’t run its own JS.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.ignoresViewportScaleLimits = false
        configuration.dataDetectorTypes = []
        configuration._overrideContentSecurityPolicy = "default-src data:; style-src data: 'unsafe-inline'; script-src 'none'; child-src 'none'; sandbox allow-scripts"
        if #available(iOS 14, *) {
            configuration._loadsSubresources = false
            configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        }
        if #available(iOS 15, *) {
            configuration._allowedNetworkHosts = Set()
        } else if #available(iOS 14, *) {
            configuration._loadsFromNetwork = false
        }
        return configuration
    }()

    private var htmlString: String = ""

    private let useSpacing: Bool
    private let useMargins: Bool

    private let webView: WKWebView
    private var contentSizeObserver: NSKeyValueObservation!

    required init?(dictionary: [String: Any], viewController: UIViewController, tintColor: UIColor, isActionable: Bool) {
        guard let markdown = dictionary["markdown"] as? String else {
            return nil
        }
        
        useSpacing = (dictionary["useSpacing"] as? Bool) ?? true
        useMargins = (dictionary["useMargins"] as? Bool) ?? true
        let useRawFormat = (dictionary["useRawFormat"] as? Bool) ?? false

        webView = WKWebView(frame: .zero, configuration: Self.webViewConfiguration)

        super.init(dictionary: dictionary, viewController: viewController, tintColor: tintColor, isActionable: isActionable)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        addSubview(webView)

        contentSizeObserver = webView.scrollView.observe(\.contentSize) { _, _ in
            self.subviewHeightChanged()
        }

        if useRawFormat {
            htmlString = markdown
        } else {
            let down = Down(markdownString: markdown)
            if let html = try? down.toHTML(.default) {
                htmlString = html
            }
        }

        reloadMarkdown()

        NSLayoutConstraint.activate([
            webView.leftAnchor.constraint(equalTo: self.leftAnchor),
            webView.rightAnchor.constraint(equalTo: self.rightAnchor),
            webView.topAnchor.constraint(equalTo: self.topAnchor),
            webView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(themeDidChange),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.themeDidChange()
    }
    
    @objc func reloadMarkdown() {
        let htmlString = """
        <!DOCTYPE html>
        <html theme="\(UIColor.isDarkModeEnabled ? "dark" : "light")" style="\(cssVariables)">
        <base target="_blank">
        <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        body {
            margin: \(useSpacing ? "13px" : "0") \(useMargins ? "16px" : "0");
            background: transparent;
            font: -apple-system-body;
            color: var(--label-color);
            -webkit-text-size-adjust: none;
        }
        pre, xmp, plaintext, listing, tt, code, kbd, samp {
            font-family: ui-monospace, Menlo;
        }
        a {
            text-decoration: none;
            color: var(--tint-color);
        }
        p, h1, h2, h3, h4, h5, h6, ul, ol {
            margin: 0 0 16px 0;
        }
        body > *:last-child {
            margin-bottom: 0;
        }
        </style>
        <body>\(self.htmlString)</body>
        </html>
        """

        webView.loadHTMLString(htmlString, baseURL: nil)
        self.setNeedsLayout()
    }

    private var cssVariables: String {
        """
        --tint-color: \(tintColor.cssString);
        --background-color: \(UIColor.sileoBackgroundColor.cssString);
        --content-background-color: \(UIColor.sileoContentBackgroundColor.cssString);
        --highlight-color: \(UIColor.sileoHighlightColor.cssString);
        --separator-color: \(UIColor.sileoSeparatorColor.cssString);
        --label-color: \(UIColor.sileoLabel.cssString);
        """.replacingOccurrences(of: "\n", with: " ")
    }

    @objc private func themeDidChange() {
        if #available(iOS 14, *) {
            let injectJS = """
            document.documentElement.setAttribute("style", value);
            """
            webView.callAsyncJavaScript(injectJS, arguments: [ "value": cssVariables ], in: nil, in: .defaultClient, completionHandler: nil)
        } else {
            let injectJS = """
            document.documentElement.setAttribute("style", "\(cssVariables)");
            """
            webView.evaluateJavaScript(injectJS, completionHandler: nil)
        }
    }

    override func depictionHeight(width: CGFloat) -> CGFloat {
        return webView.scrollView.contentSize.height
    }
}

extension DepictionMarkdownView: WKUIDelegate {
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

    @available(iOS 13, *)
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        let url = elementInfo.linkURL
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: {
            if let url = url,
               url.scheme == "http" || url.scheme == "https" {
                let viewController = SFSafariViewController(url: url)
                viewController.preferredControlTintColor = UINavigationBar.appearance().tintColor
                return viewController
            }
            return nil
        }, actionProvider: { children in
            UIMenu(children: children)
        })
        completionHandler(configuration)
    }

    @available(iOS 13, *)
    func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo, willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
        guard let url = elementInfo.linkURL else {
            return
        }
        animator.addAnimations {
            if let viewController = animator.previewViewController as? SFSafariViewController {
                self.parentViewController?.present(viewController, animated: true, completion: nil)
            } else {
                _ = DepictionButton.processAction(url.absoluteString, parentViewController: self.parentViewController, openExternal: false)
            }
        }
    }
}

extension DepictionMarkdownView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        switch navigationAction.navigationType {
        case .linkActivated, .formSubmitted:
            // User tapped a link inside the web view.
            _ = DepictionButton.processAction(url.absoluteString, parentViewController: self.parentViewController, openExternal: false)

        case .other:
            // The navigation type will be .other and URL will be about:blank when loading an
            // HTML string.
            if url.absoluteString == "about:blank" {
                decisionHandler(.allow)
                return
            }

        default: break
        }
        decisionHandler(.cancel)
    }
}
