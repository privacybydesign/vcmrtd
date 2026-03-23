import Foundation
import UIKit

@IBDesignable
class EKYCSuccessView : UIView {

    var backCheckmarkView: UIView?
    var backCheckmarkLayer: CAShapeLayer?
    
    var frontCheckmarkView: UIView?
    var frontCheckmarkLayer: CAShapeLayer?
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupLayers()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if(backCheckmarkView != nil) {
            backCheckmarkView!.frame = animationFrame()
        }
        if(frontCheckmarkView != nil) {
            frontCheckmarkView!.frame = animationFrame()
        }
        
        updatePaths()
    }
    
    func contentScalingFactor() -> CGFloat {
        return bounds.width / 80.0
    }
    
    func animationFrame() -> CGRect {
        let animationDiameter = round(bounds.width * 0.625);
        return CGRect(x: ((bounds.width - animationDiameter) / 2), y: ((bounds.height - animationDiameter) / 2), width: animationDiameter, height: animationDiameter)
    }
    
    func checkmarkPath() -> CGPath {
        return createScaledCheckmarkPath(scale: contentScalingFactor()).cgPath
    }
    
    func setupLayers() {
        let animationFrameRect: CGRect = animationFrame()
        
        backCheckmarkLayer = CAShapeLayer()
        backCheckmarkLayer!.path = checkmarkPath()
        backCheckmarkLayer!.lineWidth = round(10.0 * contentScalingFactor())
        backCheckmarkLayer!.lineCap = .square
        backCheckmarkLayer!.lineJoin = .miter
        backCheckmarkLayer!.strokeColor = UIColor.black.cgColor
        backCheckmarkLayer!.fillColor = UIColor.clear.cgColor

        backCheckmarkView = UIView(frame: animationFrameRect)
        backCheckmarkView!.backgroundColor = .clear
        backCheckmarkView!.layer.addSublayer(backCheckmarkLayer!)
        self.insertSubview(backCheckmarkView!, at: 0)
        
        frontCheckmarkLayer = CAShapeLayer()
        frontCheckmarkLayer!.path = checkmarkPath()
        frontCheckmarkLayer!.lineWidth = round(10.0 * contentScalingFactor())
        frontCheckmarkLayer!.lineCap = .square
        frontCheckmarkLayer!.lineJoin = .miter
        frontCheckmarkLayer!.strokeColor = UIColor.black.cgColor
        frontCheckmarkLayer!.fillColor = UIColor.clear.cgColor

        frontCheckmarkView = UIView(frame: animationFrameRect)
        frontCheckmarkView!.backgroundColor = .clear
        frontCheckmarkView!.layer.addSublayer(frontCheckmarkLayer!)
        self.insertSubview(frontCheckmarkView!, at: 1)
        
        backCheckmarkView!.layer.transform = CATransform3DMakeScale(0, 0, 0)
        frontCheckmarkView!.layer.transform = CATransform3DMakeScale(0, 0, 0)
    }
    
    func updatePaths() {
        if(backCheckmarkLayer != nil) {
            backCheckmarkLayer!.path = checkmarkPath()
            backCheckmarkLayer!.lineWidth = round(10.0 * contentScalingFactor())
        }
        if(frontCheckmarkLayer != nil) {
            frontCheckmarkLayer!.path = checkmarkPath()
            frontCheckmarkLayer!.lineWidth = round(10.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let checkmarkOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        checkmarkOpacityAnimation.fromValue = 1.0
        checkmarkOpacityAnimation.toValue = 0.0
        
        let checkmarkStrokeColorAnimation = CABasicAnimation(keyPath: "strokeColor")
        checkmarkStrokeColorAnimation.fromValue = UIColor.black.cgColor
        checkmarkStrokeColorAnimation.toValue = UIColor(red: 0.11, green: 0.93, blue: 0.49, alpha: 1).cgColor // red
        
        let checkmarkStrokeWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        checkmarkStrokeWidthAnimation.fromValue = round(10.0 * contentScalingFactor())
        checkmarkStrokeWidthAnimation.toValue = round(20.0 * contentScalingFactor())
        
        let backCheckmarkAnimations: CAAnimationGroup = CAAnimationGroup.init()
        backCheckmarkAnimations.animations = [checkmarkOpacityAnimation, checkmarkStrokeColorAnimation, checkmarkStrokeWidthAnimation]
        backCheckmarkAnimations.duration = 0.5
        backCheckmarkAnimations.autoreverses = false
        backCheckmarkAnimations.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        backCheckmarkAnimations.repeatCount = 0
        backCheckmarkAnimations.fillMode = .forwards
        backCheckmarkAnimations.isRemovedOnCompletion = false
        backCheckmarkAnimations.beginTime = CACurrentMediaTime() + 0.6
        
        backCheckmarkLayer!.add(backCheckmarkAnimations, forKey: "crossAnimations")
        
        let checkmarkScaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        checkmarkScaleAnimation.fromValue = 0.0
        checkmarkScaleAnimation.toValue = 1.2
        checkmarkScaleAnimation.duration = 0.5
        checkmarkScaleAnimation.autoreverses = false
        checkmarkScaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        checkmarkScaleAnimation.repeatCount = 0
        checkmarkScaleAnimation.fillMode = .forwards
        checkmarkScaleAnimation.isRemovedOnCompletion = false
        checkmarkScaleAnimation.beginTime = CACurrentMediaTime() + 0.1

        backCheckmarkView!.layer.add(checkmarkScaleAnimation, forKey: "backCrossScaleAnimation")
        frontCheckmarkView!.layer.add(checkmarkScaleAnimation, forKey: "frontCrossScaleAnimation")

        CATransaction.commit()
    }

    func createScaledCheckmarkPath(scale: CGFloat) -> UIBezierPath {
        var leftPoint: CGPoint = CGPoint(x: 9.5, y: 26.5)
        var jointPoint: CGPoint = CGPoint(x: 18.8, y: 36.1)
        var rightPoint: CGPoint = CGPoint(x: 40.5, y: 14.3)

        leftPoint.x *= scale
        leftPoint.y *= scale
        jointPoint.x *= scale
        jointPoint.y *= scale
        rightPoint.x *= scale
        rightPoint.y *= scale

        let checkmarkPath = UIBezierPath.init()
        checkmarkPath.move(to: leftPoint)
        checkmarkPath.addLine(to: jointPoint)
        checkmarkPath.addLine(to: rightPoint)

        return checkmarkPath
    }
}
