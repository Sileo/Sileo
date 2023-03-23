//
//  NewsArticlesHeader.swift
//  Sileo
//
//  Created by Skitty on 3/1/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class NewsArticlesHeader: UICollectionViewCell {
    var viewController: NewsArticlesViewController
    private var gradientView: NewsGradientBackgroundView = NewsGradientBackgroundView()

    required init?(coder: NSCoder) {
        fatalError("initWithCoder not implemented")
    }
    
    override init(frame: CGRect) {
        viewController = UINib(nibName: "NewsArticlesViewController",
                               bundle: nil).instantiate(withOwner: nil,
                                                        options: nil)[0] as? NewsArticlesViewController ?? NewsArticlesViewController()
        
        super.init(frame: frame)

        self.backgroundColor = UIColor.red
        self.clipsToBounds = false
        
        gradientView = NewsGradientBackgroundView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(gradientView)
        
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: -50),
            gradientView.heightAnchor.constraint(equalTo: self.contentView.heightAnchor, constant: 50)
        ])

        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(viewController.view ?? UIView())

        NSLayoutConstraint.activate([
            self.contentView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            self.contentView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
    }
}
