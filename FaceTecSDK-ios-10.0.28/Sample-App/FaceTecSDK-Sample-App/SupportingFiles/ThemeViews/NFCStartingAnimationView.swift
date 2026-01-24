
import UIKit

class NFCStartingAnimationView: UIView
{

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
        let backgroundColor = UIColor(red: 0.964706, green: 0.94902, blue: 0.909804, alpha: 1)
        let backgroundColor1 = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let strokeColor = UIColor(red: 0.419608, green: 0.419608, blue: 0.419608, alpha: 1)
        let borderColor = UIColor(red: 0.795254, green: 0.795254, blue: 0.795254, alpha: 1)
        let fillColor = UIColor(red: 0.109806, green: 0.113802, blue: 0.109804, alpha: 1)
        let strokeColor1 = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let backgroundColor2 = UIColor(red: 0.160784, green: 0.498039, blue: 0.713725, alpha: 1)
        let backgroundColor3 = UIColor(red: 0.65098, green: 0.698039, blue: 0.709804, alpha: 1)
        let fillColor1 = UIColor.white
        let strokeColor2 = UIColor.black

        // Paths
        //
        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 0, y: 0))
        linePath.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath1 = CGMutablePath()
        linePath1.move(to: CGPoint(x: 0, y: 0))
        linePath1.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath2 = CGMutablePath()
        linePath2.move(to: CGPoint(x: 0, y: 0))
        linePath2.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath3 = CGMutablePath()
        linePath3.move(to: CGPoint(x: 0, y: 0))
        linePath3.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath4 = CGMutablePath()
        linePath4.move(to: CGPoint(x: 0, y: 0))
        linePath4.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath5 = CGMutablePath()
        linePath5.move(to: CGPoint(x: 0, y: 0))
        linePath5.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath6 = CGMutablePath()
        linePath6.move(to: CGPoint(x: 0, y: 0))
        linePath6.addLine(to: CGPoint(x: 60.944, y: 0))

        let linePath7 = CGMutablePath()
        linePath7.move(to: CGPoint(x: 0, y: 0))
        linePath7.addLine(to: CGPoint(x: 60.944, y: 0))

        let middleLinePath = CGMutablePath()
        middleLinePath.move(to: CGPoint(x: 0, y: 0))
        middleLinePath.addLine(to: CGPoint(x: 0, y: 130))

        let pathPath = CGMutablePath()
        pathPath.move(to: CGPoint(x: 7.928, y: 14.613))
        pathPath.addLine(to: CGPoint(x: 7.928, y: 14.613))
        pathPath.addCurve(to: CGPoint(x: 3.001, y: 28.450001), control1: CGPoint(x: 8.046, y: 19.674), control2: CGPoint(x: 6.292, y: 24.601999))
        pathPath.addLine(to: CGPoint(x: 3.001, y: 28.450001))
        pathPath.addCurve(to: CGPoint(x: 1.801, y: 29.757), control1: CGPoint(x: 2.627, y: 28.908001), control2: CGPoint(x: 2.226, y: 29.344999))
        pathPath.addCurve(to: CGPoint(x: 0.286, y: 29.921), control1: CGPoint(x: 1.266, y: 30.268999), control2: CGPoint(x: 0.693, y: 30.308001))
        pathPath.addCurve(to: CGPoint(x: 0.476, y: 28.447001), control1: CGPoint(x: -0.145, y: 29.507999), control2: CGPoint(x: -0.093, y: 29.045))
        pathPath.addLine(to: CGPoint(x: 0.476, y: 28.447001))
        pathPath.addCurve(to: CGPoint(x: 0.729, y: 2.022), control1: CGPoint(x: 7.727, y: 21.171), control2: CGPoint(x: 7.84, y: 9.435))
        pathPath.addCurve(to: CGPoint(x: 0.395, y: 1.679), control1: CGPoint(x: 0.621, y: 1.904), control2: CGPoint(x: 0.504, y: 1.796))
        pathPath.addCurve(to: CGPoint(x: 0.269, y: 0.307), control1: CGPoint(x: -0.09, y: 1.158), control2: CGPoint(x: -0.13, y: 0.71))
        pathPath.addLine(to: CGPoint(x: 0.269, y: 0.307))
        pathPath.addCurve(to: CGPoint(x: 1.671, y: 0.276), control1: CGPoint(x: 0.648, y: -0.089), control2: CGPoint(x: 1.276, y: -0.103))
        pathPath.addCurve(to: CGPoint(x: 1.779, y: 0.397), control1: CGPoint(x: 1.711, y: 0.313), control2: CGPoint(x: 1.746, y: 0.353))
        pathPath.addLine(to: CGPoint(x: 1.779, y: 0.397))
        pathPath.addCurve(to: CGPoint(x: 4.491, y: 3.797), control1: CGPoint(x: 2.753, y: 1.472), control2: CGPoint(x: 3.659, y: 2.608))
        pathPath.addLine(to: CGPoint(x: 4.491, y: 3.797))
        pathPath.addCurve(to: CGPoint(x: 7.928, y: 14.613), control1: CGPoint(x: 6.635, y: 7.005), control2: CGPoint(x: 7.827, y: 10.755))
        pathPath.closeSubpath()
        pathPath.move(to: CGPoint(x: 7.928, y: 14.613))

        let pathPath1 = CGMutablePath()
        pathPath1.move(to: CGPoint(x: 6.362, y: 11.393))
        pathPath1.addLine(to: CGPoint(x: 6.362, y: 11.393))
        pathPath1.addCurve(to: CGPoint(x: 2.1, y: 21.856001), control1: CGPoint(x: 6.295, y: 15.29), control2: CGPoint(x: 4.775, y: 19.021))
        pathPath1.addCurve(to: CGPoint(x: 1.716, y: 22.243), control1: CGPoint(x: 1.975, y: 21.989), control2: CGPoint(x: 1.851, y: 22.122))
        pathPath1.addLine(to: CGPoint(x: 1.716, y: 22.243))
        pathPath1.addCurve(to: CGPoint(x: 0.283, y: 22.358), control1: CGPoint(x: 1.352, y: 22.67), control2: CGPoint(x: 0.71, y: 22.722))
        pathPath1.addCurve(to: CGPoint(x: 0.253, y: 22.332001), control1: CGPoint(x: 0.273, y: 22.349001), control2: CGPoint(x: 0.263, y: 22.341))
        pathPath1.addCurve(to: CGPoint(x: 0.415, y: 20.893999), control1: CGPoint(x: -0.131, y: 21.957001), control2: CGPoint(x: -0.078, y: 21.399))
        pathPath1.addLine(to: CGPoint(x: 0.415, y: 20.893999))
        pathPath1.addCurve(to: CGPoint(x: 4.408, y: 11.423), control1: CGPoint(x: 2.962, y: 18.399), control2: CGPoint(x: 4.4, y: 14.987))
        pathPath1.addLine(to: CGPoint(x: 4.408, y: 11.423))
        pathPath1.addCurve(to: CGPoint(x: 0.624, y: 1.929), control1: CGPoint(x: 4.445, y: 7.884), control2: CGPoint(x: 3.086, y: 4.472))
        pathPath1.addCurve(to: CGPoint(x: 0.386, y: 1.686), control1: CGPoint(x: 0.547, y: 1.845), control2: CGPoint(x: 0.463, y: 1.768))
        pathPath1.addCurve(to: CGPoint(x: 0.235, y: 0.299), control1: CGPoint(x: -0.068, y: 1.204), control2: CGPoint(x: -0.124, y: 0.669))
        pathPath1.addLine(to: CGPoint(x: 0.235, y: 0.299))
        pathPath1.addCurve(to: CGPoint(x: 1.606, y: 0.271), control1: CGPoint(x: 0.606, y: -0.087), control2: CGPoint(x: 1.22, y: -0.1))
        pathPath1.addCurve(to: CGPoint(x: 1.689, y: 0.363), control1: CGPoint(x: 1.635, y: 0.3), control2: CGPoint(x: 1.663, y: 0.33))
        pathPath1.addLine(to: CGPoint(x: 1.689, y: 0.363))
        pathPath1.addCurve(to: CGPoint(x: 3.589, y: 2.585), control1: CGPoint(x: 2.376, y: 1.056), control2: CGPoint(x: 3.011, y: 1.798))
        pathPath1.addLine(to: CGPoint(x: 3.589, y: 2.585))
        pathPath1.addCurve(to: CGPoint(x: 6.362, y: 11.393), control1: CGPoint(x: 5.435, y: 5.147), control2: CGPoint(x: 6.408, y: 8.235))
        pathPath1.closeSubpath()
        pathPath1.move(to: CGPoint(x: 6.362, y: 11.393))

        let pathPath2 = CGMutablePath()
        pathPath2.move(to: CGPoint(x: 4.934, y: 7.856))
        pathPath2.addLine(to: CGPoint(x: 4.934, y: 7.856))
        pathPath2.addCurve(to: CGPoint(x: 1.866, y: 14.977), control1: CGPoint(x: 4.884, y: 10.54), control2: CGPoint(x: 3.783, y: 13.097))
        pathPath2.addCurve(to: CGPoint(x: 1.666, y: 15.164), control1: CGPoint(x: 1.802, y: 15.041), control2: CGPoint(x: 1.738, y: 15.105))
        pathPath2.addLine(to: CGPoint(x: 1.666, y: 15.164))
        pathPath2.addCurve(to: CGPoint(x: 0.311, y: 15.247), control1: CGPoint(x: 1.315, y: 15.561), control2: CGPoint(x: 0.708, y: 15.598))
        pathPath2.addCurve(to: CGPoint(x: 0.266, y: 15.205), control1: CGPoint(x: 0.296, y: 15.233), control2: CGPoint(x: 0.281, y: 15.219))
        pathPath2.addLine(to: CGPoint(x: 0.266, y: 15.205))
        pathPath2.addCurve(to: CGPoint(x: 0.291, y: 13.883), control1: CGPoint(x: -0.092, y: 14.833), control2: CGPoint(x: -0.081, y: 14.241))
        pathPath2.addCurve(to: CGPoint(x: 0.366, y: 13.818), control1: CGPoint(x: 0.315, y: 13.86), control2: CGPoint(x: 0.34, y: 13.838))
        pathPath2.addLine(to: CGPoint(x: 0.366, y: 13.818))
        pathPath2.addCurve(to: CGPoint(x: 0.679, y: 2.007), control1: CGPoint(x: 3.677, y: 10.626), control2: CGPoint(x: 3.817, y: 5.369))
        pathPath2.addCurve(to: CGPoint(x: 0.217, y: 1.507), control1: CGPoint(x: 0.528, y: 1.838), control2: CGPoint(x: 0.351, y: 1.689))
        pathPath2.addLine(to: CGPoint(x: 0.217, y: 1.507))
        pathPath2.addCurve(to: CGPoint(x: 0.349, y: 0.216), control1: CGPoint(x: -0.103, y: 1.114), control2: CGPoint(x: -0.044, y: 0.536))
        pathPath2.addCurve(to: CGPoint(x: 1.404, y: 0.144), control1: CGPoint(x: 0.65, y: -0.029), control2: CGPoint(x: 1.072, y: -0.058))
        pathPath2.addLine(to: CGPoint(x: 1.404, y: 0.144))
        pathPath2.addCurve(to: CGPoint(x: 2.022, y: 0.672), control1: CGPoint(x: 1.63, y: 0.295), control2: CGPoint(x: 1.838, y: 0.472))
        pathPath2.addLine(to: CGPoint(x: 2.022, y: 0.672))
        pathPath2.addCurve(to: CGPoint(x: 4.934, y: 7.856), control1: CGPoint(x: 3.898, y: 2.592), control2: CGPoint(x: 4.943, y: 5.172))
        pathPath2.closeSubpath()
        pathPath2.move(to: CGPoint(x: 4.934, y: 7.856))

        let pathPath3 = CGMutablePath()
        pathPath3.move(to: CGPoint(x: 3.7, y: 4.748))
        pathPath3.addLine(to: CGPoint(x: 3.7, y: 4.748))
        pathPath3.addCurve(to: CGPoint(x: 1.79, y: 8.611), control1: CGPoint(x: 3.667, y: 6.255), control2: CGPoint(x: 2.967, y: 7.669))
        pathPath3.addLine(to: CGPoint(x: 1.79, y: 8.611))
        pathPath3.addCurve(to: CGPoint(x: 0.677, y: 8.926), control1: CGPoint(x: 1.475, y: 8.858), control2: CGPoint(x: 1.075, y: 8.971))
        pathPath3.addCurve(to: CGPoint(x: 0.362, y: 7.403), control1: CGPoint(x: -0.072, y: 8.798), control2: CGPoint(x: -0.231, y: 7.977))
        pathPath3.addLine(to: CGPoint(x: 0.362, y: 7.403))
        pathPath3.addCurve(to: CGPoint(x: 1.662, y: 5.391), control1: CGPoint(x: 0.992, y: 6.882), control2: CGPoint(x: 1.446, y: 6.179))
        pathPath3.addLine(to: CGPoint(x: 1.662, y: 5.391))
        pathPath3.addCurve(to: CGPoint(x: 0.798, y: 2.105), control1: CGPoint(x: 1.916, y: 4.221), control2: CGPoint(x: 1.595, y: 2.999))
        pathPath3.addCurve(to: CGPoint(x: 0.426, y: 1.705), control1: CGPoint(x: 0.687, y: 1.962), control2: CGPoint(x: 0.544, y: 1.846))
        pathPath3.addCurve(to: CGPoint(x: 0.308, y: 0.259), control1: CGPoint(x: -0.061, y: 1.136), control2: CGPoint(x: -0.097, y: 0.662))
        pathPath3.addLine(to: CGPoint(x: 0.308, y: 0.259))
        pathPath3.addCurve(to: CGPoint(x: 1.773, y: 0.358), control1: CGPoint(x: 0.74, y: -0.118), control2: CGPoint(x: 1.396, y: -0.074))
        pathPath3.addCurve(to: CGPoint(x: 1.774, y: 0.359), control1: CGPoint(x: 1.773, y: 0.358), control2: CGPoint(x: 1.774, y: 0.359))
        pathPath3.addLine(to: CGPoint(x: 1.774, y: 0.359))
        pathPath3.addCurve(to: CGPoint(x: 3.7, y: 4.748), control1: CGPoint(x: 3.02, y: 1.475), control2: CGPoint(x: 3.722, y: 3.076))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 3.7, y: 4.748))

        // Openned Passport
        //
        let opennedPassportLayer = CALayer()
        opennedPassportLayer.name = "Openned Passport"
        opennedPassportLayer.bounds = CGRect(x: 0, y: 0, width: 195.149231, height: 136.198486)
        opennedPassportLayer.position = CGPoint(x: 19.925385, y: 20.900757)
        opennedPassportLayer.anchorPoint = CGPoint(x: 0, y: 0)
        opennedPassportLayer.contentsGravity = .center
        opennedPassportLayer.shadowOffset = CGSize(width: 0, height: 1)
        opennedPassportLayer.allowsEdgeAntialiasing = true
        opennedPassportLayer.allowsGroupOpacity = true
        opennedPassportLayer.fillMode = .forwards

            // Openned Passport Sublayers
            //

            // Group 9
            //
            let groupLayer = CALayer()
            groupLayer.name = "Group 9"
            groupLayer.bounds = CGRect(x: 0, y: 0, width: 195.149231, height: 136.198486)
            groupLayer.position = CGPoint(x: 0, y: 0)
            groupLayer.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer.contentsGravity = .center
            groupLayer.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer.allowsEdgeAntialiasing = true
            groupLayer.allowsGroupOpacity = true
            groupLayer.fillMode = .forwards

                // Group 9 Sublayers
                //

                // Group 6
                //
                let groupLayer1 = CALayer()
                groupLayer1.name = "Group 6"
                groupLayer1.bounds = CGRect(x: 0, y: 0, width: 195.149231, height: 136.198486)
                groupLayer1.position = CGPoint(x: 0, y: 0)
                groupLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer1.contentsGravity = .center
                groupLayer1.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer1.allowsEdgeAntialiasing = true
                groupLayer1.allowsGroupOpacity = true
                groupLayer1.fillMode = .forwards

                    // Group 6 Sublayers
                    //

                    // Rectangle 3
                    //
                    let rectangleLayer = CALayer()
                    rectangleLayer.name = "Rectangle 3"
                    rectangleLayer.bounds = CGRect(x: 0, y: 0, width: 97.290833, height: 136.198425)
                    rectangleLayer.position = CGPoint(x: -0.000061, y: 0.000031)
                    rectangleLayer.anchorPoint = CGPoint(x: 0, y: 0)
                    rectangleLayer.contentsGravity = .center
                    rectangleLayer.backgroundColor = backgroundColor.cgColor
                    rectangleLayer.cornerRadius = 5
                    rectangleLayer.shadowOffset = CGSize(width: 0, height: 1)
                    rectangleLayer.allowsEdgeAntialiasing = true
                    rectangleLayer.allowsGroupOpacity = true
                    rectangleLayer.fillMode = .forwards

                    groupLayer1.addSublayer(rectangleLayer)

                    // Group 5
                    //
                    let groupLayer2 = CALayer()
                    groupLayer2.name = "Group 5"
                    groupLayer2.bounds = CGRect(x: 0, y: 0, width: 97.290833, height: 136.198456)
                    groupLayer2.position = CGPoint(x: 97.858398, y: 0.000031)
                    groupLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                    groupLayer2.contentsGravity = .center
                    groupLayer2.shadowOffset = CGSize(width: 0, height: 1)
                    groupLayer2.allowsEdgeAntialiasing = true
                    groupLayer2.allowsGroupOpacity = true
                    groupLayer2.fillMode = .forwards

                        // Group 5 Sublayers
                        //

                        // Rectangle 4
                        //
                        let rectangleLayer1 = CALayer()
                        rectangleLayer1.name = "Rectangle 4"
                        rectangleLayer1.bounds = CGRect(x: 0, y: 0, width: 97.290833, height: 136.198456)
                        rectangleLayer1.position = CGPoint(x: -1, y: 0)
                        rectangleLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                        rectangleLayer1.contentsGravity = .center
                        rectangleLayer1.backgroundColor = backgroundColor.cgColor
                        rectangleLayer1.cornerRadius = 5
                        rectangleLayer1.shadowOffset = CGSize(width: 0, height: 1)
                        rectangleLayer1.allowsEdgeAntialiasing = true
                        rectangleLayer1.allowsGroupOpacity = true
                        rectangleLayer1.fillMode = .forwards

                        groupLayer2.addSublayer(rectangleLayer1)

                    groupLayer1.addSublayer(groupLayer2)

                groupLayer.addSublayer(groupLayer1)

                // Group 7
                //
                let groupLayer3 = CALayer()
                groupLayer3.name = "Group 7"
                groupLayer3.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 26.003601)
                groupLayer3.position = CGPoint(x: 19.765137, y: 22.376282)
                groupLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer3.contentsGravity = .center
                groupLayer3.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer3.allowsEdgeAntialiasing = true
                groupLayer3.allowsGroupOpacity = true
                groupLayer3.fillMode = .forwards

                    // Group 7 Sublayers
                    //

                    // Line 1
                    //
                    let lineLayer = CAShapeLayer()
                    lineLayer.name = "Line 1"
                    lineLayer.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer.position = CGPoint(x: 0, y: 0)
                    lineLayer.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer.contentsGravity = .center
                    lineLayer.backgroundColor = backgroundColor1.cgColor
                    lineLayer.borderColor = backgroundColor1.cgColor
                    lineLayer.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer.allowsEdgeAntialiasing = true
                    lineLayer.allowsGroupOpacity = true
                    lineLayer.fillMode = .forwards
                    lineLayer.path = linePath
                    lineLayer.fillColor = backgroundColor1.cgColor
                    lineLayer.strokeColor = strokeColor.cgColor
                    lineLayer.lineWidth = 1

                    groupLayer3.addSublayer(lineLayer)

                    // Line 2
                    //
                    let lineLayer1 = CAShapeLayer()
                    lineLayer1.name = "Line 2"
                    lineLayer1.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer1.position = CGPoint(x: 0, y: 8.667877)
                    lineLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer1.contentsGravity = .center
                    lineLayer1.backgroundColor = backgroundColor1.cgColor
                    lineLayer1.borderColor = backgroundColor1.cgColor
                    lineLayer1.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer1.allowsEdgeAntialiasing = true
                    lineLayer1.allowsGroupOpacity = true
                    lineLayer1.fillMode = .forwards
                    lineLayer1.path = linePath1
                    lineLayer1.fillColor = backgroundColor1.cgColor
                    lineLayer1.strokeColor = strokeColor.cgColor
                    lineLayer1.lineWidth = 1

                    groupLayer3.addSublayer(lineLayer1)

                    // Line 3
                    //
                    let lineLayer2 = CAShapeLayer()
                    lineLayer2.name = "Line 3"
                    lineLayer2.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer2.position = CGPoint(x: 0, y: 17.335724)
                    lineLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer2.contentsGravity = .center
                    lineLayer2.backgroundColor = backgroundColor1.cgColor
                    lineLayer2.borderColor = backgroundColor1.cgColor
                    lineLayer2.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer2.allowsEdgeAntialiasing = true
                    lineLayer2.allowsGroupOpacity = true
                    lineLayer2.fillMode = .forwards
                    lineLayer2.path = linePath2
                    lineLayer2.fillColor = backgroundColor1.cgColor
                    lineLayer2.strokeColor = strokeColor.cgColor
                    lineLayer2.lineWidth = 1

                    groupLayer3.addSublayer(lineLayer2)

                    // Line 4
                    //
                    let lineLayer3 = CAShapeLayer()
                    lineLayer3.name = "Line 4"
                    lineLayer3.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer3.position = CGPoint(x: 0, y: 26.003601)
                    lineLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer3.contentsGravity = .center
                    lineLayer3.backgroundColor = backgroundColor1.cgColor
                    lineLayer3.borderColor = backgroundColor1.cgColor
                    lineLayer3.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer3.allowsEdgeAntialiasing = true
                    lineLayer3.allowsGroupOpacity = true
                    lineLayer3.fillMode = .forwards
                    lineLayer3.path = linePath3
                    lineLayer3.fillColor = backgroundColor1.cgColor
                    lineLayer3.strokeColor = strokeColor.cgColor
                    lineLayer3.lineWidth = 1

                    groupLayer3.addSublayer(lineLayer3)

                groupLayer.addSublayer(groupLayer3)

                // Group 8
                //
                let groupLayer4 = CALayer()
                groupLayer4.name = "Group 8"
                groupLayer4.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 26.003632)
                groupLayer4.position = CGPoint(x: 18.119324, y: 87.85083)
                groupLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer4.contentsGravity = .center
                groupLayer4.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer4.allowsEdgeAntialiasing = true
                groupLayer4.allowsGroupOpacity = true
                groupLayer4.fillMode = .forwards

                    // Group 8 Sublayers
                    //

                    // Line 5
                    //
                    let lineLayer4 = CAShapeLayer()
                    lineLayer4.name = "Line 5"
                    lineLayer4.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer4.position = CGPoint(x: 0, y: 0)
                    lineLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer4.contentsGravity = .center
                    lineLayer4.backgroundColor = backgroundColor1.cgColor
                    lineLayer4.borderColor = backgroundColor1.cgColor
                    lineLayer4.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer4.allowsEdgeAntialiasing = true
                    lineLayer4.allowsGroupOpacity = true
                    lineLayer4.fillMode = .forwards
                    lineLayer4.path = linePath4
                    lineLayer4.fillColor = backgroundColor1.cgColor
                    lineLayer4.strokeColor = strokeColor.cgColor
                    lineLayer4.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer4)

                    // Line 6
                    //
                    let lineLayer5 = CAShapeLayer()
                    lineLayer5.name = "Line 6"
                    lineLayer5.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer5.position = CGPoint(x: 0, y: 8.667847)
                    lineLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer5.contentsGravity = .center
                    lineLayer5.backgroundColor = backgroundColor1.cgColor
                    lineLayer5.borderColor = backgroundColor1.cgColor
                    lineLayer5.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer5.allowsEdgeAntialiasing = true
                    lineLayer5.allowsGroupOpacity = true
                    lineLayer5.fillMode = .forwards
                    lineLayer5.path = linePath5
                    lineLayer5.fillColor = backgroundColor1.cgColor
                    lineLayer5.strokeColor = strokeColor.cgColor
                    lineLayer5.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer5)

                    // Line 7
                    //
                    let lineLayer6 = CAShapeLayer()
                    lineLayer6.name = "Line 7"
                    lineLayer6.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer6.position = CGPoint(x: 0, y: 17.335754)
                    lineLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer6.contentsGravity = .center
                    lineLayer6.backgroundColor = backgroundColor1.cgColor
                    lineLayer6.borderColor = backgroundColor1.cgColor
                    lineLayer6.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer6.allowsEdgeAntialiasing = true
                    lineLayer6.allowsGroupOpacity = true
                    lineLayer6.fillMode = .forwards
                    lineLayer6.path = linePath6
                    lineLayer6.fillColor = backgroundColor1.cgColor
                    lineLayer6.strokeColor = strokeColor.cgColor
                    lineLayer6.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer6)

                    // Line 8
                    //
                    let lineLayer7 = CAShapeLayer()
                    lineLayer7.name = "Line 8"
                    lineLayer7.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer7.position = CGPoint(x: 0, y: 26.003632)
                    lineLayer7.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer7.contentsGravity = .center
                    lineLayer7.backgroundColor = backgroundColor1.cgColor
                    lineLayer7.borderColor = backgroundColor1.cgColor
                    lineLayer7.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer7.allowsEdgeAntialiasing = true
                    lineLayer7.allowsGroupOpacity = true
                    lineLayer7.fillMode = .forwards
                    lineLayer7.path = linePath7
                    lineLayer7.fillColor = backgroundColor1.cgColor
                    lineLayer7.strokeColor = strokeColor.cgColor
                    lineLayer7.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer7)

                groupLayer.addSublayer(groupLayer4)

            opennedPassportLayer.addSublayer(groupLayer)

            // Middle Line
            //
            let middleLineLayer = CAShapeLayer()
            middleLineLayer.name = "Middle Line"
            middleLineLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 136)
            middleLineLayer.position = CGPoint(x: 97, y: 3)
            middleLineLayer.anchorPoint = CGPoint(x: 0, y: 0)
            middleLineLayer.contentsGravity = .center
            middleLineLayer.borderColor = borderColor.cgColor
            middleLineLayer.shadowOffset = CGSize(width: 0, height: 1)
            middleLineLayer.allowsEdgeAntialiasing = true
            middleLineLayer.allowsGroupOpacity = true
            middleLineLayer.fillMode = .forwards
            middleLineLayer.path = middleLinePath
            middleLineLayer.fillColor = fillColor.cgColor
            middleLineLayer.strokeColor = strokeColor1.cgColor
            middleLineLayer.lineWidth = 1

            opennedPassportLayer.addSublayer(middleLineLayer)

        self.layer.addSublayer(opennedPassportLayer)

        // Device
        //
        let deviceLayer = CALayer()
        deviceLayer.name = "Device"
        deviceLayer.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
        deviceLayer.position = CGPoint(x: 197.069702, y: 132.251251)
        deviceLayer.anchorPoint = CGPoint(x: 0, y: 0)
        deviceLayer.contentsGravity = .center
        deviceLayer.shadowOffset = CGSize(width: 0, height: 1)
        deviceLayer.allowsEdgeAntialiasing = true
        deviceLayer.allowsGroupOpacity = true
        deviceLayer.fillMode = .forwards

            // Device Sublayers
            //

            // Group 14
            //
            let groupLayer5 = CALayer()
            groupLayer5.name = "Group 14"
            groupLayer5.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
            groupLayer5.position = CGPoint(x: -76, y: -116)
            groupLayer5.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer5.contentsGravity = .center
            groupLayer5.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer5.allowsEdgeAntialiasing = true
            groupLayer5.allowsGroupOpacity = true
            groupLayer5.fillMode = .forwards

                // Group 14 Sublayers
                //

                // Rectangle 6
                //
                let rectangleLayer2 = CALayer()
                rectangleLayer2.name = "Rectangle 6"
                rectangleLayer2.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 114.601166)
                rectangleLayer2.position = CGPoint(x: 0, y: 19.14679)
                rectangleLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer2.contentsGravity = .center
                rectangleLayer2.backgroundColor = backgroundColor2.cgColor
                rectangleLayer2.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer2.allowsEdgeAntialiasing = true
                rectangleLayer2.allowsGroupOpacity = true
                rectangleLayer2.fillMode = .forwards

                groupLayer5.addSublayer(rectangleLayer2)

                // Rectangle 7
                //
                let rectangleLayer3 = CALayer()
                rectangleLayer3.name = "Rectangle 7"
                rectangleLayer3.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 24.433228)
                rectangleLayer3.position = CGPoint(x: 0, y: 133.461273)
                rectangleLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer3.contentsGravity = .center
                rectangleLayer3.backgroundColor = strokeColor.cgColor
                rectangleLayer3.cornerRadius = 5
        if #available(iOS 11.0, *) {
            rectangleLayer3.maskedCorners = CACornerMask([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                rectangleLayer3.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer3.allowsEdgeAntialiasing = true
                rectangleLayer3.allowsGroupOpacity = true
                rectangleLayer3.fillMode = .forwards

                groupLayer5.addSublayer(rectangleLayer3)

                // Rectangle 8
                //
                let rectangleLayer4 = CALayer()
                rectangleLayer4.name = "Rectangle 8"
                rectangleLayer4.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 19.348602)
                rectangleLayer4.position = CGPoint(x: 91, y: 20)
                rectangleLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer4.contentsGravity = .center
                rectangleLayer4.backgroundColor = strokeColor.cgColor
                rectangleLayer4.cornerRadius = 5
        if #available(iOS 11.0, *) {
            rectangleLayer4.maskedCorners = CACornerMask([.layerMinXMaxYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                rectangleLayer4.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer4.allowsEdgeAntialiasing = true
                rectangleLayer4.allowsGroupOpacity = true
                rectangleLayer4.fillMode = .forwards
                rectangleLayer4.transform = CATransform3D( m11: -1, m12: 0, m13: 0, m14: 0,
                                                   m21: 0, m22: -1, m23: 0, m24: 0,
                                                   m31: 0, m32: 0, m33: 1, m34: 0,
                                                   m41: 0, m42: 0, m43: 0, m44: 1 )

                groupLayer5.addSublayer(rectangleLayer4)

                // Rectangle 9
                //
                let rectangleLayer5 = CALayer()
                rectangleLayer5.name = "Rectangle 9"
                rectangleLayer5.bounds = CGRect(x: 0, y: 0, width: 21.381104, height: 7.996185)
                rectangleLayer5.position = CGPoint(x: 34.726318, y: 5.67627)
                rectangleLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer5.contentsGravity = .center
                rectangleLayer5.backgroundColor = backgroundColor3.cgColor
                rectangleLayer5.cornerRadius = 2.438305
                rectangleLayer5.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer5.allowsEdgeAntialiasing = true
                rectangleLayer5.allowsGroupOpacity = true
                rectangleLayer5.fillMode = .forwards

                groupLayer5.addSublayer(rectangleLayer5)

                // Group 13
                //
                let groupLayer6 = CALayer()
                groupLayer6.name = "Group 13"
                groupLayer6.bounds = CGRect(x: 0, y: 0, width: 20.375, height: 30.180573)
                groupLayer6.position = CGPoint(x: 35.229736, y: 61.356964)
                groupLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer6.contentsGravity = .center
                groupLayer6.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer6.allowsEdgeAntialiasing = true
                groupLayer6.allowsGroupOpacity = true
                groupLayer6.fillMode = .forwards

                    // Group 13 Sublayers
                    //

                    // Path 9
                    //
                    let pathLayer = CAShapeLayer()
                    pathLayer.name = "Path 9"
                    pathLayer.bounds = CGRect(x: 0, y: 0, width: 7.93103, height: 30.180573)
                    pathLayer.position = CGPoint(x: 12.44397, y: 0)
                    pathLayer.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer.contentsGravity = .center
                    pathLayer.backgroundColor = backgroundColor1.cgColor
                    pathLayer.borderColor = backgroundColor1.cgColor
                    pathLayer.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer.allowsEdgeAntialiasing = true
                    pathLayer.allowsGroupOpacity = true
                    pathLayer.fillMode = .forwards
                    pathLayer.path = pathPath
                    pathLayer.fillColor = fillColor1.cgColor
                    pathLayer.strokeColor = strokeColor2.cgColor
                    pathLayer.lineWidth = 0

                    groupLayer6.addSublayer(pathLayer)

                    // Path 10
                    //
                    let pathLayer1 = CAShapeLayer()
                    pathLayer1.name = "Path 10"
                    pathLayer1.bounds = CGRect(x: 0, y: 0, width: 6.364502, height: 22.60144)
                    pathLayer1.position = CGPoint(x: 8.136963, y: 3.797516)
                    pathLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer1.contentsGravity = .center
                    pathLayer1.backgroundColor = backgroundColor1.cgColor
                    pathLayer1.borderColor = backgroundColor1.cgColor
                    pathLayer1.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer1.allowsEdgeAntialiasing = true
                    pathLayer1.allowsGroupOpacity = true
                    pathLayer1.fillMode = .forwards
                    pathLayer1.path = pathPath1
                    pathLayer1.fillColor = fillColor1.cgColor
                    pathLayer1.strokeColor = strokeColor2.cgColor
                    pathLayer1.lineWidth = 0

                    groupLayer6.addSublayer(pathLayer1)

                    // Path 11
                    //
                    let pathLayer2 = CAShapeLayer()
                    pathLayer2.name = "Path 11"
                    pathLayer2.bounds = CGRect(x: 0, y: 0, width: 4.938965, height: 15.498047)
                    pathLayer2.position = CGPoint(x: 3.893433, y: 7.349426)
                    pathLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer2.contentsGravity = .center
                    pathLayer2.backgroundColor = backgroundColor1.cgColor
                    pathLayer2.borderColor = backgroundColor1.cgColor
                    pathLayer2.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer2.allowsEdgeAntialiasing = true
                    pathLayer2.allowsGroupOpacity = true
                    pathLayer2.fillMode = .forwards
                    pathLayer2.path = pathPath2
                    pathLayer2.fillColor = fillColor1.cgColor
                    pathLayer2.strokeColor = strokeColor2.cgColor
                    pathLayer2.lineWidth = 0

                    groupLayer6.addSublayer(pathLayer2)

                    // Path 12
                    //
                    let pathLayer3 = CAShapeLayer()
                    pathLayer3.name = "Path 12"
                    pathLayer3.bounds = CGRect(x: 0, y: 0, width: 3.70166, height: 8.938507)
                    pathLayer3.position = CGPoint(x: -0.000122, y: 10.596069)
                    pathLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer3.contentsGravity = .center
                    pathLayer3.backgroundColor = backgroundColor1.cgColor
                    pathLayer3.borderColor = backgroundColor1.cgColor
                    pathLayer3.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer3.allowsEdgeAntialiasing = true
                    pathLayer3.allowsGroupOpacity = true
                    pathLayer3.fillMode = .forwards
                    pathLayer3.path = pathPath3
                    pathLayer3.fillColor = fillColor1.cgColor
                    pathLayer3.strokeColor = strokeColor2.cgColor
                    pathLayer3.lineWidth = 0

                    groupLayer6.addSublayer(pathLayer3)

                groupLayer5.addSublayer(groupLayer6)

            deviceLayer.addSublayer(groupLayer5)

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
