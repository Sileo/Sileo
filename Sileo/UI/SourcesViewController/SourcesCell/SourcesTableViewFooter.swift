//
//  SourcesTableViewFooter.swift
//  Sileo
//
//  Created by Amy on 30/05/2021.
//  Copyright © 2021 Amy. All rights reserved.
//

import UIKit

class SourcesTableViewFooter: UITableViewHeaderFooterView {
    
    private let titleView = UILabel(frame: CGRect(x: 15, y: 5.5, width: 320, height: 20))
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundView = UIView()
        
        titleView.autoresizingMask = .flexibleWidth
        titleView.textColor = UIColor(red: 145.0/255.0, green: 155.0/255.0, blue: 162.0/255.0, alpha: 1)
        titleView.font = UIFont.systemFont(ofSize: 12)
        addSubview(titleView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setCount(_ count: Int) {
        titleView.text = "\(count) \(String(localizationKey: "Sources_Page"))"
    }
    
}
