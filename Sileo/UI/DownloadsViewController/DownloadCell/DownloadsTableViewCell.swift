//
//  DownloadsTableViewCell.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class DownloadsTableViewCell: BaseSubtitleTableViewCell {
    public var package: DownloadPackage? = nil {
        didSet {
            self.title = package?.package.name
            self.loadIcon(url: URL(string: package?.package.icon ?? ""), placeholderIcon: UIImage(named: "Tweak Icon"))
        }
    }
    
    public var download: Download? = nil {
        didSet {
            self.updateDownload()
        }
    }
    
    public func updateDownload() {
        retryButton.isHidden = true
        if let download = download {
            self.progress = download.progress
            if download.success {
                self.subtitle = String(localizationKey: "Ready_Status")
            } else if let message = download.message {
                self.subtitle = message
            } else if let failureReason = download.failureReason,
                !failureReason.isEmpty {
                retryButton.isHidden = false
                self.subtitle = String(format: String(localizationKey: "Error_Indicator", type: .error), failureReason)
            } else if download.queued {
                self.subtitle = String(localizationKey: "Queued_Package_Status")
            } else {
                self.subtitle = String(format: String(localizationKey: "Download_Progress"),
                                       ByteCountFormatter.string(fromByteCount: Int64(download.totalBytesWritten), countStyle: .file),
                                       ByteCountFormatter.string(fromByteCount: Int64(download.totalBytesExpectedToWrite), countStyle: .file))
            }
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
        let downloadMan = DownloadManager.shared
        guard let package = package,
              let download = downloadMan.downloads[package.package.package],
              !download.success,
              download.completed,
              !download.queued,
              let task = download.task else { return }
        download.completed = false
        download.queued = true
        if task.shouldResume && task.resumeData != nil {
            if !task.retry() {
                task.make()
            }
        } else {
            task.make()
        }
        download.task = task
        downloadMan.downloads[package.package.package] = download
        downloadMan.startMoreDownloads()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.contentView.addSubview(retryButton)
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
