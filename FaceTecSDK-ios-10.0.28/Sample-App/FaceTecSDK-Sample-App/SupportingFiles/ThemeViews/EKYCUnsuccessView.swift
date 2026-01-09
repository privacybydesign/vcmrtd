import Foundation
import UIKit

@IBDesignable
class EKYCUnsuccessView : UIView {

    var backCrossView: UIView?
    var backCrossLayer: CAShapeLayer?
    
    var frontCrossView: UIView?
    var frontCrossLayer: CAShapeLayer?
    
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupLayers()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if(backCrossView != nil) {
            backCrossView!.frame = animationFrame()
        }
        if(frontCrossView != nil) {
            frontCrossView!.frame = animationFrame()
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
    
    func crossPath() -> CGPath {
        return createScaledCrossPath(scale: contentScalingFactor()).cgPath
    }
    
    func setupLayers() {
        let animationFrameRect: CGRect = animationFrame()
        
        backCrossView = UIView(frame: animationFrameRect)
        backCrossView!.backgroundColor = .clear
        
        backCrossLayer = CAShapeLayer()
        backCrossLayer!.path = crossPath()
        backCrossLayer!.lineWidth = round(10.0 * contentScalingFactor())
        backCrossLayer!.lineCap = .square
        backCrossLayer!.lineJoin = .miter
        backCrossLayer!.strokeColor = UIColor.black.cgColor
        backCrossLayer!.fillColor = UIColor.clear.cgColor

        backCrossView!.layer.addSublayer(backCrossLayer!)
        self.insertSubview(backCrossView!, at: 0)
        
        frontCrossView = UIView(frame: animationFrameRect)
        frontCrossView!.backgroundColor = .clear
        
        frontCrossLayer = CAShapeLayer()
        frontCrossLayer!.path = crossPath()
        frontCrossLayer!.lineWidth = round(10.0 * contentScalingFactor())
        frontCrossLayer!.lineCap = .square
        frontCrossLayer!.lineJoin = .miter
        frontCrossLayer!.strokeColor = UIColor.black.cgColor
        frontCrossLayer!.fillColor = UIColor.clear.cgColor

        frontCrossView!.layer.addSublayer(frontCrossLayer!)
        self.insertSubview(frontCrossView!, at: 1)
        
        backCrossView!.layer.transform = CATransform3DMakeScale(0, 0, 0)
        frontCrossView!.layer.transform = CATransform3DMakeScale(0, 0, 0)
    }
    
    func updatePaths() {
        if(backCrossLayer != nil) {
            backCrossLayer!.path = crossPath()
            backCrossLayer!.lineWidth = round(10.0 * contentScalingFactor())
        }
        if(frontCrossLayer != nil) {
            frontCrossLayer!.path = crossPath()
            frontCrossLayer!.lineWidth = round(10.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let crossOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        crossOpacityAnimation.fromValue = 1.0
        crossOpacityAnimation.toValue = 0.0
        
        let crossColorAnimation = CABasicAnimation(keyPath: "strokeColor")
        crossColorAnimation.fromValue = UIColor.black.cgColor
        crossColorAnimation.toValue = UIColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 1).cgColor // red
        
        let strokeWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        strokeWidthAnimation.fromValue = round(10.0 * contentScalingFactor())
        strokeWidthAnimation.toValue = round(20.0 * contentScalingFactor())
        
        let crossAnimations: CAAnimationGroup = CAAnimationGroup.init()
        crossAnimations.animations = [crossOpacityAnimation, crossColorAnimation, strokeWidthAnimation]
        crossAnimations.duration = 0.5
        crossAnimations.autoreverses = false
        crossAnimations.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        crossAnimations.repeatCount = 0
        crossAnimations.fillMode = .forwards
        crossAnimations.isRemovedOnCompletion = false
        crossAnimations.beginTime = CACurrentMediaTime() + 0.6
        
        backCrossLayer!.add(crossAnimations, forKey: "crossAnimations")
        
        let crossScaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        crossScaleAnimation.fromValue = 0.0
        crossScaleAnimation.toValue = 1.2
        crossScaleAnimation.duration = 0.5
        crossScaleAnimation.autoreverses = false
        crossScaleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        crossScaleAnimation.repeatCount = 0
        crossScaleAnimation.fillMode = .forwards
        crossScaleAnimation.isRemovedOnCompletion = false
        crossScaleAnimation.beginTime = CACurrentMediaTime() + 0.1

        backCrossView!.layer.add(crossScaleAnimation, forKey: "backCrossScaleAnimation")
        frontCrossView!.layer.add(crossScaleAnimation, forKey: "frontCrossScaleAnimation")

        CATransaction.commit()
    }

    func createScaledCrossPath(scale: CGFloat) -> UIBezierPath {
        var leftTopPoint: CGPoint = CGPoint(x: 12, y: 12)
        var leftBottomPoint: CGPoint = CGPoint(x: 12, y: 38)
        var rightTopPoint: CGPoint = CGPoint(x: 38, y: 12)
        var rightBottomPoint: CGPoint = CGPoint(x: 38, y: 38)

        leftTopPoint.x *= scale
        leftTopPoint.y *= scale
        leftBottomPoint.x *= scale
        leftBottomPoint.y *= scale
        rightTopPoint.x *= scale
        rightTopPoint.y *= scale
        rightBottomPoint.x *= scale
        rightBottomPoint.y *= scale

        let crossPath = UIBezierPath.init()
        crossPath.move(to: leftTopPoint)
        crossPath.addLine(to: rightBottomPoint)
        crossPath.move(to: rightTopPoint)
        crossPath.addLine(to: leftBottomPoint)

        return crossPath
    }
}


