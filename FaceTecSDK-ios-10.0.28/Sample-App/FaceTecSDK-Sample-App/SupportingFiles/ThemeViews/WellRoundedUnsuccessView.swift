import Foundation
import UIKit

@IBDesignable
class WellRoundedUnsuccessView : UIView {
    
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
        let radius: CGFloat = (bounds.width / 2.0) - (4.0 * contentScalingFactor())
        let circlePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: bounds.width / 2.0, y: bounds.width / 2.0), radius: radius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circlePath.cgPath
    }
    
    func crossPath() -> CGPath {
        return createScaledCrossPath(scale: contentScalingFactor()).cgPath
    }
    
    func setupLayers() {
        circleLayer = CAShapeLayer()
        circleLayer!.path = circlePath()
        circleLayer!.lineWidth = round(8.0 * contentScalingFactor())
        circleLayer!.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor // off-white
        circleLayer!.fillColor = UIColor.clear.cgColor

        circleView = UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: Int(bounds.height)))
        circleView!.backgroundColor = .clear
        circleView!.layer.addSublayer(circleLayer!)
        self.insertSubview(circleView!, at: 0)
        
        crossLayer = CAShapeLayer()
        crossLayer!.path = crossPath()
        crossLayer!.strokeEnd = 0
        crossLayer!.lineWidth = round(6.0 * contentScalingFactor())
        crossLayer!.lineCap = .round
        crossLayer!.lineJoin = .round
        crossLayer!.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor // off-white
        crossLayer!.fillColor = UIColor.clear.cgColor

        crossView = UIView(frame: animationFrame())
        crossView!.backgroundColor = .clear
        crossView!.layer.addSublayer(crossLayer!)
        self.insertSubview(crossView!, at: 1)
    }
    
    func updatePaths() {
        if(circleLayer != nil) {
            circleLayer!.path = circlePath()
            circleLayer!.lineWidth = round(8.0 * contentScalingFactor())
        }
        if(crossLayer != nil) {
            crossLayer!.path = crossPath()
            crossLayer!.lineWidth = round(6.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let crossStrokeEndAnimation = CABasicAnimation(keyPath: "strokeEnd")
        crossStrokeEndAnimation.toValue = 1
        crossStrokeEndAnimation.duration = 0.3
        crossStrokeEndAnimation.autoreverses = false
        crossStrokeEndAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        crossStrokeEndAnimation.repeatCount = 0
        crossStrokeEndAnimation.fillMode = .forwards
        crossStrokeEndAnimation.isRemovedOnCompletion = false
        crossStrokeEndAnimation.beginTime = CACurrentMediaTime() + 0.2

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


