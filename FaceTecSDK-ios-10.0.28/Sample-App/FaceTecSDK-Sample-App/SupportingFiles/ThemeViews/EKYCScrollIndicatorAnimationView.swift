import Foundation
import UIKit

@IBDesignable
class EKYCScrollIndicatorAnimationView : UIView {
    var pathView: UIView?
    var circleLayer: CAShapeLayer?
    var downLayer: CAShapeLayer?
    
    var pathWidthConstraint: NSLayoutConstraint?
    var pathHeightConstraint: NSLayoutConstraint?
    
    var translateDistance: CGFloat = 0
    
    convenience init() {
        self.init(frame: CGRect.zero)

        setupAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setupAnimation()
    }
    
    override func didMoveToSuperview() {
        startAnimation()
    }
    
    func setupAnimation() {
        let viewSize = self.frame.size.height
        let pathSize = viewSize / 2
        let strokeWidth = round(2.0 * contentScalingFactor())
        
        translateDistance = viewSize / 4
        
        if circleLayer == nil {
            circleLayer = CAShapeLayer.init()
            downLayer = CAShapeLayer.init()
        }
        
        let downPath: UIBezierPath = createCompletePath(size: pathSize)
        downLayer?.path = downPath.cgPath
        downLayer?.lineWidth = strokeWidth
        downLayer?.lineCap = .round
        downLayer?.strokeColor = UIColor(red: 0.929, green: 0.110, blue: 0.141, alpha: 1).cgColor // red
        downLayer?.fillColor = UIColor.clear.cgColor
        
        let circleRadius = pathSize / 2
        let circlePath: UIBezierPath = UIBezierPath(arcCenter: CGPoint.init(x: circleRadius, y: circleRadius), radius: circleRadius, startAngle: 0, endAngle: CGFloat(Double.pi) * 2, clockwise: true)
        circleLayer?.path = circlePath.cgPath
        circleLayer?.lineCap = .round
        circleLayer?.strokeColor = UIColor.black.cgColor
        circleLayer?.fillColor = UIColor.black.cgColor
        
        if pathView == nil {
            pathView = UIView.init(frame: CGRect(x: 0, y: 0, width: pathSize, height: pathSize))
            pathView?.backgroundColor = UIColor.clear
            pathView?.layer.addSublayer(circleLayer!)
            pathView?.layer.addSublayer(downLayer!)
        }
        else {
            pathView?.frame = CGRect(x: pathSize, y: pathSize / 2, width: pathSize, height: pathSize)
        }
                
        if !self.subviews.contains(pathView!) {
            self.addSubview(pathView!)
        }
        
        if pathWidthConstraint == nil {
            self.translatesAutoresizingMaskIntoConstraints = false
            pathView?.translatesAutoresizingMaskIntoConstraints = false
            
            pathWidthConstraint = NSLayoutConstraint(item: pathView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: pathSize)
            pathHeightConstraint = NSLayoutConstraint(item: pathView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: pathSize)
            
            self.addConstraints([pathWidthConstraint!, pathHeightConstraint!])
            
            self.addConstraint(NSLayoutConstraint(item: pathView!, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: 0))
            self.addConstraint(NSLayoutConstraint(item: pathView!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0))
        }
        else {
            pathWidthConstraint?.constant = pathSize
            pathHeightConstraint?.constant = pathSize
        }
    }
    
    func createCompletePath(size: CGFloat) -> UIBezierPath {
        let scaleForView: CGFloat = size / 24.0
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 17.7 * scaleForView, y: 10.7 * scaleForView))
        path.addLine(to: CGPoint(x: 12.7 * scaleForView, y: 15.7 * scaleForView))
        path.addCurve(to: CGPoint(x: 11.5 * scaleForView, y: 15.7 * scaleForView), controlPoint1: CGPoint(x: 13.2 * scaleForView, y: 16.2 * scaleForView), controlPoint2: CGPoint(x: 11 * scaleForView, y: 16.2 * scaleForView))
        path.addLine(to: CGPoint(x: 7.7 * scaleForView, y: 10.7 * scaleForView))
        return path;
    }
    
    func startAnimation() {
        animate()
    }
    
    func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 , execute: {
            self.animatePathDown()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 , execute: {
                self.animatePathDown()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3 , execute: {
                    self.animate()
                })
            })
        })
    }
    
    func animatePathDown() {
        pathView?.layer.removeAllAnimations()
        
        let positionAnimation: CABasicAnimation = CABasicAnimation(keyPath: "position")
        positionAnimation.fromValue = NSValue(cgPoint: (pathView?.layer.position)!)
        positionAnimation.toValue = NSValue(cgPoint: CGPoint(x: (pathView?.layer.position.x)!, y: (pathView?.layer.position.y)! + translateDistance))
        positionAnimation.duration = 0.2
        positionAnimation.autoreverses = true
        positionAnimation.isRemovedOnCompletion = true
        positionAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        
        pathView!.layer.add(positionAnimation, forKey: "positionAnimation")
    }
    
    func contentScalingFactor() -> CGFloat {
        return bounds.width / 30.0
    }
}
