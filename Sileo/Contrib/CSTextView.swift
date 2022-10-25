//
//  CSTextView.swift
//  Sileo
//
//  Created by CoolStar on 2/29/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

protocol CSTextViewActionHandler {
    func process(action: String) -> Bool
}

class CSTextView: UIView, CSTextViewActionHandler {
    public var attributedText: NSAttributedString? {
        get {
            renderView.attributedText
        }
        set {
            renderView.attributedText = newValue
        }
    }
    
    var renderView: CSTextRenderView
    private(set) public var overlayView: UIView
    
    override init(frame: CGRect) {
        renderView = CSTextRenderView(frame: CGRect(origin: .zero, size: frame.size))
        overlayView = UIView(frame: .zero)
        
        super.init(frame: frame)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(renderView)
        
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.25)
        self.addSubview(overlayView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        renderView.setNeedsDisplay()
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            renderView.backgroundColor = self.backgroundColor
        }
    }
    
    func process(action: String) -> Bool {
        let superview = self.superview as? CSTextViewActionHandler
        return superview?.process(action: action) ?? false
    }
}
