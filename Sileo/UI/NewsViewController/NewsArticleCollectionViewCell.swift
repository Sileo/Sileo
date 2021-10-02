//
//  NewsArticleCollectionViewCell.swift
//  Sileo
//
//  Created by Skitty on 3/1/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class NewsArticleCollectionViewCell: UICollectionViewCell {
    override var isHighlighted: Bool {
        didSet {
            unreadView?.backgroundColor = tintColor
            UIView.animate(withDuration: 0.3, animations: {
                self.contentView.alpha = self.isHighlighted ? 0.7 : 1
            })
        }
    }
    public var article: NewsArticle? {
        didSet {
            titleLabel?.text = article?.title
            cardTitleLabel?.text = article?.title
            let formatter = DateFormatter()
            if let locale = LanguageHelper.shared.locale {
                formatter.locale = locale
            }
            let dateText = DateFormatter.localizedString(from: article?.date ?? Date(),
                                                         dateStyle: DateFormatter.Style.long,
                                                         timeStyle: DateFormatter.Style.none)
            dateLabel?.text = dateText
            cardDateLabel?.text = dateText
            excerptLabel?.text = article?.body
            unreadView?.isHidden = article?.userReadDate != nil
            cardUnreadView?.isHidden = article?.userReadDate != nil
            
            self.setNeedsLayout()
        }
    }
    @IBOutlet private var cardView: UIView?
    @IBOutlet private var titleLabel: UILabel?
    @IBOutlet private var dateLabel: UILabel?
    @IBOutlet private var excerptLabel: UILabel?
    @IBOutlet private var unreadView: UIView?
    
    @IBOutlet private var darkeningView: UIView?
    @IBOutlet private var imageView: UIImageView?
    @IBOutlet private var cardTitleLabel: UILabel?
    @IBOutlet private var cardDateLabel: UILabel?
    @IBOutlet private var cardUnreadView: UIView?
    
    private var titleConstraints: [NSLayoutConstraint]?
    private var dateConstraints: [NSLayoutConstraint]?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        cardView?.layer.shadowColor = UIColor(white: 0, alpha: 1).cgColor
        cardView?.layer.shadowOffset = CGSize(width: 10, height: 10)
        cardView?.layer.shadowRadius = 1
        cardView?.layer.shadowOpacity = 1
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        cardView?.layer.shadowPath = UIBezierPath(roundedRect: cardView?.bounds ?? CGRect.zero,
                                                  cornerRadius: cardView?.layer.cornerRadius ?? 0).cgPath

        titleLabel?.textColor = tintColor
        unreadView?.backgroundColor = tintColor
        
        if self.article != nil && self.article?.imageURL != nil {
            if let url = article?.imageURL {
                imageView?.image = EvanderNetworking.shared.image(url, size: imageView?.frame.size) { [weak self] refresh, image in
                    if refresh,
                        let strong = self,
                        let image = image,
                        url == strong.article?.imageURL {
                            DispatchQueue.main.async {
                                strong.imageView?.image = image
                            }
                    }
                }
            }
            cardView?.isHidden = false
            
            var text = article?.type ?? "Editorial"
            if article?.author != nil {
                text += " by " + (article?.author)!
            }
            cardDateLabel?.text = text
                       
            titleConstraints = []
            if let cardTitleLabel = cardTitleLabel {
                titleConstraints?.append(cardTitleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -28))
                titleConstraints?.append(cardTitleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16))
                titleConstraints?.append(cardTitleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 16))
            }
            
            dateConstraints = []
            if let cardDateLabel = cardDateLabel {
                dateConstraints?.append(cardDateLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16))
                dateConstraints?.append(cardDateLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12))
            }
            
            for constraint in titleConstraints ?? [] {
                constraint.isActive = true
            }
            for constraint in dateConstraints ?? [] {
                constraint.isActive = true
            }
        } else {
            cardView?.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.article = nil
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        if self.article?.imageURL == nil {
            titleLabel?.textColor = tintColor
            unreadView?.backgroundColor = tintColor
        }
    }
}
