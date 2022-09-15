//
//  SourceProgressIndicatorView.swift
//  Sileo
//
//  Created by CoolStar on 7/27/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SourceProgressIndicatorView: UIView {
    private let barView: UIView
    private var barWidthConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        barView = UIView()
        
        super.init(frame: frame)
        
        barView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(barView)
        barView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        barView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        barView.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        barView.backgroundColor = self.tintColor
    }
    
    public var progress: CGFloat = 0 {
        didSet {
            self.updateProgress()
        }
    }
    
    func updateProgress() {
        barWidthConstraint?.isActive = false
        barWidthConstraint = barView.widthAnchor.constraint(equalTo: self.widthAnchor, multiplier: self.progress)
        barWidthConstraint?.isActive = true
    }
}
