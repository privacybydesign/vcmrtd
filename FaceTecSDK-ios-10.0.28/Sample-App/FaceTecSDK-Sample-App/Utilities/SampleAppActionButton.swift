//
//  SampleAppActionButton.swift
//  FaceTecSDK-Sample-App
//

import Foundation
import UIKit
 
class SampleAppActionButton: UIButton {
    let enabledBackgroundColor: UIColor = UIColor(red: 0.255, green: 0.498, blue: 0.698, alpha: 1.0)
    let disabledBackgroundColor: UIColor = UIColor(red: 0.255, green: 0.498, blue: 0.689, alpha: 0.4)
    let highlightedBackgroundColor: UIColor = UIColor(red: 0.224, green: 0.431, blue: 0.6, alpha: 1.0)
    let titleTextColor = UIColor.white
    
    var _highlighted = false;
    var _enabled = false;
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override var isHighlighted: Bool {
        didSet {
            if self._highlighted == self.isHighlighted {
                return
            }
            self._highlighted = self.isHighlighted

            let backgroundColor = self.isHighlighted ? self.highlightedBackgroundColor : self.enabledBackgroundColor
            let transitionDuration = self.isHighlighted ? 0 : 0.2
            UIView.transition(with: self, duration: transitionDuration, options: [.transitionCrossDissolve, .allowAnimatedContent]) {
                self.setBackgroundImage(self.imageWithColor(color: backgroundColor), for: [.normal, .highlighted])
            } completion: { (_) in }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            if self._enabled == self.isEnabled {
                return
            }
            self._enabled = self.isEnabled

            let backgroundColor = self.isEnabled ? self.enabledBackgroundColor : self.disabledBackgroundColor
            UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve, .allowAnimatedContent]) {
                self.setBackgroundImage(self.imageWithColor(color: backgroundColor), for: [.normal, .disabled])
            } completion: { (_) in }
        }
    }
    
    func setup() {
        isExclusiveTouch = true
        
        backgroundColor = UIColor.clear
        layer.backgroundColor = UIColor.clear.cgColor
        layer.cornerRadius = 8
        layer.borderWidth = 0
        layer.masksToBounds = true
        
        setBackgroundImage(imageWithColor(color: enabledBackgroundColor), for: .normal)
        setBackgroundImage(imageWithColor(color: disabledBackgroundColor), for: .disabled)
        setBackgroundImage(imageWithColor(color: highlightedBackgroundColor), for: .highlighted)
        
        setTitleColor(titleTextColor, for: [.normal, .disabled, .highlighted])
        
        titleEdgeInsets = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        titleLabel?.adjustsFontSizeToFitWidth = false
        
        if #available(iOS 13.0, *) {
            // For iOS 13+, use the rounded system font for displayed text
            if let roundedDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(.rounded) {
                if let roundedBoldDescriptor = roundedDescriptor.withSymbolicTraits(.traitBold) {
                    let roundedButtonFont = UIFont(descriptor: roundedBoldDescriptor, size: (self.titleLabel?.font.pointSize)!)
                    self.titleLabel?.font = roundedButtonFont
                }
            }
        }
        
        self._highlighted = self.isHighlighted;
        self._enabled = self.isEnabled;
    }
    
    func imageWithColor(color: UIColor) -> UIImage {
        let size = CGSize(width: 1, height: 1)
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(rect)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
