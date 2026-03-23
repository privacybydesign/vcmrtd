import UIKit

class NFCCardStartingAnimationView: UIView {
    // MARK: - Initialization
    init()
    {
        super.init(frame: CGRect(x: 0, y: 0, width: 235, height: 180))
        self.setupLayers()
    }

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.setupLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let scaleFactor = self.bounds.size.height / 180;
        let translateXToCenter = -((235 - self.bounds.size.width) / 2.0);
        let translateYToCenter = -((180 - self.bounds.size.height) / 2.0);
        self.layer.transform = CATransform3DScale(CATransform3DIdentity, scaleFactor, scaleFactor, 1)
        self.layer.transform = CATransform3DTranslate(self.layer.transform, translateXToCenter, translateYToCenter, 1)
    }

    // MARK: - Setup Layers

    private func setupLayers()
    {
        // Colors
        //
        let fillColor = UIColor(red: 0.964706, green: 0.94902, blue: 0.909804, alpha: 1)
        let strokeColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let strokeColor1 = UIColor(red: 0.419608, green: 0.419608, blue: 0.419608, alpha: 1)
        let fillColor1 = UIColor(red: 0.423529, green: 0.423529, blue: 0.423529, alpha: 1)
        let backgroundColor = UIColor(red: 0.160784, green: 0.498039, blue: 0.713725, alpha: 1)
        let backgroundColor1 = UIColor(red: 0.419608, green: 0.419608, blue: 0.419608, alpha: 1)
        let backgroundColor2 = UIColor(red: 0.65098, green: 0.698039, blue: 0.709804, alpha: 1)
        let fillColor2 = UIColor.white
        let strokeColor2 = UIColor.black

        // Paths
        //
        let rectanglePath = CGMutablePath()
        rectanglePath.move(to: CGPoint(x: 6.7, y: 0))
        rectanglePath.addLine(to: CGPoint(x: 68.120003, y: 0))
        rectanglePath.addCurve(to: CGPoint(x: 74.82, y: 6.7), control1: CGPoint(x: 71.82, y: 0), control2: CGPoint(x: 74.82, y: 3))
        rectanglePath.addLine(to: CGPoint(x: 74.82, y: 112))
        rectanglePath.addCurve(to: CGPoint(x: 68.120003, y: 118.699997), control1: CGPoint(x: 74.82, y: 115.699997), control2: CGPoint(x: 71.82, y: 118.699997))
        rectanglePath.addLine(to: CGPoint(x: 6.7, y: 118.699997))
        rectanglePath.addCurve(to: CGPoint(x: 0, y: 112), control1: CGPoint(x: 3, y: 118.699997), control2: CGPoint(x: 0, y: 115.699997))
        rectanglePath.addLine(to: CGPoint(x: 0, y: 6.7))
        rectanglePath.addCurve(to: CGPoint(x: 6.7, y: 0), control1: CGPoint(x: 0, y: 3), control2: CGPoint(x: 3, y: 0))
        rectanglePath.closeSubpath()
        rectanglePath.move(to: CGPoint(x: 6.7, y: 0))
        rectanglePath.closeSubpath()
        rectanglePath.move(to: CGPoint(x: 6.7, y: 0))

        let pathPath = CGMutablePath()
        pathPath.move(to: CGPoint(x: 0, y: 0.41))
        pathPath.addLine(to: CGPoint(x: 107.449997, y: 0.59))
        pathPath.closeSubpath()
        pathPath.move(to: CGPoint(x: 0, y: 0.41))

        let rectanglePath1 = CGMutablePath()
        rectanglePath1.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath1.addLine(to: CGPoint(x: 19.370001, y: 0))
        rectanglePath1.addCurve(to: CGPoint(x: 20.25, y: 0.88), control1: CGPoint(x: 19.856001, y: 0), control2: CGPoint(x: 20.25, y: 0.394))
        rectanglePath1.addLine(to: CGPoint(x: 20.25, y: 2.52))
        rectanglePath1.addCurve(to: CGPoint(x: 19.370001, y: 3.4), control1: CGPoint(x: 20.25, y: 3.006), control2: CGPoint(x: 19.856001, y: 3.4))
        rectanglePath1.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath1.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath1.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath1.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath1.closeSubpath()
        rectanglePath1.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath1.closeSubpath()
        rectanglePath1.move(to: CGPoint(x: 0.88, y: 0))

        let rectanglePath2 = CGMutablePath()
        rectanglePath2.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath2.addLine(to: CGPoint(x: 11.08, y: 0))
        rectanglePath2.addCurve(to: CGPoint(x: 11.96, y: 0.88), control1: CGPoint(x: 11.566, y: 0), control2: CGPoint(x: 11.96, y: 0.394))
        rectanglePath2.addLine(to: CGPoint(x: 11.96, y: 2.52))
        rectanglePath2.addCurve(to: CGPoint(x: 11.08, y: 3.4), control1: CGPoint(x: 11.96, y: 3.006), control2: CGPoint(x: 11.566, y: 3.4))
        rectanglePath2.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath2.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath2.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath2.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath2.closeSubpath()
        rectanglePath2.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath2.closeSubpath()
        rectanglePath2.move(to: CGPoint(x: 0.88, y: 0))

        let rectanglePath3 = CGMutablePath()
        rectanglePath3.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath3.addLine(to: CGPoint(x: 11.08, y: 0))
        rectanglePath3.addCurve(to: CGPoint(x: 11.96, y: 0.88), control1: CGPoint(x: 11.566, y: 0), control2: CGPoint(x: 11.96, y: 0.394))
        rectanglePath3.addLine(to: CGPoint(x: 11.96, y: 2.52))
        rectanglePath3.addCurve(to: CGPoint(x: 11.08, y: 3.4), control1: CGPoint(x: 11.96, y: 3.006), control2: CGPoint(x: 11.566, y: 3.4))
        rectanglePath3.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath3.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath3.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath3.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath3.closeSubpath()
        rectanglePath3.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath3.closeSubpath()
        rectanglePath3.move(to: CGPoint(x: 0.88, y: 0))

        let rectanglePath4 = CGMutablePath()
        rectanglePath4.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath4.addLine(to: CGPoint(x: 36.959999, y: 0))
        rectanglePath4.addCurve(to: CGPoint(x: 37.84, y: 0.88), control1: CGPoint(x: 37.445999, y: 0), control2: CGPoint(x: 37.84, y: 0.394))
        rectanglePath4.addLine(to: CGPoint(x: 37.84, y: 2.52))
        rectanglePath4.addCurve(to: CGPoint(x: 36.959999, y: 3.4), control1: CGPoint(x: 37.84, y: 3.006), control2: CGPoint(x: 37.445999, y: 3.4))
        rectanglePath4.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath4.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath4.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath4.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath4.closeSubpath()
        rectanglePath4.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath4.closeSubpath()
        rectanglePath4.move(to: CGPoint(x: 0.88, y: 0))

        let rectanglePath5 = CGMutablePath()
        rectanglePath5.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath5.addLine(to: CGPoint(x: 36.959999, y: 0))
        rectanglePath5.addCurve(to: CGPoint(x: 37.84, y: 0.88), control1: CGPoint(x: 37.445999, y: 0), control2: CGPoint(x: 37.84, y: 0.394))
        rectanglePath5.addLine(to: CGPoint(x: 37.84, y: 2.52))
        rectanglePath5.addCurve(to: CGPoint(x: 36.959999, y: 3.4), control1: CGPoint(x: 37.84, y: 3.006), control2: CGPoint(x: 37.445999, y: 3.4))
        rectanglePath5.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath5.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath5.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath5.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath5.closeSubpath()
        rectanglePath5.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath5.closeSubpath()
        rectanglePath5.move(to: CGPoint(x: 0.88, y: 0))

        let rectanglePath6 = CGMutablePath()
        rectanglePath6.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath6.addLine(to: CGPoint(x: 36.959999, y: 0))
        rectanglePath6.addCurve(to: CGPoint(x: 37.84, y: 0.88), control1: CGPoint(x: 37.445999, y: 0), control2: CGPoint(x: 37.84, y: 0.394))
        rectanglePath6.addLine(to: CGPoint(x: 37.84, y: 2.52))
        rectanglePath6.addCurve(to: CGPoint(x: 36.959999, y: 3.4), control1: CGPoint(x: 37.84, y: 3.006), control2: CGPoint(x: 37.445999, y: 3.4))
        rectanglePath6.addLine(to: CGPoint(x: 0.88, y: 3.4))
        rectanglePath6.addCurve(to: CGPoint(x: 0, y: 2.52), control1: CGPoint(x: 0.394, y: 3.4), control2: CGPoint(x: 0, y: 3.006))
        rectanglePath6.addLine(to: CGPoint(x: 0, y: 0.88))
        rectanglePath6.addCurve(to: CGPoint(x: 0.88, y: 0), control1: CGPoint(x: 0, y: 0.394), control2: CGPoint(x: 0.394, y: 0))
        rectanglePath6.closeSubpath()
        rectanglePath6.move(to: CGPoint(x: 0.88, y: 0))
        rectanglePath6.closeSubpath()
        rectanglePath6.move(to: CGPoint(x: 0.88, y: 0))

        let pathPath1 = CGMutablePath()
        pathPath1.move(to: CGPoint(x: 0.751, y: 3.271))
        pathPath1.addCurve(to: CGPoint(x: 0.201, y: 2.671), control1: CGPoint(x: 0.509, y: 3.133), control2: CGPoint(x: 0.317, y: 2.923))
        pathPath1.addCurve(to: CGPoint(x: 0.001, y: 1.751), control1: CGPoint(x: 0.062, y: 2.384), control2: CGPoint(x: -0.007, y: 2.069))
        pathPath1.addLine(to: CGPoint(x: 0.001, y: 1.751))
        pathPath1.addCurve(to: CGPoint(x: 0.201, y: 0.831), control1: CGPoint(x: -0.007, y: 1.432), control2: CGPoint(x: 0.062, y: 1.117))
        pathPath1.addCurve(to: CGPoint(x: 0.741, y: 0.221), control1: CGPoint(x: 0.322, y: 0.582), control2: CGPoint(x: 0.508, y: 0.371))
        pathPath1.addCurve(to: CGPoint(x: 1.541, y: 0.001), control1: CGPoint(x: 0.983, y: 0.078), control2: CGPoint(x: 1.259, y: 0.002))
        pathPath1.addCurve(to: CGPoint(x: 2.371, y: 0.211), control1: CGPoint(x: 1.831, y: -0.008), control2: CGPoint(x: 2.119, y: 0.065))
        pathPath1.addCurve(to: CGPoint(x: 2.901, y: 0.801), control1: CGPoint(x: 2.601, y: 0.351), control2: CGPoint(x: 2.785, y: 0.556))
        pathPath1.addCurve(to: CGPoint(x: 3.091, y: 1.681), control1: CGPoint(x: 3.033, y: 1.075), control2: CGPoint(x: 3.099, y: 1.376))
        pathPath1.addLine(to: CGPoint(x: 3.091, y: 1.941))
        pathPath1.addLine(to: CGPoint(x: 0.391, y: 1.941))
        pathPath1.addLine(to: CGPoint(x: 0.391, y: 1.421))
        pathPath1.addLine(to: CGPoint(x: 2.751, y: 1.421))
        pathPath1.addLine(to: CGPoint(x: 2.371, y: 1.911))
        pathPath1.addLine(to: CGPoint(x: 2.371, y: 1.611))
        pathPath1.addCurve(to: CGPoint(x: 2.271, y: 1.061), control1: CGPoint(x: 2.373, y: 1.423), control2: CGPoint(x: 2.339, y: 1.236))
        pathPath1.addCurve(to: CGPoint(x: 1.991, y: 0.741), control1: CGPoint(x: 2.211, y: 0.929), control2: CGPoint(x: 2.114, y: 0.817))
        pathPath1.addCurve(to: CGPoint(x: 1.541, y: 0.621), control1: CGPoint(x: 1.859, y: 0.65), control2: CGPoint(x: 1.7, y: 0.608))
        pathPath1.addCurve(to: CGPoint(x: 1.131, y: 0.731), control1: CGPoint(x: 1.397, y: 0.62), control2: CGPoint(x: 1.255, y: 0.658))
        pathPath1.addCurve(to: CGPoint(x: 0.841, y: 1.061), control1: CGPoint(x: 1.004, y: 0.811), control2: CGPoint(x: 0.904, y: 0.925))
        pathPath1.addCurve(to: CGPoint(x: 0.741, y: 1.601), control1: CGPoint(x: 0.773, y: 1.233), control2: CGPoint(x: 0.739, y: 1.416))
        pathPath1.addLine(to: CGPoint(x: 0.741, y: 1.901))
        pathPath1.addCurve(to: CGPoint(x: 0.841, y: 2.421), control1: CGPoint(x: 0.739, y: 2.079), control2: CGPoint(x: 0.773, y: 2.256))
        pathPath1.addCurve(to: CGPoint(x: 1.141, y: 2.751), control1: CGPoint(x: 0.901, y: 2.561), control2: CGPoint(x: 1.007, y: 2.677))
        pathPath1.addCurve(to: CGPoint(x: 1.591, y: 2.871), control1: CGPoint(x: 1.275, y: 2.835), control2: CGPoint(x: 1.432, y: 2.877))
        pathPath1.addCurve(to: CGPoint(x: 1.931, y: 2.811), control1: CGPoint(x: 1.707, y: 2.873), control2: CGPoint(x: 1.822, y: 2.852))
        pathPath1.addCurve(to: CGPoint(x: 2.171, y: 2.651), control1: CGPoint(x: 2.021, y: 2.774), control2: CGPoint(x: 2.102, y: 2.72))
        pathPath1.addCurve(to: CGPoint(x: 2.351, y: 2.421), control1: CGPoint(x: 2.247, y: 2.589), control2: CGPoint(x: 2.309, y: 2.51))
        pathPath1.addLine(to: CGPoint(x: 2.351, y: 2.421))
        pathPath1.addLine(to: CGPoint(x: 3.081, y: 2.421))
        pathPath1.addLine(to: CGPoint(x: 3.081, y: 2.421))
        pathPath1.addCurve(to: CGPoint(x: 2.931, y: 2.801), control1: CGPoint(x: 3.048, y: 2.554), control2: CGPoint(x: 2.998, y: 2.681))
        pathPath1.addCurve(to: CGPoint(x: 2.631, y: 3.131), control1: CGPoint(x: 2.853, y: 2.929), control2: CGPoint(x: 2.751, y: 3.041))
        pathPath1.addCurve(to: CGPoint(x: 2.191, y: 3.361), control1: CGPoint(x: 2.501, y: 3.236), control2: CGPoint(x: 2.351, y: 3.315))
        pathPath1.addCurve(to: CGPoint(x: 1.611, y: 3.451), control1: CGPoint(x: 2.004, y: 3.424), control2: CGPoint(x: 1.808, y: 3.454))
        pathPath1.addCurve(to: CGPoint(x: 0.751, y: 3.271), control1: CGPoint(x: 1.313, y: 3.468), control2: CGPoint(x: 1.016, y: 3.405))
        pathPath1.closeSubpath()
        pathPath1.move(to: CGPoint(x: 0.751, y: 3.271))

        let pathPath2 = CGMutablePath()
        pathPath2.move(to: CGPoint(x: 1.002, y: 4.421))
        pathPath2.addCurve(to: CGPoint(x: 0.272, y: 3.631), control1: CGPoint(x: 0.691, y: 4.229), control2: CGPoint(x: 0.438, y: 3.956))
        pathPath2.addCurve(to: CGPoint(x: 0.002, y: 2.351), control1: CGPoint(x: 0.079, y: 3.233), control2: CGPoint(x: -0.014, y: 2.793))
        pathPath2.addLine(to: CGPoint(x: 0.002, y: 2.351))
        pathPath2.addCurve(to: CGPoint(x: 0.262, y: 1.091), control1: CGPoint(x: -0.013, y: 1.916), control2: CGPoint(x: 0.076, y: 1.484))
        pathPath2.addCurve(to: CGPoint(x: 1.002, y: 0.281), control1: CGPoint(x: 0.422, y: 0.753), control2: CGPoint(x: 0.68, y: 0.471))
        pathPath2.addCurve(to: CGPoint(x: 2.132, y: 0.001), control1: CGPoint(x: 1.346, y: 0.087), control2: CGPoint(x: 1.737, y: -0.01))
        pathPath2.addCurve(to: CGPoint(x: 3.072, y: 0.201), control1: CGPoint(x: 2.456, y: -0.008), control2: CGPoint(x: 2.779, y: 0.061))
        pathPath2.addCurve(to: CGPoint(x: 3.742, y: 0.761), control1: CGPoint(x: 3.339, y: 0.327), control2: CGPoint(x: 3.57, y: 0.52))
        pathPath2.addCurve(to: CGPoint(x: 4.072, y: 1.581), control1: CGPoint(x: 3.924, y: 0.999), control2: CGPoint(x: 4.038, y: 1.283))
        pathPath2.addLine(to: CGPoint(x: 4.072, y: 1.581))
        pathPath2.addLine(to: CGPoint(x: 3.272, y: 1.581))
        pathPath2.addLine(to: CGPoint(x: 3.272, y: 1.521))
        pathPath2.addCurve(to: CGPoint(x: 3.052, y: 1.071), control1: CGPoint(x: 3.231, y: 1.357), control2: CGPoint(x: 3.156, y: 1.203))
        pathPath2.addCurve(to: CGPoint(x: 2.672, y: 0.771), control1: CGPoint(x: 2.952, y: 0.941), control2: CGPoint(x: 2.821, y: 0.838))
        pathPath2.addCurve(to: CGPoint(x: 2.142, y: 0.671), control1: CGPoint(x: 2.504, y: 0.701), control2: CGPoint(x: 2.323, y: 0.666))
        pathPath2.addCurve(to: CGPoint(x: 1.452, y: 0.871), control1: CGPoint(x: 1.897, y: 0.668), control2: CGPoint(x: 1.657, y: 0.738))
        pathPath2.addCurve(to: CGPoint(x: 1.002, y: 1.441), control1: CGPoint(x: 1.25, y: 1.013), control2: CGPoint(x: 1.094, y: 1.211))
        pathPath2.addCurve(to: CGPoint(x: 0.842, y: 2.321), control1: CGPoint(x: 0.888, y: 1.72), control2: CGPoint(x: 0.833, y: 2.02))
        pathPath2.addLine(to: CGPoint(x: 0.842, y: 2.321))
        pathPath2.addCurve(to: CGPoint(x: 1.002, y: 3.191), control1: CGPoint(x: 0.833, y: 2.619), control2: CGPoint(x: 0.888, y: 2.915))
        pathPath2.addCurve(to: CGPoint(x: 2.142, y: 3.971), control1: CGPoint(x: 1.171, y: 3.671), control2: CGPoint(x: 1.632, y: 3.987))
        pathPath2.addCurve(to: CGPoint(x: 2.662, y: 3.871), control1: CGPoint(x: 2.32, y: 3.975), control2: CGPoint(x: 2.498, y: 3.941))
        pathPath2.addCurve(to: CGPoint(x: 3.052, y: 3.571), control1: CGPoint(x: 2.812, y: 3.8), control2: CGPoint(x: 2.945, y: 3.698))
        pathPath2.addCurve(to: CGPoint(x: 3.282, y: 3.091), control1: CGPoint(x: 3.16, y: 3.428), control2: CGPoint(x: 3.238, y: 3.265))
        pathPath2.addLine(to: CGPoint(x: 3.282, y: 3.091))
        pathPath2.addLine(to: CGPoint(x: 4.082, y: 3.091))
        pathPath2.addLine(to: CGPoint(x: 4.082, y: 3.091))
        pathPath2.addCurve(to: CGPoint(x: 3.762, y: 3.911), control1: CGPoint(x: 4.045, y: 3.387), control2: CGPoint(x: 3.935, y: 3.668))
        pathPath2.addCurve(to: CGPoint(x: 3.082, y: 4.461), control1: CGPoint(x: 3.583, y: 4.146), control2: CGPoint(x: 3.349, y: 4.335))
        pathPath2.addCurve(to: CGPoint(x: 2.142, y: 4.661), control1: CGPoint(x: 2.789, y: 4.601), control2: CGPoint(x: 2.466, y: 4.669))
        pathPath2.addCurve(to: CGPoint(x: 1.002, y: 4.421), control1: CGPoint(x: 1.747, y: 4.686), control2: CGPoint(x: 1.353, y: 4.603))
        pathPath2.closeSubpath()
        pathPath2.move(to: CGPoint(x: 1.002, y: 4.421))

        let shapePath = CGMutablePath()
        shapePath.move(to: CGPoint(x: 1.63, y: 0))
        shapePath.addLine(to: CGPoint(x: 2.31, y: 0))
        shapePath.addLine(to: CGPoint(x: 2.31, y: 0.81))
        shapePath.addLine(to: CGPoint(x: 2.07, y: 0.81))
        shapePath.addLine(to: CGPoint(x: 0.85, y: 4.55))
        shapePath.addLine(to: CGPoint(x: 0, y: 4.55))
        shapePath.addLine(to: CGPoint(x: 1.63, y: 0))
        shapePath.closeSubpath()
        shapePath.move(to: CGPoint(x: 1.04, y: 2.74))
        shapePath.addLine(to: CGPoint(x: 3.12, y: 2.74))
        shapePath.addLine(to: CGPoint(x: 3.34, y: 3.37))
        shapePath.addLine(to: CGPoint(x: 0.82, y: 3.37))
        shapePath.addLine(to: CGPoint(x: 1.04, y: 2.74))
        shapePath.closeSubpath()
        shapePath.move(to: CGPoint(x: 2.04, y: 0.81))
        shapePath.addLine(to: CGPoint(x: 2.04, y: 0))
        shapePath.addLine(to: CGPoint(x: 2.49, y: 0))
        shapePath.addLine(to: CGPoint(x: 4.16, y: 4.55))
        shapePath.addLine(to: CGPoint(x: 3.31, y: 4.55))
        shapePath.addLine(to: CGPoint(x: 2.04, y: 0.81))
        shapePath.closeSubpath()
        shapePath.move(to: CGPoint(x: 2.04, y: 0.81))

        let shapePath1 = CGMutablePath()
        shapePath1.move(to: CGPoint(x: 0, y: 0.001))
        shapePath1.addLine(to: CGPoint(x: 1.82, y: 0.001))
        shapePath1.addCurve(to: CGPoint(x: 2.65, y: 0.171), control1: CGPoint(x: 2.106, y: -0.01), control2: CGPoint(x: 2.391, y: 0.049))
        shapePath1.addCurve(to: CGPoint(x: 3.19, y: 0.661), control1: CGPoint(x: 2.874, y: 0.279), control2: CGPoint(x: 3.061, y: 0.449))
        shapePath1.addCurve(to: CGPoint(x: 3.38, y: 1.411), control1: CGPoint(x: 3.323, y: 0.888), control2: CGPoint(x: 3.389, y: 1.148))
        shapePath1.addLine(to: CGPoint(x: 3.38, y: 1.411))
        shapePath1.addCurve(to: CGPoint(x: 3.15, y: 2.221), control1: CGPoint(x: 3.385, y: 1.698), control2: CGPoint(x: 3.305, y: 1.98))
        shapePath1.addCurve(to: CGPoint(x: 2.52, y: 2.711), control1: CGPoint(x: 2.995, y: 2.445), control2: CGPoint(x: 2.775, y: 2.616))
        shapePath1.addLine(to: CGPoint(x: 3.52, y: 4.531))
        shapePath1.addLine(to: CGPoint(x: 2.6, y: 4.531))
        shapePath1.addLine(to: CGPoint(x: 1.7, y: 2.831))
        shapePath1.addLine(to: CGPoint(x: 0.82, y: 2.831))
        shapePath1.addLine(to: CGPoint(x: 0.82, y: 4.551))
        shapePath1.addLine(to: CGPoint(x: 0.01, y: 4.551))
        shapePath1.addLine(to: CGPoint(x: 0, y: 0.001))
        shapePath1.closeSubpath()
        shapePath1.move(to: CGPoint(x: 1.73, y: 2.201))
        shapePath1.addCurve(to: CGPoint(x: 2.33, y: 2.001), control1: CGPoint(x: 1.948, y: 2.214), control2: CGPoint(x: 2.163, y: 2.143))
        shapePath1.addCurve(to: CGPoint(x: 2.55, y: 1.431), control1: CGPoint(x: 2.478, y: 1.849), control2: CGPoint(x: 2.557, y: 1.643))
        shapePath1.addLine(to: CGPoint(x: 2.55, y: 1.431))
        shapePath1.addCurve(to: CGPoint(x: 2.32, y: 0.871), control1: CGPoint(x: 2.559, y: 1.22), control2: CGPoint(x: 2.475, y: 1.015))
        shapePath1.addCurve(to: CGPoint(x: 1.71, y: 0.661), control1: CGPoint(x: 2.152, y: 0.724), control2: CGPoint(x: 1.933, y: 0.648))
        shapePath1.addLine(to: CGPoint(x: 0.81, y: 0.661))
        shapePath1.addLine(to: CGPoint(x: 0.81, y: 2.211))
        shapePath1.addLine(to: CGPoint(x: 1.73, y: 2.201))
        shapePath1.closeSubpath()
        shapePath1.move(to: CGPoint(x: 1.73, y: 2.201))

        let shapePath2 = CGMutablePath()
        shapePath2.move(to: CGPoint(x: 0, y: 0.002))
        shapePath2.addLine(to: CGPoint(x: 1.67, y: 0.002))
        shapePath2.addCurve(to: CGPoint(x: 2.83, y: 0.262), control1: CGPoint(x: 2.073, y: -0.013), control2: CGPoint(x: 2.472, y: 0.076))
        shapePath2.addCurve(to: CGPoint(x: 3.57, y: 1.032), control1: CGPoint(x: 3.15, y: 0.436), control2: CGPoint(x: 3.408, y: 0.705))
        shapePath2.addCurve(to: CGPoint(x: 3.83, y: 2.252), control1: CGPoint(x: 3.751, y: 1.412), control2: CGPoint(x: 3.84, y: 1.83))
        shapePath2.addLine(to: CGPoint(x: 3.83, y: 2.252))
        shapePath2.addCurve(to: CGPoint(x: 3.57, y: 3.482), control1: CGPoint(x: 3.841, y: 2.676), control2: CGPoint(x: 3.752, y: 3.097))
        shapePath2.addCurve(to: CGPoint(x: 2.83, y: 4.262), control1: CGPoint(x: 3.409, y: 3.811), control2: CGPoint(x: 3.15, y: 4.083))
        shapePath2.addCurve(to: CGPoint(x: 1.67, y: 4.532), control1: CGPoint(x: 2.473, y: 4.45), control2: CGPoint(x: 2.073, y: 4.543))
        shapePath2.addLine(to: CGPoint(x: 0, y: 4.532))
        shapePath2.addLine(to: CGPoint(x: 0, y: 0.002))
        shapePath2.closeSubpath()
        shapePath2.move(to: CGPoint(x: 1.58, y: 3.862))
        shapePath2.addCurve(to: CGPoint(x: 2.36, y: 3.682), control1: CGPoint(x: 1.851, y: 3.869), control2: CGPoint(x: 2.12, y: 3.808))
        shapePath2.addCurve(to: CGPoint(x: 2.83, y: 3.142), control1: CGPoint(x: 2.566, y: 3.552), control2: CGPoint(x: 2.73, y: 3.364))
        shapePath2.addCurve(to: CGPoint(x: 3, y: 2.262), control1: CGPoint(x: 2.95, y: 2.864), control2: CGPoint(x: 3.008, y: 2.564))
        shapePath2.addLine(to: CGPoint(x: 3, y: 2.262))
        shapePath2.addCurve(to: CGPoint(x: 2.83, y: 1.402), control1: CGPoint(x: 3.008, y: 1.966), control2: CGPoint(x: 2.95, y: 1.672))
        shapePath2.addCurve(to: CGPoint(x: 2.35, y: 0.862), control1: CGPoint(x: 2.732, y: 1.175), control2: CGPoint(x: 2.564, y: 0.985))
        shapePath2.addCurve(to: CGPoint(x: 1.58, y: 0.682), control1: CGPoint(x: 2.113, y: 0.736), control2: CGPoint(x: 1.848, y: 0.674))
        shapePath2.addLine(to: CGPoint(x: 0.82, y: 0.682))
        shapePath2.addLine(to: CGPoint(x: 0.82, y: 3.862))
        shapePath2.addLine(to: CGPoint(x: 1.58, y: 3.862))
        shapePath2.closeSubpath()
        shapePath2.move(to: CGPoint(x: 1.58, y: 3.862))

        let pathPath3 = CGMutablePath()
        pathPath3.move(to: CGPoint(x: 4.51, y: 0))
        pathPath3.addLine(to: CGPoint(x: 8.84, y: 0))
        pathPath3.addCurve(to: CGPoint(x: 9.01, y: 0.17), control1: CGPoint(x: 8.97, y: 0), control2: CGPoint(x: 9.01, y: 0))
        pathPath3.addLine(to: CGPoint(x: 9.01, y: 2.23))
        pathPath3.addCurve(to: CGPoint(x: 8.86, y: 2.39), control1: CGPoint(x: 9.01, y: 2.35), control2: CGPoint(x: 9.01, y: 2.39))
        pathPath3.addLine(to: CGPoint(x: 6.51, y: 2.39))
        pathPath3.addCurve(to: CGPoint(x: 6.35, y: 2.27), control1: CGPoint(x: 6.42, y: 2.39), control2: CGPoint(x: 6.38, y: 2.39))
        pathPath3.addCurve(to: CGPoint(x: 4.94, y: 0.88), control1: CGPoint(x: 6.191, y: 1.572), control2: CGPoint(x: 5.64, y: 1.029))
        pathPath3.addCurve(to: CGPoint(x: 2.76, y: 1.97), control1: CGPoint(x: 4.045, y: 0.664), control2: CGPoint(x: 3.124, y: 1.124))
        pathPath3.addCurve(to: CGPoint(x: 2.66, y: 2.26), control1: CGPoint(x: 2.712, y: 2.061), control2: CGPoint(x: 2.678, y: 2.159))
        pathPath3.addCurve(to: CGPoint(x: 2.48, y: 2.39), control1: CGPoint(x: 2.66, y: 2.38), control2: CGPoint(x: 2.58, y: 2.39))
        pathPath3.addLine(to: CGPoint(x: 0.16, y: 2.39))
        pathPath3.addCurve(to: CGPoint(x: 0, y: 2.23), control1: CGPoint(x: 0.04, y: 2.39), control2: CGPoint(x: 0, y: 2.39))
        pathPath3.addLine(to: CGPoint(x: 0, y: 0.17))
        pathPath3.addCurve(to: CGPoint(x: 0.17, y: 0), control1: CGPoint(x: 0, y: 0.03), control2: CGPoint(x: 0, y: 0))
        pathPath3.addLine(to: CGPoint(x: 4.51, y: 0))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 4.51, y: 0))

        let pathPath4 = CGMutablePath()
        pathPath4.move(to: CGPoint(x: 4.51, y: 2.381))
        pathPath4.addLine(to: CGPoint(x: 0.21, y: 2.381))
        pathPath4.addCurve(to: CGPoint(x: 0, y: 2.181), control1: CGPoint(x: 0, y: 2.381), control2: CGPoint(x: 0, y: 2.381))
        pathPath4.addLine(to: CGPoint(x: 0, y: 0.181))
        pathPath4.addCurve(to: CGPoint(x: 0.17, y: 0.001), control1: CGPoint(x: 0, y: 0.051), control2: CGPoint(x: 0, y: -0.009))
        pathPath4.addLine(to: CGPoint(x: 2.48, y: 0.001))
        pathPath4.addCurve(to: CGPoint(x: 2.66, y: 0.121), control1: CGPoint(x: 2.57, y: 0.001), control2: CGPoint(x: 2.63, y: 0.001))
        pathPath4.addCurve(to: CGPoint(x: 4.343, y: 1.547), control1: CGPoint(x: 2.859, y: 0.907), control2: CGPoint(x: 3.535, y: 1.48))
        pathPath4.addCurve(to: CGPoint(x: 6.24, y: 0.421), control1: CGPoint(x: 5.151, y: 1.615), control2: CGPoint(x: 5.913, y: 1.163))
        pathPath4.addCurve(to: CGPoint(x: 6.35, y: 0.121), control1: CGPoint(x: 6.285, y: 0.324), control2: CGPoint(x: 6.322, y: 0.224))
        pathPath4.addCurve(to: CGPoint(x: 6.52, y: 0.001), control1: CGPoint(x: 6.35, y: 0.021), control2: CGPoint(x: 6.42, y: 0.001))
        pathPath4.addLine(to: CGPoint(x: 8.85, y: 0.001))
        pathPath4.addCurve(to: CGPoint(x: 9.01, y: 0.161), control1: CGPoint(x: 8.98, y: 0.001), control2: CGPoint(x: 9.01, y: 0.001))
        pathPath4.addLine(to: CGPoint(x: 9.01, y: 2.161))
        pathPath4.addCurve(to: CGPoint(x: 8.82, y: 2.351), control1: CGPoint(x: 9.01, y: 2.351), control2: CGPoint(x: 9.01, y: 2.351))
        pathPath4.addLine(to: CGPoint(x: 4.51, y: 2.381))
        pathPath4.closeSubpath()
        pathPath4.move(to: CGPoint(x: 4.51, y: 2.381))

        let pathPath5 = CGMutablePath()
        pathPath5.move(to: CGPoint(x: 0, y: 1.26))
        pathPath5.addCurve(to: CGPoint(x: 1.277, y: 0), control1: CGPoint(x: 0.006, y: 0.56), control2: CGPoint(x: 0.577, y: -0.004))
        pathPath5.addCurve(to: CGPoint(x: 2.54, y: 1.273), control1: CGPoint(x: 1.977, y: 0.004), control2: CGPoint(x: 2.542, y: 0.573))
        pathPath5.addCurve(to: CGPoint(x: 1.27, y: 2.54), control1: CGPoint(x: 2.538, y: 1.973), control2: CGPoint(x: 1.97, y: 2.54))
        pathPath5.addCurve(to: CGPoint(x: 0.366, y: 2.168), control1: CGPoint(x: 0.931, y: 2.543), control2: CGPoint(x: 0.605, y: 2.408))
        pathPath5.addCurve(to: CGPoint(x: 0, y: 1.26), control1: CGPoint(x: 0.127, y: 1.927), control2: CGPoint(x: -0.005, y: 1.599))
        pathPath5.closeSubpath()
        pathPath5.move(to: CGPoint(x: 0, y: 1.26))

        let shapePath3 = CGMutablePath()
        shapePath3.move(to: CGPoint(x: 14.09, y: 0))
        shapePath3.addCurve(to: CGPoint(x: 1.074, y: 8.687), control1: CGPoint(x: 8.394, y: -0.004), control2: CGPoint(x: 3.256, y: 3.425))
        shapePath3.addCurve(to: CGPoint(x: 4.124, y: 24.035999), control1: CGPoint(x: -1.108, y: 13.949), control2: CGPoint(x: 0.096, y: 20.007999))
        shapePath3.addCurve(to: CGPoint(x: 19.473, y: 27.086), control1: CGPoint(x: 8.152, y: 28.063999), control2: CGPoint(x: 14.211, y: 29.268))
        shapePath3.addCurve(to: CGPoint(x: 28.16, y: 14.07), control1: CGPoint(x: 24.735001, y: 24.903999), control2: CGPoint(x: 28.164, y: 19.767))
        shapePath3.addCurve(to: CGPoint(x: 14.09, y: 0), control1: CGPoint(x: 28.149, y: 6.304), control2: CGPoint(x: 21.856001, y: 0.011))
        shapePath3.closeSubpath()
        shapePath3.move(to: CGPoint(x: 20.84, y: 25.18))
        shapePath3.addCurve(to: CGPoint(x: 16.690001, y: 26.82), control1: CGPoint(x: 19.559999, y: 25.958), control2: CGPoint(x: 18.157, y: 26.511999))
        shapePath3.addCurve(to: CGPoint(x: 7.31, y: 25.190001), control1: CGPoint(x: 13.47, y: 27.471001), control2: CGPoint(x: 10.122, y: 26.889999))
        shapePath3.addCurve(to: CGPoint(x: 7.139, y: 25.021), control1: CGPoint(x: 7.233, y: 25.159), control2: CGPoint(x: 7.171, y: 25.098))
        shapePath3.addCurve(to: CGPoint(x: 7.14, y: 24.780001), control1: CGPoint(x: 7.107, y: 24.944), control2: CGPoint(x: 7.107, y: 24.857))
        shapePath3.addCurve(to: CGPoint(x: 8.3, y: 21.26), control1: CGPoint(x: 7.468, y: 23.587999), control2: CGPoint(x: 7.855, y: 22.413))
        shapePath3.addCurve(to: CGPoint(x: 10.3, y: 17.370001), control1: CGPoint(x: 8.788, y: 19.879), control2: CGPoint(x: 9.461, y: 18.57))
        shapePath3.addCurve(to: CGPoint(x: 11.16, y: 16.25), control1: CGPoint(x: 10.58, y: 16.99), control2: CGPoint(x: 10.87, y: 16.620001))
        shapePath3.addCurve(to: CGPoint(x: 11.41, y: 16.200001), control1: CGPoint(x: 11.23, y: 16.15), control2: CGPoint(x: 11.3, y: 16.139999))
        shapePath3.addCurve(to: CGPoint(x: 16.59, y: 16.200001), control1: CGPoint(x: 13.037, y: 17.030001), control2: CGPoint(x: 14.963, y: 17.030001))
        shapePath3.addCurve(to: CGPoint(x: 16.77, y: 16.162001), control1: CGPoint(x: 16.641001, y: 16.160999), control2: CGPoint(x: 16.707001, y: 16.146999))
        shapePath3.addCurve(to: CGPoint(x: 16.91, y: 16.280001), control1: CGPoint(x: 16.832001, y: 16.177999), control2: CGPoint(x: 16.884001, y: 16.221001))
        shapePath3.addCurve(to: CGPoint(x: 19.43, y: 20.540001), control1: CGPoint(x: 17.940001, y: 17.579), control2: CGPoint(x: 18.788, y: 19.011999))
        shapePath3.addCurve(to: CGPoint(x: 20.91, y: 24.969999), control1: CGPoint(x: 20.013, y: 21.985001), control2: CGPoint(x: 20.507999, y: 23.465))
        shapePath3.addCurve(to: CGPoint(x: 20.84, y: 25.18), control1: CGPoint(x: 20.941999, y: 25.048), control2: CGPoint(x: 20.912001, y: 25.136999))
        shapePath3.closeSubpath()
        shapePath3.move(to: CGPoint(x: 10.69, y: 14.26))
        shapePath3.addCurve(to: CGPoint(x: 10.56, y: 5.84), control1: CGPoint(x: 8.354, y: 11.96), control2: CGPoint(x: 8.296, y: 8.211))
        shapePath3.addCurve(to: CGPoint(x: 14.385, y: 4.363), control1: CGPoint(x: 11.553, y: 4.805), control2: CGPoint(x: 12.954, y: 4.264))
        shapePath3.addCurve(to: CGPoint(x: 17.969999, y: 6.35), control1: CGPoint(x: 15.815, y: 4.461), control2: CGPoint(x: 17.129, y: 5.189))
        shapePath3.addCurve(to: CGPoint(x: 19.18, y: 9.98), control1: CGPoint(x: 18.759001, y: 7.396), control2: CGPoint(x: 19.184, y: 8.67))
        shapePath3.addCurve(to: CGPoint(x: 17.18, y: 14.48), control1: CGPoint(x: 19.218, y: 11.703), control2: CGPoint(x: 18.485001, y: 13.353))
        shapePath3.addCurve(to: CGPoint(x: 10.69, y: 14.26), control1: CGPoint(x: 15.292, y: 16.113001), control2: CGPoint(x: 12.464, y: 16.017))
        shapePath3.addLine(to: CGPoint(x: 10.69, y: 14.26))
        shapePath3.closeSubpath()
        shapePath3.move(to: CGPoint(x: 21.940001, y: 24.440001))
        shapePath3.addLine(to: CGPoint(x: 21.610001, y: 23.33))
        shapePath3.addCurve(to: CGPoint(x: 20.52, y: 20.26), control1: CGPoint(x: 21.290001, y: 22.26), control2: CGPoint(x: 20.93, y: 21.26))
        shapePath3.addCurve(to: CGPoint(x: 18.41, y: 16.450001), control1: CGPoint(x: 19.959999, y: 18.916), control2: CGPoint(x: 19.253, y: 17.638))
        shapePath3.addCurve(to: CGPoint(x: 17.719999, y: 15.6), control1: CGPoint(x: 18.200001, y: 16.15), control2: CGPoint(x: 17.959999, y: 15.88))
        shapePath3.addCurve(to: CGPoint(x: 17.719999, y: 15.38), control1: CGPoint(x: 17.629999, y: 15.5), control2: CGPoint(x: 17.65, y: 15.46))
        shapePath3.addCurve(to: CGPoint(x: 20.190001, y: 9.8), control1: CGPoint(x: 19.392, y: 14.025), control2: CGPoint(x: 20.311001, y: 11.949))
        shapePath3.addCurve(to: CGPoint(x: 16.82, y: 4.07), control1: CGPoint(x: 20.205, y: 7.416), control2: CGPoint(x: 18.910999, y: 5.216))
        shapePath3.addCurve(to: CGPoint(x: 9.69, y: 5.35), control1: CGPoint(x: 14.437, y: 2.774), control2: CGPoint(x: 11.474, y: 3.306))
        shapePath3.addCurve(to: CGPoint(x: 10.18, y: 15.19), control1: CGPoint(x: 7.127, y: 8.209), control2: CGPoint(x: 7.346, y: 12.6))
        shapePath3.addCurve(to: CGPoint(x: 10.23, y: 15.76), control1: CGPoint(x: 10.48, y: 15.45), control2: CGPoint(x: 10.48, y: 15.45))
        shapePath3.addCurve(to: CGPoint(x: 8.47, y: 18.34), control1: CGPoint(x: 9.591, y: 16.582001), control2: CGPoint(x: 9.003, y: 17.444))
        shapePath3.addCurve(to: CGPoint(x: 7.84, y: 19.719999), control1: CGPoint(x: 8.234, y: 18.788), control2: CGPoint(x: 8.024, y: 19.247999))
        shapePath3.addCurve(to: CGPoint(x: 6.24, y: 24.26), control1: CGPoint(x: 7.205, y: 21.195999), control2: CGPoint(x: 6.671, y: 22.712))
        shapePath3.addLine(to: CGPoint(x: 6.18, y: 24.450001))
        shapePath3.addCurve(to: CGPoint(x: 1.743, y: 9.952), control1: CGPoint(x: 1.745, y: 21.069), control2: CGPoint(x: -0.041, y: 15.236))
        shapePath3.addCurve(to: CGPoint(x: 14.06, y: 1.11), control1: CGPoint(x: 3.528, y: 4.668), control2: CGPoint(x: 8.483, y: 1.11))
        shapePath3.addCurve(to: CGPoint(x: 26.377001, y: 9.952), control1: CGPoint(x: 19.638, y: 1.11), control2: CGPoint(x: 24.593, y: 4.668))
        shapePath3.addCurve(to: CGPoint(x: 21.940001, y: 24.450001), control1: CGPoint(x: 28.160999, y: 15.236), control2: CGPoint(x: 26.375999, y: 21.069))
        shapePath3.addLine(to: CGPoint(x: 21.940001, y: 24.440001))
        shapePath3.closeSubpath()
        shapePath3.move(to: CGPoint(x: 21.940001, y: 24.440001))

        let pathPath6 = CGMutablePath()
        pathPath6.move(to: CGPoint(x: 7.928, y: 14.613))
        pathPath6.addLine(to: CGPoint(x: 7.928, y: 14.613))
        pathPath6.addCurve(to: CGPoint(x: 3.001, y: 28.450001), control1: CGPoint(x: 8.046, y: 19.674), control2: CGPoint(x: 6.292, y: 24.601999))
        pathPath6.addLine(to: CGPoint(x: 3.001, y: 28.450001))
        pathPath6.addCurve(to: CGPoint(x: 1.801, y: 29.757), control1: CGPoint(x: 2.627, y: 28.908001), control2: CGPoint(x: 2.226, y: 29.344999))
        pathPath6.addCurve(to: CGPoint(x: 0.286, y: 29.921), control1: CGPoint(x: 1.266, y: 30.268999), control2: CGPoint(x: 0.693, y: 30.308001))
        pathPath6.addCurve(to: CGPoint(x: 0.476, y: 28.447001), control1: CGPoint(x: -0.145, y: 29.507999), control2: CGPoint(x: -0.093, y: 29.045))
        pathPath6.addLine(to: CGPoint(x: 0.476, y: 28.447001))
        pathPath6.addCurve(to: CGPoint(x: 0.729, y: 2.022), control1: CGPoint(x: 7.727, y: 21.171), control2: CGPoint(x: 7.84, y: 9.435))
        pathPath6.addCurve(to: CGPoint(x: 0.395, y: 1.679), control1: CGPoint(x: 0.621, y: 1.904), control2: CGPoint(x: 0.504, y: 1.796))
        pathPath6.addCurve(to: CGPoint(x: 0.269, y: 0.307), control1: CGPoint(x: -0.09, y: 1.158), control2: CGPoint(x: -0.13, y: 0.71))
        pathPath6.addLine(to: CGPoint(x: 0.269, y: 0.307))
        pathPath6.addCurve(to: CGPoint(x: 1.671, y: 0.276), control1: CGPoint(x: 0.648, y: -0.089), control2: CGPoint(x: 1.276, y: -0.103))
        pathPath6.addCurve(to: CGPoint(x: 1.779, y: 0.397), control1: CGPoint(x: 1.711, y: 0.313), control2: CGPoint(x: 1.746, y: 0.353))
        pathPath6.addLine(to: CGPoint(x: 1.779, y: 0.397))
        pathPath6.addCurve(to: CGPoint(x: 4.491, y: 3.797), control1: CGPoint(x: 2.753, y: 1.472), control2: CGPoint(x: 3.659, y: 2.608))
        pathPath6.addLine(to: CGPoint(x: 4.491, y: 3.797))
        pathPath6.addCurve(to: CGPoint(x: 7.928, y: 14.613), control1: CGPoint(x: 6.635, y: 7.005), control2: CGPoint(x: 7.827, y: 10.755))
        pathPath6.closeSubpath()
        pathPath6.move(to: CGPoint(x: 7.928, y: 14.613))

        let pathPath7 = CGMutablePath()
        pathPath7.move(to: CGPoint(x: 6.362, y: 11.393))
        pathPath7.addLine(to: CGPoint(x: 6.362, y: 11.393))
        pathPath7.addCurve(to: CGPoint(x: 2.1, y: 21.856001), control1: CGPoint(x: 6.295, y: 15.29), control2: CGPoint(x: 4.775, y: 19.021))
        pathPath7.addCurve(to: CGPoint(x: 1.716, y: 22.243), control1: CGPoint(x: 1.975, y: 21.989), control2: CGPoint(x: 1.851, y: 22.122))
        pathPath7.addLine(to: CGPoint(x: 1.716, y: 22.243))
        pathPath7.addCurve(to: CGPoint(x: 0.283, y: 22.358), control1: CGPoint(x: 1.352, y: 22.67), control2: CGPoint(x: 0.71, y: 22.722))
        pathPath7.addCurve(to: CGPoint(x: 0.253, y: 22.332001), control1: CGPoint(x: 0.273, y: 22.349001), control2: CGPoint(x: 0.263, y: 22.341))
        pathPath7.addCurve(to: CGPoint(x: 0.415, y: 20.893999), control1: CGPoint(x: -0.131, y: 21.957001), control2: CGPoint(x: -0.078, y: 21.399))
        pathPath7.addLine(to: CGPoint(x: 0.415, y: 20.893999))
        pathPath7.addCurve(to: CGPoint(x: 4.408, y: 11.423), control1: CGPoint(x: 2.962, y: 18.399), control2: CGPoint(x: 4.4, y: 14.987))
        pathPath7.addLine(to: CGPoint(x: 4.408, y: 11.423))
        pathPath7.addCurve(to: CGPoint(x: 0.624, y: 1.929), control1: CGPoint(x: 4.445, y: 7.884), control2: CGPoint(x: 3.086, y: 4.472))
        pathPath7.addCurve(to: CGPoint(x: 0.386, y: 1.686), control1: CGPoint(x: 0.547, y: 1.845), control2: CGPoint(x: 0.463, y: 1.768))
        pathPath7.addCurve(to: CGPoint(x: 0.235, y: 0.299), control1: CGPoint(x: -0.068, y: 1.204), control2: CGPoint(x: -0.124, y: 0.669))
        pathPath7.addLine(to: CGPoint(x: 0.235, y: 0.299))
        pathPath7.addCurve(to: CGPoint(x: 1.606, y: 0.271), control1: CGPoint(x: 0.606, y: -0.087), control2: CGPoint(x: 1.22, y: -0.1))
        pathPath7.addCurve(to: CGPoint(x: 1.689, y: 0.363), control1: CGPoint(x: 1.635, y: 0.3), control2: CGPoint(x: 1.663, y: 0.33))
        pathPath7.addLine(to: CGPoint(x: 1.689, y: 0.363))
        pathPath7.addCurve(to: CGPoint(x: 3.589, y: 2.585), control1: CGPoint(x: 2.376, y: 1.056), control2: CGPoint(x: 3.011, y: 1.798))
        pathPath7.addLine(to: CGPoint(x: 3.589, y: 2.585))
        pathPath7.addCurve(to: CGPoint(x: 6.362, y: 11.393), control1: CGPoint(x: 5.435, y: 5.147), control2: CGPoint(x: 6.408, y: 8.235))
        pathPath7.closeSubpath()
        pathPath7.move(to: CGPoint(x: 6.362, y: 11.393))

        let pathPath8 = CGMutablePath()
        pathPath8.move(to: CGPoint(x: 4.934, y: 7.856))
        pathPath8.addLine(to: CGPoint(x: 4.934, y: 7.856))
        pathPath8.addCurve(to: CGPoint(x: 1.866, y: 14.977), control1: CGPoint(x: 4.884, y: 10.54), control2: CGPoint(x: 3.783, y: 13.097))
        pathPath8.addCurve(to: CGPoint(x: 1.666, y: 15.164), control1: CGPoint(x: 1.802, y: 15.041), control2: CGPoint(x: 1.738, y: 15.105))
        pathPath8.addLine(to: CGPoint(x: 1.666, y: 15.164))
        pathPath8.addCurve(to: CGPoint(x: 0.311, y: 15.247), control1: CGPoint(x: 1.315, y: 15.561), control2: CGPoint(x: 0.708, y: 15.598))
        pathPath8.addCurve(to: CGPoint(x: 0.266, y: 15.205), control1: CGPoint(x: 0.296, y: 15.233), control2: CGPoint(x: 0.281, y: 15.219))
        pathPath8.addLine(to: CGPoint(x: 0.266, y: 15.205))
        pathPath8.addCurve(to: CGPoint(x: 0.291, y: 13.883), control1: CGPoint(x: -0.092, y: 14.833), control2: CGPoint(x: -0.081, y: 14.241))
        pathPath8.addCurve(to: CGPoint(x: 0.366, y: 13.818), control1: CGPoint(x: 0.315, y: 13.86), control2: CGPoint(x: 0.34, y: 13.838))
        pathPath8.addLine(to: CGPoint(x: 0.366, y: 13.818))
        pathPath8.addCurve(to: CGPoint(x: 0.679, y: 2.007), control1: CGPoint(x: 3.677, y: 10.626), control2: CGPoint(x: 3.817, y: 5.369))
        pathPath8.addCurve(to: CGPoint(x: 0.217, y: 1.507), control1: CGPoint(x: 0.528, y: 1.838), control2: CGPoint(x: 0.351, y: 1.689))
        pathPath8.addLine(to: CGPoint(x: 0.217, y: 1.507))
        pathPath8.addCurve(to: CGPoint(x: 0.349, y: 0.216), control1: CGPoint(x: -0.103, y: 1.114), control2: CGPoint(x: -0.044, y: 0.536))
        pathPath8.addCurve(to: CGPoint(x: 1.404, y: 0.144), control1: CGPoint(x: 0.65, y: -0.029), control2: CGPoint(x: 1.072, y: -0.058))
        pathPath8.addLine(to: CGPoint(x: 1.404, y: 0.144))
        pathPath8.addCurve(to: CGPoint(x: 2.022, y: 0.672), control1: CGPoint(x: 1.63, y: 0.295), control2: CGPoint(x: 1.838, y: 0.472))
        pathPath8.addLine(to: CGPoint(x: 2.022, y: 0.672))
        pathPath8.addCurve(to: CGPoint(x: 4.934, y: 7.856), control1: CGPoint(x: 3.898, y: 2.592), control2: CGPoint(x: 4.943, y: 5.172))
        pathPath8.closeSubpath()
        pathPath8.move(to: CGPoint(x: 4.934, y: 7.856))

        let pathPath9 = CGMutablePath()
        pathPath9.move(to: CGPoint(x: 3.7, y: 4.748))
        pathPath9.addLine(to: CGPoint(x: 3.7, y: 4.748))
        pathPath9.addCurve(to: CGPoint(x: 1.79, y: 8.611), control1: CGPoint(x: 3.667, y: 6.255), control2: CGPoint(x: 2.967, y: 7.669))
        pathPath9.addLine(to: CGPoint(x: 1.79, y: 8.611))
        pathPath9.addCurve(to: CGPoint(x: 0.677, y: 8.926), control1: CGPoint(x: 1.475, y: 8.858), control2: CGPoint(x: 1.075, y: 8.971))
        pathPath9.addCurve(to: CGPoint(x: 0.362, y: 7.403), control1: CGPoint(x: -0.072, y: 8.798), control2: CGPoint(x: -0.231, y: 7.977))
        pathPath9.addLine(to: CGPoint(x: 0.362, y: 7.403))
        pathPath9.addCurve(to: CGPoint(x: 1.662, y: 5.391), control1: CGPoint(x: 0.992, y: 6.882), control2: CGPoint(x: 1.446, y: 6.179))
        pathPath9.addLine(to: CGPoint(x: 1.662, y: 5.391))
        pathPath9.addCurve(to: CGPoint(x: 0.798, y: 2.105), control1: CGPoint(x: 1.916, y: 4.221), control2: CGPoint(x: 1.595, y: 2.999))
        pathPath9.addCurve(to: CGPoint(x: 0.426, y: 1.705), control1: CGPoint(x: 0.687, y: 1.962), control2: CGPoint(x: 0.544, y: 1.846))
        pathPath9.addCurve(to: CGPoint(x: 0.308, y: 0.259), control1: CGPoint(x: -0.061, y: 1.136), control2: CGPoint(x: -0.097, y: 0.662))
        pathPath9.addLine(to: CGPoint(x: 0.308, y: 0.259))
        pathPath9.addCurve(to: CGPoint(x: 1.773, y: 0.358), control1: CGPoint(x: 0.74, y: -0.118), control2: CGPoint(x: 1.396, y: -0.074))
        pathPath9.addCurve(to: CGPoint(x: 1.774, y: 0.359), control1: CGPoint(x: 1.773, y: 0.358), control2: CGPoint(x: 1.774, y: 0.359))
        pathPath9.addLine(to: CGPoint(x: 1.774, y: 0.359))
        pathPath9.addCurve(to: CGPoint(x: 3.7, y: 4.748), control1: CGPoint(x: 3.02, y: 1.475), control2: CGPoint(x: 3.722, y: 3.076))
        pathPath9.closeSubpath()
        pathPath9.move(to: CGPoint(x: 3.7, y: 4.748))

        // eCard
        //
        let eCardLayer = CALayer()
        eCardLayer.name = "eCard"
        eCardLayer.bounds = CGRect(x: 0, y: 0, width: 135.7, height: 89.82)
        eCardLayer.position = CGPoint(x: 49, y: 46)
        eCardLayer.anchorPoint = CGPoint(x: 0, y: 0)
        eCardLayer.contentsGravity = .center
        eCardLayer.contentsScale = 2
        eCardLayer.allowsEdgeAntialiasing = true
        eCardLayer.allowsGroupOpacity = true

            // eCard Animations
            //

            // opacity
            //
            let opacityAnimation = CAKeyframeAnimation()
            opacityAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            opacityAnimation.duration = 6
            opacityAnimation.repeatCount = 100
            opacityAnimation.fillMode = .backwards
            opacityAnimation.isRemovedOnCompletion = false
            opacityAnimation.keyPath = "opacity"
            opacityAnimation.values = [ 1, 1 ]
            opacityAnimation.calculationMode = .linear

            eCardLayer.add(opacityAnimation, forKey: "opacityAnimation")

            // eCard Sublayers
            //

            // eCardSVG_ok
            //
            let eCardSVGOkLayer = CALayer()
            eCardSVGOkLayer.name = "eCardSVG_ok"
            eCardSVGOkLayer.bounds = CGRect(x: 0, y: 0, width: 138.7, height: 85)
            eCardSVGOkLayer.position = CGPoint(x: -0, y: 2)
            eCardSVGOkLayer.anchorPoint = CGPoint(x: 0, y: 0)
            eCardSVGOkLayer.contentsGravity = .center
            eCardSVGOkLayer.contentsScale = 2
            eCardSVGOkLayer.allowsEdgeAntialiasing = true
            eCardSVGOkLayer.allowsGroupOpacity = true
            eCardSVGOkLayer.transform = CATransform3D( m11: 1.1, m12: -0, m13: -0, m14: -0,
                                                   m21: 0, m22: 1.1, m23: -0, m24: -0,
                                                   m31: 0, m32: 0, m33: -1, m34: -0,
                                                   m41: 0, m42: 0, m43: 0, m44: 1 )

                // eCardSVG_ok Sublayers
                //

                // Rectangle
                //
                let rectangleLayer = CAShapeLayer()
                rectangleLayer.name = "Rectangle"
                rectangleLayer.bounds = CGRect(x: 0, y: 0, width: 74.82, height: 118.7)
                rectangleLayer.position = CGPoint(x: 61.35, y: 37.41)
                rectangleLayer.contentsGravity = .center
                rectangleLayer.contentsScale = 2
                rectangleLayer.allowsEdgeAntialiasing = true
                rectangleLayer.allowsGroupOpacity = true
                rectangleLayer.transform = CATransform3D( m11: 0, m12: 1, m13: 0, m14: 0,
                                                  m21: -1, m22: 0, m23: 0, m24: 0,
                                                  m31: 0, m32: 0, m33: 1, m34: 0,
                                                  m41: 0, m42: 0, m43: 0, m44: 1 )
                rectangleLayer.path = rectanglePath
                rectangleLayer.fillColor = fillColor.cgColor
                rectangleLayer.strokeColor = strokeColor.cgColor
                rectangleLayer.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer)

                // Path
                //
                let pathLayer = CAShapeLayer()
                pathLayer.name = "Path"
                pathLayer.bounds = CGRect(x: 0, y: 0, width: 107.45, height: 1)
                pathLayer.position = CGPoint(x: 5.97, y: 20.41)
                pathLayer.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer.contentsGravity = .center
                pathLayer.contentsScale = 2
                pathLayer.allowsEdgeAntialiasing = true
                pathLayer.allowsGroupOpacity = true
                pathLayer.path = pathPath
                pathLayer.fillColor = strokeColor.cgColor
                pathLayer.strokeColor = strokeColor1.cgColor
                pathLayer.fillRule = .evenOdd
                pathLayer.lineCap = .round
                pathLayer.lineWidth = 0.5

                eCardSVGOkLayer.addSublayer(pathLayer)

                // Rectangle
                //
                let rectangleLayer1 = CAShapeLayer()
                rectangleLayer1.name = "Rectangle"
                rectangleLayer1.bounds = CGRect(x: 0, y: 0, width: 20.25, height: 3.4)
                rectangleLayer1.position = CGPoint(x: 46.21, y: 61.96)
                rectangleLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer1.contentsGravity = .center
                rectangleLayer1.contentsScale = 2
                rectangleLayer1.allowsEdgeAntialiasing = true
                rectangleLayer1.allowsGroupOpacity = true
                rectangleLayer1.path = rectanglePath1
                rectangleLayer1.fillColor = strokeColor1.cgColor
                rectangleLayer1.strokeColor = strokeColor.cgColor
                rectangleLayer1.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer1)

                // Rectangle
                //
                let rectangleLayer2 = CAShapeLayer()
                rectangleLayer2.name = "Rectangle"
                rectangleLayer2.bounds = CGRect(x: 0, y: 0, width: 11.96, height: 3.4)
                rectangleLayer2.position = CGPoint(x: 96.09, y: 42.17)
                rectangleLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer2.contentsGravity = .center
                rectangleLayer2.contentsScale = 2
                rectangleLayer2.allowsEdgeAntialiasing = true
                rectangleLayer2.allowsGroupOpacity = true
                rectangleLayer2.path = rectanglePath2
                rectangleLayer2.fillColor = strokeColor1.cgColor
                rectangleLayer2.strokeColor = strokeColor.cgColor
                rectangleLayer2.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer2)

                // Rectangle
                //
                let rectangleLayer3 = CAShapeLayer()
                rectangleLayer3.name = "Rectangle"
                rectangleLayer3.bounds = CGRect(x: 0, y: 0, width: 11.96, height: 3.4)
                rectangleLayer3.position = CGPoint(x: 96.09, y: 32.27)
                rectangleLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer3.contentsGravity = .center
                rectangleLayer3.contentsScale = 2
                rectangleLayer3.allowsEdgeAntialiasing = true
                rectangleLayer3.allowsGroupOpacity = true
                rectangleLayer3.path = rectanglePath3
                rectangleLayer3.fillColor = strokeColor1.cgColor
                rectangleLayer3.strokeColor = strokeColor.cgColor
                rectangleLayer3.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer3)

                // Rectangle
                //
                let rectangleLayer4 = CAShapeLayer()
                rectangleLayer4.name = "Rectangle"
                rectangleLayer4.bounds = CGRect(x: 0, y: 0, width: 37.84, height: 3.4)
                rectangleLayer4.position = CGPoint(x: 46.21, y: 52.06)
                rectangleLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer4.contentsGravity = .center
                rectangleLayer4.contentsScale = 2
                rectangleLayer4.allowsEdgeAntialiasing = true
                rectangleLayer4.allowsGroupOpacity = true
                rectangleLayer4.path = rectanglePath4
                rectangleLayer4.fillColor = strokeColor1.cgColor
                rectangleLayer4.strokeColor = strokeColor.cgColor
                rectangleLayer4.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer4)

                // Rectangle
                //
                let rectangleLayer5 = CAShapeLayer()
                rectangleLayer5.name = "Rectangle"
                rectangleLayer5.bounds = CGRect(x: 0, y: 0, width: 37.84, height: 3.4)
                rectangleLayer5.position = CGPoint(x: 46.21, y: 42.17)
                rectangleLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer5.contentsGravity = .center
                rectangleLayer5.contentsScale = 2
                rectangleLayer5.allowsEdgeAntialiasing = true
                rectangleLayer5.allowsGroupOpacity = true
                rectangleLayer5.path = rectanglePath5
                rectangleLayer5.fillColor = strokeColor1.cgColor
                rectangleLayer5.strokeColor = strokeColor.cgColor
                rectangleLayer5.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer5)

                // Rectangle
                //
                let rectangleLayer6 = CAShapeLayer()
                rectangleLayer6.name = "Rectangle"
                rectangleLayer6.bounds = CGRect(x: 0, y: 0, width: 37.84, height: 3.4)
                rectangleLayer6.position = CGPoint(x: 46.21, y: 32.27)
                rectangleLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer6.contentsGravity = .center
                rectangleLayer6.contentsScale = 2
                rectangleLayer6.allowsEdgeAntialiasing = true
                rectangleLayer6.allowsGroupOpacity = true
                rectangleLayer6.path = rectanglePath6
                rectangleLayer6.fillColor = strokeColor1.cgColor
                rectangleLayer6.strokeColor = strokeColor.cgColor
                rectangleLayer6.lineWidth = 0

                eCardSVGOkLayer.addSublayer(rectangleLayer6)

                // Path
                //
                let pathLayer1 = CAShapeLayer()
                pathLayer1.name = "Path"
                pathLayer1.bounds = CGRect(x: 0, y: 0, width: 3.091224, height: 3.453342)
                pathLayer1.position = CGPoint(x: 5.459446, y: 11.579369)
                pathLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer1.contentsGravity = .center
                pathLayer1.contentsScale = 2
                pathLayer1.allowsEdgeAntialiasing = true
                pathLayer1.allowsGroupOpacity = true
                pathLayer1.path = pathPath1
                pathLayer1.fillColor = strokeColor1.cgColor
                pathLayer1.strokeColor = strokeColor.cgColor
                pathLayer1.lineWidth = 0

                eCardSVGOkLayer.addSublayer(pathLayer1)

                // Path
                //
                let pathLayer2 = CAShapeLayer()
                pathLayer2.name = "Path"
                pathLayer2.bounds = CGRect(x: 0, y: 0, width: 4.081744, height: 4.665142)
                pathLayer2.position = CGPoint(x: 8.998256, y: 10.369182)
                pathLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer2.contentsGravity = .center
                pathLayer2.contentsScale = 2
                pathLayer2.allowsEdgeAntialiasing = true
                pathLayer2.allowsGroupOpacity = true
                pathLayer2.path = pathPath2
                pathLayer2.fillColor = strokeColor1.cgColor
                pathLayer2.strokeColor = strokeColor.cgColor
                pathLayer2.lineWidth = 0

                eCardSVGOkLayer.addSublayer(pathLayer2)

                // Shape
                //
                let shapeLayer = CAShapeLayer()
                shapeLayer.name = "Shape"
                shapeLayer.bounds = CGRect(x: 0, y: 0, width: 4.16, height: 4.55)
                shapeLayer.position = CGPoint(x: 13.28, y: 10.45)
                shapeLayer.anchorPoint = CGPoint(x: 0, y: 0)
                shapeLayer.contentsGravity = .center
                shapeLayer.contentsScale = 2
                shapeLayer.allowsEdgeAntialiasing = true
                shapeLayer.allowsGroupOpacity = true
                shapeLayer.path = shapePath
                shapeLayer.fillColor = strokeColor1.cgColor
                shapeLayer.strokeColor = strokeColor.cgColor
                shapeLayer.lineWidth = 0

                eCardSVGOkLayer.addSublayer(shapeLayer)

                // Shape
                //
                let shapeLayer1 = CAShapeLayer()
                shapeLayer1.name = "Shape"
                shapeLayer1.bounds = CGRect(x: 0, y: 0, width: 3.52, height: 4.551303)
                shapeLayer1.position = CGPoint(x: 17.93, y: 10.448697)
                shapeLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                shapeLayer1.contentsGravity = .center
                shapeLayer1.contentsScale = 2
                shapeLayer1.allowsEdgeAntialiasing = true
                shapeLayer1.allowsGroupOpacity = true
                shapeLayer1.path = shapePath1
                shapeLayer1.fillColor = strokeColor1.cgColor
                shapeLayer1.strokeColor = strokeColor.cgColor
                shapeLayer1.lineWidth = 0

                eCardSVGOkLayer.addSublayer(shapeLayer1)

                // Shape
                //
                let shapeLayer2 = CAShapeLayer()
                shapeLayer2.name = "Shape"
                shapeLayer2.bounds = CGRect(x: 0, y: 0, width: 3.830843, height: 4.532504)
                shapeLayer2.position = CGPoint(x: 22, y: 10.448455)
                shapeLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                shapeLayer2.contentsGravity = .center
                shapeLayer2.contentsScale = 2
                shapeLayer2.allowsEdgeAntialiasing = true
                shapeLayer2.allowsGroupOpacity = true
                shapeLayer2.path = shapePath2
                shapeLayer2.fillColor = strokeColor1.cgColor
                shapeLayer2.strokeColor = strokeColor.cgColor
                shapeLayer2.lineWidth = 0

                eCardSVGOkLayer.addSublayer(shapeLayer2)

                // Path
                //
                let pathLayer3 = CAShapeLayer()
                pathLayer3.name = "Path"
                pathLayer3.bounds = CGRect(x: 0, y: 0, width: 9.01, height: 2.39)
                pathLayer3.position = CGPoint(x: 28.31, y: 9.83)
                pathLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer3.contentsGravity = .center
                pathLayer3.contentsScale = 2
                pathLayer3.allowsEdgeAntialiasing = true
                pathLayer3.allowsGroupOpacity = true
                pathLayer3.path = pathPath3
                pathLayer3.fillColor = strokeColor1.cgColor
                pathLayer3.strokeColor = strokeColor.cgColor
                pathLayer3.lineWidth = 0

                eCardSVGOkLayer.addSublayer(pathLayer3)

                // Path
                //
                let pathLayer4 = CAShapeLayer()
                pathLayer4.name = "Path"
                pathLayer4.bounds = CGRect(x: 0, y: 0, width: 9.01, height: 2.381071)
                pathLayer4.position = CGPoint(x: 28.31, y: 12.908929)
                pathLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer4.contentsGravity = .center
                pathLayer4.contentsScale = 2
                pathLayer4.allowsEdgeAntialiasing = true
                pathLayer4.allowsGroupOpacity = true
                pathLayer4.path = pathPath4
                pathLayer4.fillColor = strokeColor1.cgColor
                pathLayer4.strokeColor = strokeColor.cgColor
                pathLayer4.lineWidth = 0

                eCardSVGOkLayer.addSublayer(pathLayer4)

                // Path
                //
                let pathLayer5 = CAShapeLayer()
                pathLayer5.name = "Path"
                pathLayer5.bounds = CGRect(x: 0, y: 0, width: 2.54012, height: 2.540041)
                pathLayer5.position = CGPoint(x: 31.54984, y: 11.3)
                pathLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer5.contentsGravity = .center
                pathLayer5.contentsScale = 2
                pathLayer5.allowsEdgeAntialiasing = true
                pathLayer5.allowsGroupOpacity = true
                pathLayer5.path = pathPath5
                pathLayer5.fillColor = strokeColor1.cgColor
                pathLayer5.strokeColor = strokeColor.cgColor
                pathLayer5.lineWidth = 0

                eCardSVGOkLayer.addSublayer(pathLayer5)

                // Shape
                //
                let shapeLayer3 = CAShapeLayer()
                shapeLayer3.name = "Shape"
                shapeLayer3.bounds = CGRect(x: 0, y: 0, width: 28.160415, height: 28.160415)
                shapeLayer3.position = CGPoint(x: 7.309592, y: 34.739993)
                shapeLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                shapeLayer3.contentsGravity = .center
                shapeLayer3.contentsScale = 2
                shapeLayer3.allowsEdgeAntialiasing = true
                shapeLayer3.allowsGroupOpacity = true
                shapeLayer3.path = shapePath3
                shapeLayer3.fillColor = fillColor1.cgColor
                shapeLayer3.strokeColor = strokeColor.cgColor
                shapeLayer3.lineWidth = 0

                eCardSVGOkLayer.addSublayer(shapeLayer3)

            eCardLayer.addSublayer(eCardSVGOkLayer)

        self.layer.addSublayer(eCardLayer)

        // Device
        //
        let deviceLayer = CALayer()
        deviceLayer.name = "Device"
        deviceLayer.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
        deviceLayer.position = CGPoint(x: 157, y: 20)
        deviceLayer.anchorPoint = CGPoint(x: 0, y: 0)
        deviceLayer.contentsGravity = .center
        deviceLayer.shadowOffset = CGSize(width: 0, height: 1)
        deviceLayer.allowsEdgeAntialiasing = true
        deviceLayer.allowsGroupOpacity = true
        deviceLayer.fillMode = .forwards

            // Device Animations
            //

            // opacity
            //
            let opacityAnimation1 = CAKeyframeAnimation()
            opacityAnimation1.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            opacityAnimation1.duration = 5.999999
            opacityAnimation1.repeatCount = 100
            opacityAnimation1.fillMode = .backwards
            opacityAnimation1.isRemovedOnCompletion = false
            opacityAnimation1.keyPath = "opacity"
            opacityAnimation1.values = [ 1, 1 ]
            opacityAnimation1.calculationMode = .linear

            deviceLayer.add(opacityAnimation1, forKey: "opacityAnimation1")

            // Device Sublayers
            //

            // Group 14
            //
            let groupLayer = CALayer()
            groupLayer.name = "Group 14"
            groupLayer.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
            groupLayer.position = CGPoint(x: -80, y: -5)
            groupLayer.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer.contentsGravity = .center
            groupLayer.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer.allowsEdgeAntialiasing = true
            groupLayer.allowsGroupOpacity = true
            groupLayer.fillMode = .forwards
            groupLayer.transform = CATransform3D( m11: 0.95, m12: 0, m13: 0, m14: 0,
                                              m21: 0, m22: 0.95, m23: 0, m24: 0,
                                              m31: 0, m32: 0, m33: 1, m34: 0,
                                              m41: 0, m42: 0, m43: 0, m44: 1 )

                // Group 14 Sublayers
                //

                // Rectangle 6
                //
                let rectangleLayer7 = CALayer()
                rectangleLayer7.name = "Rectangle 6"
                rectangleLayer7.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 114.601166)
                rectangleLayer7.position = CGPoint(x: 0, y: 19.14679)
                rectangleLayer7.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer7.contentsGravity = .center
                rectangleLayer7.backgroundColor = backgroundColor.cgColor
                rectangleLayer7.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer7.allowsEdgeAntialiasing = true
                rectangleLayer7.allowsGroupOpacity = true
                rectangleLayer7.fillMode = .forwards

                groupLayer.addSublayer(rectangleLayer7)

                // Rectangle 7
                //
                let rectangleLayer8 = CALayer()
                rectangleLayer8.name = "Rectangle 7"
                rectangleLayer8.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 24.433228)
                rectangleLayer8.position = CGPoint(x: 0, y: 133.461273)
                rectangleLayer8.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer8.contentsGravity = .center
                rectangleLayer8.backgroundColor = backgroundColor1.cgColor
                rectangleLayer8.cornerRadius = 5
                if #available(iOS 11.0, *) {
                    rectangleLayer8.maskedCorners = CACornerMask([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
                }
                else {
                    // Fallback on earlier versions
                }
                rectangleLayer8.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer8.allowsEdgeAntialiasing = true
                rectangleLayer8.allowsGroupOpacity = true
                rectangleLayer8.fillMode = .forwards

                groupLayer.addSublayer(rectangleLayer8)

                // Rectangle 8
                //
                let rectangleLayer9 = CALayer()
                rectangleLayer9.name = "Rectangle 8"
                rectangleLayer9.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 19.348602)
                rectangleLayer9.position = CGPoint(x: 91, y: 20)
                rectangleLayer9.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer9.contentsGravity = .center
                rectangleLayer9.backgroundColor = backgroundColor1.cgColor
                rectangleLayer9.cornerRadius = 5
                if #available(iOS 11.0, *) {
                    rectangleLayer9.maskedCorners = CACornerMask([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
                }
                else {
                    // Fallback on earlier versions
                }
                rectangleLayer9.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer9.allowsEdgeAntialiasing = true
                rectangleLayer9.allowsGroupOpacity = true
                rectangleLayer9.fillMode = .forwards
                rectangleLayer9.transform = CATransform3D( m11: -1, m12: 0, m13: 0, m14: 0,
                                                   m21: 0, m22: -1, m23: 0, m24: 0,
                                                   m31: 0, m32: 0, m33: 1, m34: 0,
                                                   m41: 0, m42: 0, m43: 0, m44: 1 )

                groupLayer.addSublayer(rectangleLayer9)

                // Rectangle 9
                //
                let rectangleLayer10 = CALayer()
                rectangleLayer10.name = "Rectangle 9"
                rectangleLayer10.bounds = CGRect(x: 0, y: 0, width: 21.381104, height: 7.996185)
                rectangleLayer10.position = CGPoint(x: 34.726318, y: 5.67627)
                rectangleLayer10.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer10.contentsGravity = .center
                rectangleLayer10.backgroundColor = backgroundColor2.cgColor
                rectangleLayer10.cornerRadius = 2.438305
                rectangleLayer10.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer10.allowsEdgeAntialiasing = true
                rectangleLayer10.allowsGroupOpacity = true
                rectangleLayer10.fillMode = .forwards

                groupLayer.addSublayer(rectangleLayer10)

                // Group 13
                //
                let groupLayer1 = CALayer()
                groupLayer1.name = "Group 13"
                groupLayer1.bounds = CGRect(x: 0, y: 0, width: 20.375, height: 30.180573)
                groupLayer1.position = CGPoint(x: 35.229736, y: 61.356964)
                groupLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer1.contentsGravity = .center
                groupLayer1.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer1.allowsEdgeAntialiasing = true
                groupLayer1.allowsGroupOpacity = true
                groupLayer1.fillMode = .forwards

                    // Group 13 Sublayers
                    //

                    // Path 9
                    //
                    let pathLayer6 = CAShapeLayer()
                    pathLayer6.name = "Path 9"
                    pathLayer6.bounds = CGRect(x: 0, y: 0, width: 7.93103, height: 30.180573)
                    pathLayer6.position = CGPoint(x: 12.44397, y: 0)
                    pathLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer6.contentsGravity = .center
                    pathLayer6.backgroundColor = strokeColor.cgColor
                    pathLayer6.borderColor = strokeColor.cgColor
                    pathLayer6.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer6.allowsEdgeAntialiasing = true
                    pathLayer6.allowsGroupOpacity = true
                    pathLayer6.fillMode = .forwards
                    pathLayer6.path = pathPath6
                    pathLayer6.fillColor = fillColor2.cgColor
                    pathLayer6.strokeColor = strokeColor2.cgColor
                    pathLayer6.lineWidth = 0

                    groupLayer1.addSublayer(pathLayer6)

                    // Path 10
                    //
                    let pathLayer7 = CAShapeLayer()
                    pathLayer7.name = "Path 10"
                    pathLayer7.bounds = CGRect(x: 0, y: 0, width: 6.364502, height: 22.60144)
                    pathLayer7.position = CGPoint(x: 8.136963, y: 3.797516)
                    pathLayer7.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer7.contentsGravity = .center
                    pathLayer7.backgroundColor = strokeColor.cgColor
                    pathLayer7.borderColor = strokeColor.cgColor
                    pathLayer7.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer7.allowsEdgeAntialiasing = true
                    pathLayer7.allowsGroupOpacity = true
                    pathLayer7.fillMode = .forwards
                    pathLayer7.path = pathPath7
                    pathLayer7.fillColor = fillColor2.cgColor
                    pathLayer7.strokeColor = strokeColor2.cgColor
                    pathLayer7.lineWidth = 0

                    groupLayer1.addSublayer(pathLayer7)

                    // Path 11
                    //
                    let pathLayer8 = CAShapeLayer()
                    pathLayer8.name = "Path 11"
                    pathLayer8.bounds = CGRect(x: 0, y: 0, width: 4.938965, height: 15.498047)
                    pathLayer8.position = CGPoint(x: 3.893433, y: 7.349426)
                    pathLayer8.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer8.contentsGravity = .center
                    pathLayer8.backgroundColor = strokeColor.cgColor
                    pathLayer8.borderColor = strokeColor.cgColor
                    pathLayer8.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer8.allowsEdgeAntialiasing = true
                    pathLayer8.allowsGroupOpacity = true
                    pathLayer8.fillMode = .forwards
                    pathLayer8.path = pathPath8
                    pathLayer8.fillColor = fillColor2.cgColor
                    pathLayer8.strokeColor = strokeColor2.cgColor
                    pathLayer8.lineWidth = 0

                    groupLayer1.addSublayer(pathLayer8)

                    // Path 12
                    //
                    let pathLayer9 = CAShapeLayer()
                    pathLayer9.name = "Path 12"
                    pathLayer9.bounds = CGRect(x: 0, y: 0, width: 3.70166, height: 8.938507)
                    pathLayer9.position = CGPoint(x: -0.000122, y: 10.596069)
                    pathLayer9.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer9.contentsGravity = .center
                    pathLayer9.backgroundColor = strokeColor.cgColor
                    pathLayer9.borderColor = strokeColor.cgColor
                    pathLayer9.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer9.allowsEdgeAntialiasing = true
                    pathLayer9.allowsGroupOpacity = true
                    pathLayer9.fillMode = .forwards
                    pathLayer9.path = pathPath9
                    pathLayer9.fillColor = fillColor2.cgColor
                    pathLayer9.strokeColor = strokeColor2.cgColor
                    pathLayer9.lineWidth = 0

                    groupLayer1.addSublayer(pathLayer9)

                groupLayer.addSublayer(groupLayer1)

            deviceLayer.addSublayer(groupLayer)

        self.layer.addSublayer(deviceLayer)

    }

    // MARK: - Responder

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let location = touches.first?.location(in: self.superview),
              let hitLayer = self.layer.presentation()?.hitTest(location) else { return }

        print("Layer \(hitLayer.name ?? String(describing: hitLayer)) was tapped.")
    }
}
