//
//  FlaggedSourceWarningViewController.swift
//  Sileo
//
//  Created by Jamie Bishop on 30/07/2019.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit
import Evander

class FlaggedSourceWarningViewController: SileoViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var safetyButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var scrollHairlineView: UIView!
    @IBOutlet weak var scrollHairlineConstraint: NSLayoutConstraint!
    
    var shouldAddAnywayCallback: (() -> Void)?
    
    var urls: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusBarStyle = .lightContent
        
        safetyButton.layer.cornerRadius = 8
        
        titleLabel.text = String(localizationKey: "Dangerous_Repo.Title")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.15
        paragraphStyle.alignment = .center
        var bodyString = String(localizationKey: "Dangerous_Repo.Body")
        for (index, url) in urls.enumerated() {
            bodyString += "\(index == 0 ? "\n\n" : "\n")\(url.absoluteString)"
        }
        bodyLabel.attributedText = NSAttributedString(string: bodyString,
                                                      attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
        continueButton.setTitle(String(localizationKey: "Dangerous_Repo.Continue"), for: .normal)
        safetyButton.setTitle(String(localizationKey: "Dangerous_Repo.Cancel"), for: .normal)
        
        if UIScreen.main.bounds.width < 350 {
            bodyLabel.font = UIFont.systemFont(ofSize: 14)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollHairlineConstraint.constant = 1 / view.window!.screen.scale
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @IBAction func safetyButtonTapped(sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func addAnywayButtonTapped(sender: Any) {
        shouldAddAnywayCallback?()
        dismiss(animated: true)
    }
    
    func determineScrollHairlineAnimated(animated: Bool) {
        FRUIView.animate(withDuration: animated ? 0.2 : 0, delay: 0, options: .beginFromCurrentState,
                       animations: {
                        self.scrollHairlineView.alpha = self.scrollView.contentOffset.y >= self.scrollView.contentSize.height -
                            self.scrollView.bounds.size.height ? 0 : 1
        })
    }
    
    // MARK: - Scroll View Delegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        determineScrollHairlineAnimated(animated: true)
    }
}
