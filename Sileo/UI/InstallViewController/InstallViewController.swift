//
//  InstallViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/24/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class InstallViewController: SileoViewController {
    public var progress: Float {
        get {
            progressView?.progress ?? 0
        }
        set {
            progressView?.progress = newValue
            DownloadManager.shared.totalProgress = CGFloat(newValue)
            DownloadManager.shared.reloadData(recheckPackages: false)
        }
    }
    
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView?
    @IBOutlet var progressView: UIProgressView?
    @IBOutlet var teleprompterView: UIView?
    
    var teleprompterLabels: [SileoLabelView] = []
    
    @IBOutlet var completeButton: DownloadConfirmButton?
    @IBOutlet var showDetailsButton: UIButton?
    @IBOutlet var hideDetailsButton: DownloadConfirmButton?
    
    @IBOutlet var detailsView: UIView?
    @IBOutlet var detailsTextView: UITextView?
    
    var detailsAttributedString: NSMutableAttributedString?
    
    var returnButtonAction: APTWrapper.FINISH = .back
    var refreshSileo = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.statusBarStyle = UIDevice.current.userInterfaceIdiom == .pad ? .default : .lightContent
        
        activityIndicatorView?.startAnimating()
        completeButton?.layer.cornerRadius = 10
        hideDetailsButton?.layer.cornerRadius = 10
        
        detailsAttributedString = NSMutableAttributedString(string: "")
        
        completeButton?.setTitle(String(localizationKey: "Done"), for: .normal)
        showDetailsButton?.setTitle(String(localizationKey: "Show_Install_Details"), for: .normal)
        hideDetailsButton?.setTitle(String(localizationKey: "Hide_Install_Details"), for: .normal)
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        // swiftlint:disable:next line_length
        let testAPTStatus = "pmstatus:dpkg-exec:0.0000:Running dpkg\npmstatus:bash:0.0000:Installing bash (iphoneos-arm)\npmstatus:bash:9.0909:Preparing bash (iphoneos-arm)\npmstatus:bash:18.1818:Unpacking bash (iphoneos-arm)\npmstatus:bash:27.2727:Preparing to configure bash (iphoneos-arm)\npmstatus:dpkg-exec:27.2727:Running dpkg\npmstatus:bash:27.2727:Configuring bash (iphoneos-arm)\npmstatus:bash:36.3636:Configuring bash (iphoneos-arm)\npmstatus:bash:45.4545:Installed bash (iphoneos-arm)\npmstatus:dpkg-exec:45.4545:Running dpkg\npmstatus:mobilesubstrate:45.4545:Installing mobilesubstrate (iphoneos-arm)\npmstatus:mobilesubstrate:54.5455:Preparing mobilesubstrate (iphoneos-arm)\npmstatus:mobilesubstrate:63.6364:Unpacking mobilesubstrate (iphoneos-arm)\npmstatus:mobilesubstrate:72.7273:Preparing to configure mobilesubstrate (iphoneos-arm)\npmstatus:dpkg-exec:72.7273:Running dpkg\npmstatus:mobilesubstrate:72.7273:Configuring mobilesubstrate (iphoneos-arm)\npmstatus:mobilesubstrate:81.8182:Configuring mobilesubstrate (iphoneos-arm)\npmstatus:mobilesubstrate:90.9091:Installed mobilesubstrate (iphoneos-arm)"
        DispatchQueue.global(qos: .default).async {
            let aptStatuses = testAPTStatus.components(separatedBy: "\n")
            for status in aptStatuses {
                let (statusValid, statusProgress, readableStatus) = APTWrapper.installProgress(aptStatus: status)
                if statusValid {
                    DispatchQueue.main.async {
                        self.push(text: readableStatus)
                        self.setProgress(Float(statusProgress)/100.0, animated: true)
                    }
                }
                usleep(useconds_t(50 * USEC_PER_SEC/1000))
            }
            DispatchQueue.main.async {
                self.setProgress(1, animated: true)
                self.activityIndicatorView?.stopAnimating()
                self.progressView?.alpha = 0
                self.completeButton?.alpha = 1
            }
        }
        #else
        let downloadManager = DownloadManager.shared
        
        let installs = downloadManager.installations + downloadManager.upgrades
        let removals = downloadManager.uninstallations
        
        if let detailsAttributedString = self.detailsAttributedString {
            detailsTextView?.attributedText = self.transform(attributedString: detailsAttributedString)
        }
        
        APTWrapper.performOperations(installs: installs, removals: removals, progressCallback: { installProgress, statusValid, statusReadable in
            if statusValid {
                DispatchQueue.main.async {
                    self.push(text: statusReadable)
                    self.setProgress(Float(installProgress)/100, animated: true)
                }
            }
        }, outputCallback: { output, pipe in
            var textColor = Dusk.foregroundColor
            if pipe == STDERR_FILENO {
                textColor = Dusk.errorColor
            }
            if pipe == APTWrapper.debugFD {
                textColor = Dusk.debugColor
            }
            
            let substring = NSMutableAttributedString(string: output, attributes: [NSAttributedString.Key.foregroundColor: textColor])
            DispatchQueue.main.async {
                self.detailsAttributedString?.append(substring)
                
                guard let detailsAttributedString = self.detailsAttributedString else {
                    return
                }
                
                self.detailsTextView?.attributedText = self.transform(attributedString: detailsAttributedString)
                
                self.detailsTextView?.scrollRangeToVisible(NSRange(location: detailsAttributedString.string.count - 1, length: 1))
            }
        }, completionCallback: { _, finish, refresh in
            DispatchQueue.main.async {
                self.returnButtonAction = finish
                self.refreshSileo = refresh
                self.setProgress(1, animated: true)
                self.activityIndicatorView?.stopAnimating()
                self.progressView?.alpha = 0
                self.updateCompleteButton()
                self.completeButton?.alpha = 1
            }
        })
        #endif
    }
    
    func transform(attributedString: NSMutableAttributedString) -> NSMutableAttributedString {
        let font = UIFont(name: "Menlo-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 4
        
        attributedString.addAttributes([
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: attributedString.length))
        return attributedString
    }
    
    func setProgress(_ progress: Float, animated: Bool) {
        progressView?.setProgress(progress, animated: animated)
        DownloadManager.shared.totalProgress = CGFloat(progress)
        DownloadManager.shared.reloadData(recheckPackages: false)
    }
    
    func push(text: String) {
        guard let activityIndicatorView = self.activityIndicatorView,
            let progressView = self.progressView else {
                return
        }
        
        let initialFrame = CGRect(x: activityIndicatorView.frame.minX + activityIndicatorView.frame.width + 16,
                                  y: activityIndicatorView.frame.minY + 32,
                                  width: progressView.frame.width,
                                  height: 20)
        
        let label = SileoLabelView(frame: initialFrame)
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.alpha = 0.5
        teleprompterView?.addSubview(label)
        teleprompterLabels.append(label)
        
        while teleprompterLabels.count > 6 {
            teleprompterLabels.removeFirst().removeFromSuperview()
        }
        
        teleprompterView?.bringSubviewToFront(activityIndicatorView)
        teleprompterView?.bringSubviewToFront(progressView)
        
        UIView.animate(withDuration: 0.25) {
            self.viewDidLayoutSubviews()
        }
    }
    
    func updateCompleteButton() {
        switch returnButtonAction {
        case .back:
            if refreshSileo { completeButton?.setTitle(String(localizationKey: "After_Install_Relaunch"), for: .normal); break }
            completeButton?.setTitle(String(localizationKey: "Done"), for: .normal)
        case .reopen:
            completeButton?.setTitle(String(localizationKey: "After_Install_Relaunch"), for: .normal)
        case .restart, .reload:
            completeButton?.setTitle(String(localizationKey: "After_Install_Respring"), for: .normal)
        case .reboot:
            completeButton?.setTitle(String(localizationKey: "After_Install_Reboot"), for: .normal)
        case .uicache:
            if refreshSileo { completeButton?.setTitle(String(localizationKey: "After_Install_Relaunch"), for: .normal); }
        }
    }
    
    @IBAction func completeButtonTapped(_ sender: Any?) {
        if self.returnButtonAction == .back || self.returnButtonAction == .uicache {
            if self.refreshSileo { spawn(command: "/usr/bin/uicache", args: ["uicache", "-p", Bundle.main.bundlePath]); return }
            self.navigationController?.popViewController(animated: true)
            DispatchQueue.global(qos: .default).async {
                PackageListManager.shared.purgeCache()
                PackageListManager.shared.waitForReady()
                DispatchQueue.main.async {
                    DownloadManager.shared.lockedForInstallation = false
                    DownloadManager.shared.removeAllItems()
                    
                    NotificationCenter.default.post(name: PackageListManager.reloadNotification, object: nil)
                    DownloadManager.shared.reloadData(recheckPackages: true)
                    TabBarController.singleton?.dismissPopupController()
                }
            }
        } else if self.returnButtonAction == .reopen {
            exit(0)
        } else if self.returnButtonAction == .restart || self.returnButtonAction == .reload {
            spawnAsRoot(command: "sbreload \(self.refreshSileo ? "&& uicache \(Bundle.main.bundlePath)" : "")")
        } else if self.returnButtonAction == .reboot {
            spawnAsRoot(command: "sync")
            spawnAsRoot(command: "ldrestart")
        }
    }
    
    @IBAction func showDetails(_ sender: Any?) {
        guard let detailsView = self.detailsView else {
            return
        }
        detailsView.alpha = 0
        detailsView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        detailsView.frame = self.view.bounds
        
        self.view.addSubview(detailsView)
        
        self.view.bringSubviewToFront(detailsView)
        UIView.animate(withDuration: 0.25) {
            self.detailsView?.alpha = 1
            
            self.statusBarStyle = .lightContent
        }
    }
    
    @IBAction func hideDetails(_ sender: Any?) {
        UIView.animate(withDuration: 0.25, animations: {
            self.detailsView?.alpha = 0
            
            self.statusBarStyle = UIDevice.current.userInterfaceIdiom == .pad ? .default : .lightContent
        }, completion: { _ in
            self.detailsView?.removeFromSuperview()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let activityIndicatorView = self.activityIndicatorView,
            let progressView = self.progressView else {
                return
        }
        
        progressView.tintColor = UINavigationBar.appearance().tintColor
        
        var frame = CGRect(x: activityIndicatorView.frame.minX + activityIndicatorView.frame.width + 16,
                           y: activityIndicatorView.frame.minY,
                           width: progressView.frame.width,
                           height: 20)
        var alpha: CGFloat = 1.0
        
        for label in teleprompterLabels.reversed() {
            label.frame = frame
            label.alpha = alpha
            frame.origin.y -= 24
            
            alpha -= 0.17
        }
        
        completeButton?.tintColor = UINavigationBar.appearance().tintColor
        completeButton?.isHighlighted = completeButton?.isHighlighted ?? false
        
        hideDetailsButton?.tintColor = UINavigationBar.appearance().tintColor
        hideDetailsButton?.isHighlighted = hideDetailsButton?.isHighlighted ?? false
    }
}
