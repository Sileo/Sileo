//
//  DepictionSubpageViewController.swift
//  Sileo
//
//  Created by CoolStar on 7/31/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class DepictionSubpageViewController: UIViewController {
    @IBOutlet var scrollView: UIScrollView?
    var depictionView: DepictionBaseView?
    var loadingView: UIActivityIndicatorView?

    public var depictionURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        let loadingView = UIActivityIndicatorView(style: .gray)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(loadingView)

        loadingView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        loadingView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        loadingView.hidesWhenStopped = true

        self.reloadData()
    }

    func reloadData() {
        guard let depictionURL = self.depictionURL else {
            return
        }

        if self.depictionView == nil {
            loadingView?.startAnimating()
        }

        URLSession.shared.dataTask(with: depictionURL) { data, _, error in
            guard error == nil,
                let data = data else {
                    return
            }
            guard let rawDepiction = try? JSONSerialization.jsonObject(with: data, options: []) else {
                return
            }
            guard let depiction = rawDepiction as? [String: Any],
                (depiction["class"] as? String) != nil else {
                    return
            }

            DispatchQueue.main.sync {
                if let title = depiction["title"] as? String {
                    self.title = title
                }

                if let minVersion = depiction["minVersion"] as? String {
                    if minVersion.compare(StoreVersion) == .orderedDescending {
                        self.versionTooLow()
                    }
                }

                guard let depictView = DepictionBaseView.view(dictionary: depiction, viewController: self, tintColor: nil, isActionable: false) else {
                    return
                }

                self.depictionView?.removeFromSuperview()
                self.depictionView = depictView

                self.navigationController?.navigationBar.tintColor = depictView.tintColor

                self.scrollView?.addSubview(depictView)
                self.loadingView?.stopAnimating()
                self.viewDidLayoutSubviews()
            }
        }.resume()
    }

    func versionTooLow() {
        let alertController = UIAlertController(title: String(localizationKey: "Sileo_Update_Required.Title", type: .error),
                                                message: String(localizationKey: "Depiction_Requires_Sileo_Update", type: .error),
                                                preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    func subviewHeightChanged() {
        self.viewDidLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let depictionView = depictionView,
        let scrollView = scrollView else {
            return
        }

        let depictionHeight = depictionView.depictionHeight(width: scrollView.bounds.width)
        depictionView.frame = CGRect(origin: .zero, size: CGSize(width: scrollView.bounds.width, height: depictionHeight))

        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: depictionHeight)
    }
}
