import Foundation
import UIKit

@IBDesignable
class PseudoFullscreenSuccessView : UIView {
    
    var circleView: UIView?
    var circleLayer: CAShapeLayer?
    
    var checkmarkView: UIView?
    var checkmarkLayer: CAShapeLayer?
    
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
        if(checkmarkView != nil) {
            checkmarkView!.frame = animationFrame()
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
    
    func checkmarkPath() -> CGPath {
        return createScaledCheckmarkPath(scale: contentScalingFactor()).cgPath
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
        
        checkmarkLayer = CAShapeLayer()
        checkmarkLayer!.path = checkmarkPath()
        checkmarkLayer!.strokeEnd = 0
        checkmarkLayer!.lineWidth = round(4.0 * contentScalingFactor())
        checkmarkLayer!.miterLimit = 10
        checkmarkLayer!.lineCap = .round
        checkmarkLayer!.lineJoin = .round
        checkmarkLayer!.strokeColor = UIColor(red: 0.235, green: 0.702, blue: 0.443, alpha: 1).cgColor // green
        checkmarkLayer!.fillColor = UIColor.clear.cgColor

        checkmarkView = UIView(frame: animationFrame())
        checkmarkView!.backgroundColor = .clear
        checkmarkView!.layer.addSublayer(checkmarkLayer!)
        self.insertSubview(checkmarkView!, at: 1)
    }
    
    func updatePaths() {
        if(circleLayer != nil) {
            circleLayer!.path = circlePath()
            circleLayer!.lineWidth = round(4.0 * contentScalingFactor())
        }
        if(checkmarkLayer != nil) {
            checkmarkLayer!.path = checkmarkPath()
            checkmarkLayer!.lineWidth = round(4.0 * contentScalingFactor())
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
        
        let checkmarkStrokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        checkmarkStrokeEndAnimation.toValue = 1
        checkmarkStrokeEndAnimation.duration = 0.3
        checkmarkStrokeEndAnimation.autoreverses = false
        checkmarkStrokeEndAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        checkmarkStrokeEndAnimation.repeatCount = 0
        checkmarkStrokeEndAnimation.fillMode = .forwards
        checkmarkStrokeEndAnimation.isRemovedOnCompletion = false
        checkmarkStrokeEndAnimation.beginTime = CACurrentMediaTime() + 0.75
        
        circleLayer!.add(circleStrokeEndAnimation, forKey: "circleStrokeAnimation")
        circleLayer!.add(circleAnimations, forKey: "circleAnimations")
        
        checkmarkLayer!.add(checkmarkStrokeEndAnimation, forKey: "checkmarkAnimations")
        
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

