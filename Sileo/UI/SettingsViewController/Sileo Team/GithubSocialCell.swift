//
//  GithubSocialCell.swift
//  Aemulo
//
//  Created by Amy on 09/04/2021.
//
//  Copyright © 2021 Amy While. All rights reserved.

import UIKit
import Evander

class GithubSocialCell: UITableViewCell {
    
    private var author = UILabel()
    private var profilePicture = UIImageView()
    private var authorLink = UILabel()
    public var social: GithubSocial? {
        didSet {
            guard let social = social else { return }
            self.author.text = social.author
            self.authorLink.text = social.role
            self.pullImage()
        }
    }
    
    private func pullImage() {
        guard let url = social?.url else { return }
        self.profilePicture.image = EvanderNetworking.shared.image(url, size: profilePicture.frame.size) { [weak self] refresh, image in
            if refresh,
               let strong = self,
               let image = image,
               strong.social?.url == url {
                DispatchQueue.main.async {
                    strong.profilePicture.image = image
                }
            }
        }
    }
    
    let height: CGFloat = 75
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        let size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
        return CGSize(width: size.width, height: max(size.height, height))
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(profilePicture)
        self.contentView.addSubview(author)
        self.contentView.addSubview(authorLink)
        self.selectionStyle = .gray
        self.backgroundColor = .none
        
        profilePicture.translatesAutoresizingMaskIntoConstraints = false
        profilePicture.widthAnchor.constraint(equalToConstant: 60).isActive = true
        profilePicture.heightAnchor.constraint(equalToConstant: 60).isActive = true
        profilePicture.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 17.5).isActive = true
        profilePicture.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor).isActive = true
        profilePicture.layer.masksToBounds = true
        profilePicture.layer.cornerRadius = 30
        
        author.translatesAutoresizingMaskIntoConstraints = false
        author.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant: -7.5).isActive = true
        author.leadingAnchor.constraint(equalTo: self.profilePicture.trailingAnchor, constant: 7.5).isActive = true
        author.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 7.5).isActive = true
        author.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        author.adjustsFontSizeToFitWidth = true
        
        authorLink.translatesAutoresizingMaskIntoConstraints = false
        authorLink.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant: 10).isActive = true
        authorLink.leadingAnchor.constraint(equalTo: self.profilePicture.trailingAnchor, constant: 7.5).isActive = true
        authorLink.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: 7.5).isActive = true
        authorLink.font = UIFont.systemFont(ofSize: 13, weight: .light)
        authorLink.adjustsFontSizeToFitWidth = true
        
        author.textColor = .sileoLabel
        authorLink.textColor = .sileoLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GithubSocial {
    var githubProfile: String
    var author: String
    var url: String
    var role: String
    var twitter: URL
    
    init(githubProfile: String, author: String, role: String, twitter: URL) {
        self.githubProfile = githubProfile
        self.author = author
        self.url = "https://github.com/\(githubProfile).png"
        self.role = role
        self.twitter = twitter
    }
}
