import Foundation
import UIKit

@IBDesignable
class PseudoFullscreenUnsuccessView : UIView {
    
    var circleView: UIView?
    var circleLayer: CAShapeLayer?
    
    var crossView: UIView?
    var crossLayer: CAShapeLayer?
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupLayers()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if(circleView != nil) {
            circleView!.frame = self.bounds
        }
        if(crossView != nil) {
            crossView!.frame = animationFrame()
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
    
    func circlePath() -> CGPath {
        let radius: CGFloat = bounds.width / 2.0
        let circlePath = UIBezierPath(arcCenter: CGPoint.init(x: radius, y: radius), radius: radius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circlePath.cgPath
    }
    
    func crossPath() -> CGPath {
        return createScaledCrossPath(scale: contentScalingFactor()).cgPath
    }
    
    func setupLayers() {
        circleLayer = CAShapeLayer()
        circleLayer!.path = circlePath()
        circleLayer!.strokeEnd = 0
        circleLayer!.lineWidth = round(4.0 * contentScalingFactor())
        circleLayer!.lineCap = .round
        circleLayer!.strokeColor = UIColor(red: 0.169, green: 0.169, blue: 0.169, alpha: 1).cgColor // black
        circleLayer!.fillColor = UIColor.clear.cgColor

        circleView = UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: Int(bounds.height)))
        circleView!.backgroundColor = .clear
        circleView!.layer.addSublayer(circleLayer!)
        self.insertSubview(circleView!, at: 0)
        
        crossLayer = CAShapeLayer()
        crossLayer!.path = crossPath()
        crossLayer!.strokeEnd = 0
        crossLayer!.lineWidth = round(4.0 * contentScalingFactor())
        crossLayer!.lineCap = .round
        crossLayer!.strokeColor = UIColor(red: 0.765, green: 0.282, blue: 0.231, alpha: 1).cgColor // red
        crossLayer!.fillColor = UIColor.clear.cgColor

        crossView = UIView(frame: animationFrame())
        crossView!.backgroundColor = .clear
        crossView!.layer.addSublayer(crossLayer!)
        self.insertSubview(crossView!, at: 1)
    }
    
    func updatePaths() {
        if(circleLayer != nil) {
            circleLayer!.path = circlePath()
            circleLayer!.lineWidth = round(4.0 * contentScalingFactor())
        }
        if(crossLayer != nil) {
            crossLayer!.path = crossPath()
            crossLayer!.lineWidth = round(4.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let oldRadius: CGFloat = bounds.width / 2.0
        let newRadius: CGFloat = oldRadius / 2.0
        let newCirclePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: oldRadius, y: oldRadius), radius: newRadius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        
        let circleStrokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        circleStrokeEndAnimation.toValue = 1
        circleStrokeEndAnimation.duration = 0.3
        circleStrokeEndAnimation.autoreverses = false
        circleStrokeEndAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        circleStrokeEndAnimation.repeatCount = 0
        circleStrokeEndAnimation.fillMode = .forwards
        circleStrokeEndAnimation.isRemovedOnCompletion = false

        let circleLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        circleLineWidthAnimation.toValue = oldRadius

        let circlePathAnimation = CABasicAnimation(keyPath: "path")
        circlePathAnimation.toValue = newCirclePath.cgPath

        let circleAnimations: CAAnimationGroup = CAAnimationGroup.init()
        circleAnimations.duration = 0.6
        circleAnimations.repeatCount = 0
        circleAnimations.autoreverses = false
        circleAnimations.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        circleAnimations.fillMode = .forwards
        circleAnimations.animations = [circleLineWidthAnimation, circlePathAnimation]
        circleAnimations.isRemovedOnCompletion = false
        circleAnimations.beginTime = CACurrentMediaTime() + 0.15
        
        let crossStrokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        crossStrokeEndAnimation.toValue = 1
        crossStrokeEndAnimation.duration = 0.3
        crossStrokeEndAnimation.autoreverses = false
        crossStrokeEndAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        crossStrokeEndAnimation.repeatCount = 0
        crossStrokeEndAnimation.fillMode = .forwards
        crossStrokeEndAnimation.isRemovedOnCompletion = false
        crossStrokeEndAnimation.beginTime = CACurrentMediaTime() + 0.75
        
        circleLayer!.add(circleStrokeEndAnimation, forKey: "circleStrokeAnimation")
        circleLayer!.add(circleAnimations, forKey: "circleAnimations")

        crossLayer!.add(crossStrokeEndAnimation, forKey: "crossAnimations")
        
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

