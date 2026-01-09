import Foundation
import UIKit

@IBDesignable
class WellRoundedSuccessView : UIView {
    
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
        let radius: CGFloat = (bounds.width / 2.0) - (4.0 * contentScalingFactor())
        let circlePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: bounds.width / 2.0, y: bounds.width / 2.0), radius: radius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circlePath.cgPath
    }
    
    func checkmarkPath() -> CGPath {
        return createScaledCheckmarkPath(scale: contentScalingFactor()).cgPath
    }
    
    func setupLayers() {
        circleLayer = CAShapeLayer()
        circleLayer!.path = circlePath()
        circleLayer!.lineWidth = round(8.0 * contentScalingFactor())
        circleLayer!.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor // off-white
        circleLayer!.fillColor = UIColor.clear.cgColor

        circleView = UIView(frame: self.bounds)
        circleView!.backgroundColor = .clear
        circleView!.layer.addSublayer(circleLayer!)
        self.insertSubview(circleView!, at: 0)
        
        checkmarkLayer = CAShapeLayer()
        checkmarkLayer!.path = checkmarkPath()
        checkmarkLayer!.strokeEnd = 0
        checkmarkLayer!.lineWidth = round(6.0 * contentScalingFactor())
        checkmarkLayer!.miterLimit = 10
        checkmarkLayer!.lineCap = .round
        checkmarkLayer!.lineJoin = .round
        checkmarkLayer!.strokeColor = UIColor(red: 0.035, green: 0.710, blue: 0.639, alpha: 1).cgColor // green
        checkmarkLayer!.fillColor = UIColor.clear.cgColor

        checkmarkView = UIView(frame: animationFrame())
        checkmarkView!.backgroundColor = .clear
        checkmarkView!.layer.addSublayer(checkmarkLayer!)
        self.insertSubview(checkmarkView!, at: 1)
    }
    
    func updatePaths() {
        if(circleLayer != nil) {
            circleLayer!.path = circlePath()
            circleLayer!.lineWidth = round(8.0 * contentScalingFactor())
        }
        if(checkmarkLayer != nil) {
            checkmarkLayer!.path = checkmarkPath()
            checkmarkLayer!.lineWidth = round(6.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let checkmarkStrokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        checkmarkStrokeEndAnimation.toValue = 1
        checkmarkStrokeEndAnimation.duration = 0.3
        checkmarkStrokeEndAnimation.autoreverses = false
        checkmarkStrokeEndAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        checkmarkStrokeEndAnimation.repeatCount = 0
        checkmarkStrokeEndAnimation.fillMode = .forwards
        checkmarkStrokeEndAnimation.isRemovedOnCompletion = false
        checkmarkStrokeEndAnimation.beginTime = CACurrentMediaTime() + 0.2
        
        checkmarkLayer!.add(checkmarkStrokeEndAnimation, forKey: "checkmarkStrokeEndAnimations")
        
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

