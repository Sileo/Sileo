//
//  FlaggedSourceWarningViewController.swift
//  Sileo
//
//  Created by Jamie Bishop on 30/07/2019.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import UIKit

class FlaggedSourceWarningViewController: SileoViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var safetyButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var scrollHairlineView: UIView!
    @IBOutlet weak var scrollHairlineConstraint: NSLayoutConstraint!
    
    var shouldAddAnywayCallback: (() -> Void)?
    
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusBarStyle = .lightContent
        
        safetyButton.layer.cornerRadius = 8
        
        titleLabel.text = String(localizationKey: "Dangerous_Repo.Title")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.15
        paragraphStyle.alignment = .center
        bodyLabel.attributedText = NSAttributedString(string: String(localizationKey: "Dangerous_Repo.Body"),
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
    
    func presentLastChanceAlert() {
        let urlString = url?.absoluteString ?? "this repo"
        let lastChanceAlert = UIAlertController(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Title"),
                                                message: String(format: String(localizationKey: "Dangerous_Repo.Last_Chance.Body"), urlString),
                                                preferredStyle: .alert)
        
        lastChanceAlert.addAction(.init(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Cancel"),
                                        style: .cancel, handler: { [unowned self] _ in
                                            self.dismiss(animated: true)
                                        }))
        
        lastChanceAlert.addAction(.init(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Continue"),
                                        style: .destructive, handler: { [unowned self] _ in
                                            self.addAnyway()
                                        }))
        
        present(lastChanceAlert, animated: true)
    }
    
    func addAnyway() {
        shouldAddAnywayCallback?()
        dismiss(animated: true)
    }
    
    @IBAction func safetyButtonTapped(sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func addAnywayButtonTapped(sender: Any) {
       presentLastChanceAlert()
    }
    
    func determineScrollHairlineAnimated(animated: Bool) {
        UIView.animate(withDuration: animated ? 0.2 : 0, delay: 0, options: .beginFromCurrentState,
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
