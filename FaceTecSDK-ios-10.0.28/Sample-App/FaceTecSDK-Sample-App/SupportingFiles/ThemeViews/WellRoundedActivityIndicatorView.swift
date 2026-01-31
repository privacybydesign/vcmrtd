import Foundation
import UIKit

@IBDesignable
class WellRoundedActivityIndicatorView : UIView {
    
    var circleTrackView: UIView?
    var circleTrackLayer: CAShapeLayer?
    
    var circleFillView: UIView?
    var circleFillLayer: CAShapeLayer?
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupLayers()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if(circleTrackView != nil) {
            circleTrackView!.frame = self.bounds
        }
        if(circleFillView != nil) {
            circleFillView!.frame = self.bounds
        }
        
        updatePaths()
    }
    
    func contentScalingFactor() -> CGFloat {
        return bounds.width / 80.0
    }
    
    func circleTrackPath() -> CGPath {
        let circleTrackRadius: CGFloat = (bounds.width / 2.0) - round(4.0 * contentScalingFactor())
        let circleTrackPath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: bounds.width / 2.0, y: bounds.width / 2.0), radius: circleTrackRadius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circleTrackPath.cgPath
    }
    
    func circleFillPath() -> CGPath {
        let circleFillRadius: CGFloat = round(1.5 * contentScalingFactor())
        let circleFillPath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: round(4.0 * contentScalingFactor()), y: bounds.width / 2.0), radius: circleFillRadius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        return circleFillPath.cgPath
    }
    
    func setupLayers() {
        circleTrackLayer = CAShapeLayer()
        circleTrackLayer!.path = circleTrackPath()
        circleTrackLayer!.lineWidth = round(8.0 * contentScalingFactor())
        circleTrackLayer!.strokeColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor // off-white
        circleTrackLayer!.fillColor = UIColor.clear.cgColor

        circleTrackView = UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: Int(bounds.height)))
        circleTrackView!.backgroundColor = .clear
        circleTrackView!.layer.addSublayer(circleTrackLayer!)
        self.insertSubview(circleTrackView!, at: 0)
        
        circleFillLayer = CAShapeLayer()
        circleFillLayer!.path = circleFillPath()
        circleFillLayer!.lineWidth = round(43.0 * contentScalingFactor())
        circleFillLayer!.strokeColor = UIColor(red: 0.035, green: 0.710, blue: 0.639, alpha: 1).cgColor // green
        circleFillLayer!.fillColor = UIColor(red: 0.035, green: 0.710, blue: 0.639, alpha: 1).cgColor // green

        circleFillView = UIView(frame: CGRect(x: 0, y: 0, width: Int(bounds.width), height: Int(bounds.height)))
        circleFillView!.backgroundColor = .clear
        circleFillView!.layer.addSublayer(circleFillLayer!)
        self.insertSubview(circleFillView!, at: 1)
    }
    
    func updatePaths() {
        if(circleTrackLayer != nil) {
            circleTrackLayer!.path = circleTrackPath()
            circleTrackLayer!.lineWidth = round(8.0 * contentScalingFactor())
        }
        if(circleFillLayer != nil) {
            circleFillLayer!.path = circleFillPath()
            circleFillLayer!.lineWidth = round(3.0 * contentScalingFactor())
        }
    }
    
    func startAnimation() {
        CATransaction.begin()
        
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(Double.pi * 2)
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.duration = 2.0
        rotateAnimation.repeatCount=Float.infinity
        
        circleFillView!.layer.add(rotateAnimation, forKey: "rotateAnimation")
        
        CATransaction.commit()
    }
}
