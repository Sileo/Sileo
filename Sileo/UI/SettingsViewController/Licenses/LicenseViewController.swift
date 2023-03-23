//
//  LicenseViewController.swift
//  Sileo
//
//  Created by Jamie Bishop on 30/07/2019.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import UIKit

class LicenseViewController: UIViewController {
    let licenseText: String
    var textView: UITextView?
    
    init(with license: SourceLicense) {
        licenseText = license.licenseText
        super.init(nibName: nil, bundle: nil)
        
        navigationItem.title = license.name
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.alwaysBounceVertical = true
        textView.isEditable = false
        textView.dataDetectorTypes = .link
        
        // WTF, UITextView
        textView.isScrollEnabled = false
        textView.text = licenseText
        textView.isScrollEnabled = true
        textView.textColor = .sileoLabel
        textView.backgroundColor = .clear
        
        view.addSubview(textView)
        
        view.backgroundColor = .sileoContentBackgroundColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        // Constraints
        textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        self.textView = textView
    }
    
    @objc func updateSileoColors() {
        view.backgroundColor = .sileoContentBackgroundColor
        textView?.textColor = .sileoLabel
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            view.backgroundColor = .sileoContentBackgroundColor
        }
    }
}
