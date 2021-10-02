//
//  DownloadsTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class DownloadsTableViewCell: BaseSubtitleTableViewCell {
    public var package: DownloadPackage? = nil {
        didSet {
            internalPackage = package?.package
        }
    }
    
    public var internalPackage: Package? {
        didSet {
            self.title = internalPackage?.name
            if let url = internalPackage?.icon {
                self.icon = EvanderNetworking.shared.image(url, size: iconView.frame.size) { [weak self] refresh, image in
                    if refresh,
                       let strong = self,
                       let image = image,
                       url == strong.internalPackage?.icon {
                        DispatchQueue.main.async {
                            strong.icon = image
                        }
                    }
                } ?? UIImage(named: "Tweak Icon")
            } else {
                self.icon = UIImage(named: "Tweak Icon")
            }
        }
    }
    
    public var operation: DownloadsTableViewController.InstallOperation? {
        didSet {
            internalPackage = operation?.package
            var progress = operation?.progress ?? 0.0
            progress = (progress / 1.0) * 0.3
            self.progress = progress + 0.7
            if let status = operation?.status {
                subtitle = status
            }
            operation?.cell = self
        }
    }
    
    public var download: Download? = nil {
        didSet {
            self.updateDownload()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        operation?.cell = nil
    }
    
    public func updateDownload() {
        retryButton.isHidden = true
        if let download = download {
            self.progress = (download.progress / 1.0) * 0.7
            if download.progress == 1.0 && download.failureReason == nil {
                self.subtitle = String(localizationKey: "Ready_Status")
            } else if let message = download.message {
                self.subtitle = message
            } else if let failureReason = download.failureReason,
                !failureReason.isEmpty {
                retryButton.isHidden = false
                self.subtitle = String(format: String(localizationKey: "Error_Indicator", type: .error), failureReason)
            } else if download.started {
                self.subtitle = String(format: String(localizationKey: "Download_Progress"),
                                       ByteCountFormatter.string(fromByteCount: Int64(download.totalBytesWritten), countStyle: .file),
                                       ByteCountFormatter.string(fromByteCount: Int64(download.totalBytesExpectedToWrite), countStyle: .file))
            } else {
                self.subtitle = String(localizationKey: "Queued_Package_Status")
            }
        } else if shouldHaveDownload {
            self.subtitle = String(localizationKey: "Queued_Package_Status")
            self.progress = 0
        } else {
            self.progress = 0
            self.subtitle = String(localizationKey: errorDescription ?? (shouldHaveDownload ? "Download_Starting" : "Ready_Status"))
        }
    }
    
    public var errorDescription: String? = nil {
        didSet {
            let errored = errorDescription != nil
            if errored {
                download = nil
            }
            self.textLabel?.textColor = errored ? .red : .sileoLabel
            self.detailTextLabel?.textColor = errored ? .red : UIColor(red: 172.0/255.0, green: 184.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
    }
    
    public var shouldHaveDownload: Bool = false {
        didSet {
            if !shouldHaveDownload {
                download = nil
            }
        }
    }
    
    public let retryButton = UIButton()
    
    @objc public func retryDownload() {
        retryButton.isHidden = true
        let downloadMan = DownloadManager.shared
        guard let package = package,
              let download = downloadMan.downloads[package.package.packageID],
              !download.success else { return }
        download.completed = false
        download.task = nil
        download.queued = false
        downloadMan.startMoreDownloads()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.contentView.addSubview(retryButton)
        self.detailTextLabel?.adjustsFontSizeToFitWidth = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.heightAnchor.constraint(equalToConstant: 17.5).isActive = true
        retryButton.widthAnchor.constraint(equalToConstant: 17.5).isActive = true
        retryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: retryButton.trailingAnchor, constant: 15).isActive = true
        
        retryButton.setImage(UIImage(named: "Refresh")?.withRenderingMode(.alwaysTemplate), for: .normal)
        retryButton.tintColor = .tintColor
        retryButton.addTarget(self, action: #selector(retryDownload), for: .touchUpInside)
        retryButton.isHidden = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
