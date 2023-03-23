//
//  SourceErrorsViewController.swift
//  Sileo
//
//  Created by CoolStar on 7/9/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit

class SourcesErrorsViewController: SileoViewController {
    public var attributedString: NSAttributedString?
    @IBOutlet weak var errorOutputText: UITextView?
    @IBOutlet weak private var dismissButton: UIButton?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLoad() {
        if self.title == nil {
            self.title = String(localizationKey: "Refreshing_Sources_Page")
        }
        super.viewDidLoad()
        
        if let attributedString = attributedString {
            errorOutputText?.attributedText = transform(attributedString: attributedString)
        }
        dismissButton?.layer.cornerRadius = 10
        dismissButton?.setTitle(String(localizationKey: "Done"), for: .normal)
        
        self.statusBarStyle = .lightContent
    }
    
    @IBAction func dismiss(_ sender: Any?) {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let dismissButton = dismissButton {
            dismissButton.tintColor = UINavigationBar.appearance().tintColor
            dismissButton.isHighlighted = dismissButton.isHighlighted
        }
    }
    
    func transform(attributedString: NSAttributedString) -> NSAttributedString {
        guard let str = attributedString.mutableCopy() as? NSMutableAttributedString else {
            return attributedString
        }
        guard let font = UIFont(name: "Menlo-Regular", size: 12) else {
            return attributedString
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 4
        
        str.addAttributes([
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: str.length))
        return str
    }
}
