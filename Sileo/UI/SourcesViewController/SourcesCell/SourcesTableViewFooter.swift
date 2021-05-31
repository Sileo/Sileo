//
//  SourcesTableViewFooter.swift
//  Sileo
//
//  Created by Amy on 30/05/2021.
//  Copyright © 2021 Amy. All rights reserved.
//

import UIKit

class SourcesTableViewFooter: UITableViewHeaderFooterView {
    
    private let titleView = UILabel(frame: .zero)
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
    
        titleView.autoresizingMask = .flexibleWidth
        titleView.textAlignment = .center
        titleView.textColor = UIColor(red: 145.0/255.0, green: 155.0/255.0, blue: 162.0/255.0, alpha: 1)
        titleView.font = UIFont.systemFont(ofSize: 12)
        contentView.addSubview(titleView)
        
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.centerXAnchor.constraint(equalTo: contentView.layoutMarginsGuide.centerXAnchor).isActive = true
        titleView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 3.5).isActive = true
        titleView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true
        titleView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
        titleView.heightAnchor.constraint(equalToConstant: 20).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setCount(_ count: Int) {
        titleView.text = "\(count) \(String(localizationKey: "Sources_Page"))"
    }
    
}
