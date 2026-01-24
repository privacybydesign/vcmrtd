import Foundation
import UIKit

@IBDesignable
class EKYCActvityIndicatorView : UIView {
    
    var circleLayers: [CAShapeLayer] = []
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupLayers()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    func contentScalingFactor() -> CGFloat {
        return bounds.width / 80.0
    }
    
    func circlePath() -> CGPath {
        let radius: CGFloat = round(2.0 * contentScalingFactor())
        let circlePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: round(4.0 * contentScalingFactor()), y: bounds.width / 2.0), radius: radius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circlePath.cgPath
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        for layer in circleLayers {
            layer.path = circlePath()
            layer.lineWidth = round(4.0 * contentScalingFactor())
            
            let index: NSInteger = circleLayers.index(of: layer)!
            self.subviews[index].frame = self.bounds
            layer.frame = self.bounds
        }
    }
    
    func setupLayers() {
        circleLayers = [circleLayer(color: UIColor(red: 0.93, green: 0.11, blue: 0.14, alpha: 1.0)),
                            circleLayer(color: UIColor(red: 0.88, green: 0.24, blue: 0.25, alpha: 1.0)),
                            circleLayer(color: UIColor(red: 0.83, green: 0.35, blue: 0.36, alpha: 1.0)),
                            circleLayer(color: UIColor(red: 0.78, green: 0.44, blue: 0.45, alpha: 1.0))]
        
        for layer in circleLayers {
            let index: NSInteger = circleLayers.index(of: layer)!
            let view = UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: Int(bounds.height)))
            view.backgroundColor = .clear
            view.layer.addSublayer(layer)
            self.insertSubview(view, at: index)
        }
    }
    
    func circleLayer(color: UIColor) -> CAShapeLayer {
        let circleLayer = CAShapeLayer()
        circleLayer.path = circlePath()
        circleLayer.lineWidth = round(4.0 * contentScalingFactor())
        circleLayer.strokeColor = color.cgColor
        circleLayer.fillColor = color.cgColor
        return circleLayer
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let animationDurations = [1.0, 1.2, 1.5, 2.0]
        for view in self.subviews {
            let index: NSInteger = self.subviews.index(of: view)!
            if(index >= animationDurations.count) {
                return
            }
            
            let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
            rotateAnimation.fromValue = 0.0
            rotateAnimation.toValue = CGFloat(Double.pi * 2)
            rotateAnimation.duration = animationDurations[index]
            rotateAnimation.repeatCount = Float.infinity
            rotateAnimation.isRemovedOnCompletion = false
            rotateAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
            
            let strokeWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
            strokeWidthAnimation.fromValue = round(4.0 * contentScalingFactor())
            strokeWidthAnimation.toValue = round(12.0 * contentScalingFactor())
            
            let newCirclePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: round(2.0 * contentScalingFactor()), y: bounds.width / 2.0), radius: round(6.0 * contentScalingFactor()), startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
            let circlePathAnimation = CABasicAnimation(keyPath: "path")
            circlePathAnimation.toValue = newCirclePath.cgPath
            
            let circleAnimations: CAAnimationGroup = CAAnimationGroup.init()
            circleAnimations.animations = [strokeWidthAnimation, circlePathAnimation]
            circleAnimations.duration = animationDurations[index] / 2.0
            circleAnimations.repeatCount = Float.infinity
            circleAnimations.autoreverses = true
            circleAnimations.fillMode = .forwards
            circleAnimations.isRemovedOnCompletion = false
            
            view.layer.add(rotateAnimation, forKey: "circle\(animationDurations[index])RotateAnimation")
            view.layer.sublayers![0].add(circleAnimations, forKey: "circle\(animationDurations[index])StrokeWidthAnimation")
            
            view.transform = CGAffineTransform.identity
        }
        
        CATransaction.commit()
    }
}
