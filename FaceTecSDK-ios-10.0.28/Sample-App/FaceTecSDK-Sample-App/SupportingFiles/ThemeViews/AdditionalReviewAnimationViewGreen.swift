import UIKit

class AdditionalReviewAnimationViewGreen: UIView
{

    // MARK: - Initialization

    init()
    {
        super.init(frame: CGRect(x: 0, y: 0, width: 123, height: 80))
        self.setupLayers()
    }

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        self.setupLayers()
    }

    // MARK: - Setup Layers

    private func setupLayers()
    {
        // Colors
        //
        let fillColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let strokeColor = UIColor(red: 0.796, green: 0.796, blue: 0.796, alpha: 1)
        let fillColor1 = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        let strokeColor1 = UIColor(red: 0.035, green: 0.710, blue: 0.639, alpha: 1)

        // Paths
        //
        let strokePath = CGMutablePath()
        strokePath.move(to: CGPoint(x: 2.225, y: 70.536003))
        strokePath.addLine(to: CGPoint(x: 2, y: 9.106))
        strokePath.addCurve(to: CGPoint(x: 8.67, y: 2.386), control1: CGPoint(x: 1.986, y: 5.424), control2: CGPoint(x: 4.988, y: 2.4))
        strokePath.addLine(to: CGPoint(x: 113.982002, y: 2))
        strokePath.addCurve(to: CGPoint(x: 120.700996, y: 8.671), control1: CGPoint(x: 117.664001, y: 1.987), control2: CGPoint(x: 120.688004, y: 4.988))
        strokePath.addLine(to: CGPoint(x: 120.927002, y: 70.100998))
        strokePath.addCurve(to: CGPoint(x: 114.255997, y: 76.82), control1: CGPoint(x: 120.940002, y: 73.782997), control2: CGPoint(x: 117.938004, y: 76.806999))
        strokePath.addLine(to: CGPoint(x: 8.945, y: 77.207001))
        strokePath.addCurve(to: CGPoint(x: 2.225, y: 70.536003), control1: CGPoint(x: 5.262, y: 77.220001), control2: CGPoint(x: 2.239, y: 74.218002))
        strokePath.closeSubpath()
        strokePath.move(to: CGPoint(x: 2.225, y: 70.536003))

        let fillPath = CGMutablePath()
        fillPath.move(to: CGPoint(x: 19.375999, y: 3.399))
        fillPath.addLine(to: CGPoint(x: 0.892, y: 3.467))
        fillPath.addCurve(to: CGPoint(x: 0.006, y: 2.587), control1: CGPoint(x: 0.405, y: 3.469), control2: CGPoint(x: 0.008, y: 3.075))
        fillPath.addLine(to: CGPoint(x: 0, y: 0.954))
        fillPath.addCurve(to: CGPoint(x: 0.88, y: 0.068), control1: CGPoint(x: -0.002, y: 0.466), control2: CGPoint(x: 0.392, y: 0.069))
        fillPath.addLine(to: CGPoint(x: 19.364, y: 0))
        fillPath.addCurve(to: CGPoint(x: 20.25, y: 0.879), control1: CGPoint(x: 19.851, y: -0.002), control2: CGPoint(x: 20.247999, y: 0.392))
        fillPath.addLine(to: CGPoint(x: 20.256001, y: 2.513))
        fillPath.addCurve(to: CGPoint(x: 19.375999, y: 3.399), control1: CGPoint(x: 20.257, y: 3.001), control2: CGPoint(x: 19.864, y: 3.397))

        let fillPath1 = CGMutablePath()
        fillPath1.move(to: CGPoint(x: 11.084, y: 3.399))
        fillPath1.addLine(to: CGPoint(x: 0.892, y: 3.436))
        fillPath1.addCurve(to: CGPoint(x: 0.006, y: 2.557), control1: CGPoint(x: 0.405, y: 3.438), control2: CGPoint(x: 0.008, y: 3.044))
        fillPath1.addLine(to: CGPoint(x: 0, y: 0.923))
        fillPath1.addCurve(to: CGPoint(x: 0.88, y: 0.037), control1: CGPoint(x: -0.002, y: 0.436), control2: CGPoint(x: 0.392, y: 0.039))
        fillPath1.addLine(to: CGPoint(x: 11.072, y: 0))
        fillPath1.addCurve(to: CGPoint(x: 11.958, y: 0.879), control1: CGPoint(x: 11.559, y: -0.002), control2: CGPoint(x: 11.956, y: 0.392))
        fillPath1.addLine(to: CGPoint(x: 11.964, y: 2.513))
        fillPath1.addCurve(to: CGPoint(x: 11.084, y: 3.399), control1: CGPoint(x: 11.965, y: 3.001), control2: CGPoint(x: 11.572, y: 3.397))

        let fillPath2 = CGMutablePath()
        fillPath2.move(to: CGPoint(x: 11.084, y: 3.399))
        fillPath2.addLine(to: CGPoint(x: 0.892, y: 3.436))
        fillPath2.addCurve(to: CGPoint(x: 0.006, y: 2.557), control1: CGPoint(x: 0.405, y: 3.438), control2: CGPoint(x: 0.008, y: 3.044))
        fillPath2.addLine(to: CGPoint(x: 0, y: 0.923))
        fillPath2.addCurve(to: CGPoint(x: 0.88, y: 0.037), control1: CGPoint(x: -0.002, y: 0.436), control2: CGPoint(x: 0.392, y: 0.039))
        fillPath2.addLine(to: CGPoint(x: 11.072, y: 0))
        fillPath2.addCurve(to: CGPoint(x: 11.958, y: 0.879), control1: CGPoint(x: 11.559, y: -0.002), control2: CGPoint(x: 11.956, y: 0.392))
        fillPath2.addLine(to: CGPoint(x: 11.964, y: 2.513))
        fillPath2.addCurve(to: CGPoint(x: 11.084, y: 3.399), control1: CGPoint(x: 11.965, y: 3.001), control2: CGPoint(x: 11.572, y: 3.397))

        let fillPath3 = CGMutablePath()
        fillPath3.move(to: CGPoint(x: 36.967999, y: 3.399))
        fillPath3.addLine(to: CGPoint(x: 0.892, y: 3.531))
        fillPath3.addCurve(to: CGPoint(x: 0.006, y: 2.652), control1: CGPoint(x: 0.405, y: 3.533), control2: CGPoint(x: 0.008, y: 3.139))
        fillPath3.addLine(to: CGPoint(x: 0, y: 1.018))
        fillPath3.addCurve(to: CGPoint(x: 0.88, y: 0.132), control1: CGPoint(x: -0.001, y: 0.531), control2: CGPoint(x: 0.392, y: 0.134))
        fillPath3.addLine(to: CGPoint(x: 36.956001, y: 0))
        fillPath3.addCurve(to: CGPoint(x: 37.841999, y: 0.879), control1: CGPoint(x: 37.443001, y: -0.002), control2: CGPoint(x: 37.84, y: 0.392))
        fillPath3.addLine(to: CGPoint(x: 37.848, y: 2.513))
        fillPath3.addCurve(to: CGPoint(x: 36.967999, y: 3.399), control1: CGPoint(x: 37.848999, y: 3.001), control2: CGPoint(x: 37.456001, y: 3.397))

        let fillPath4 = CGMutablePath()
        fillPath4.move(to: CGPoint(x: 36.967999, y: 3.399))
        fillPath4.addLine(to: CGPoint(x: 0.892, y: 3.531))
        fillPath4.addCurve(to: CGPoint(x: 0.006, y: 2.652), control1: CGPoint(x: 0.405, y: 3.533), control2: CGPoint(x: 0.008, y: 3.139))
        fillPath4.addLine(to: CGPoint(x: 0, y: 1.018))
        fillPath4.addCurve(to: CGPoint(x: 0.88, y: 0.132), control1: CGPoint(x: -0.001, y: 0.531), control2: CGPoint(x: 0.392, y: 0.134))
        fillPath4.addLine(to: CGPoint(x: 36.956001, y: 0))
        fillPath4.addCurve(to: CGPoint(x: 37.841999, y: 0.879), control1: CGPoint(x: 37.443001, y: -0.002), control2: CGPoint(x: 37.84, y: 0.392))
        fillPath4.addLine(to: CGPoint(x: 37.848, y: 2.513))
        fillPath4.addCurve(to: CGPoint(x: 36.967999, y: 3.399), control1: CGPoint(x: 37.848999, y: 3.001), control2: CGPoint(x: 37.456001, y: 3.397))

        let fillPath5 = CGMutablePath()
        fillPath5.move(to: CGPoint(x: 36.967999, y: 3.399))
        fillPath5.addLine(to: CGPoint(x: 0.892, y: 3.531))
        fillPath5.addCurve(to: CGPoint(x: 0.006, y: 2.652), control1: CGPoint(x: 0.405, y: 3.533), control2: CGPoint(x: 0.008, y: 3.139))
        fillPath5.addLine(to: CGPoint(x: 0, y: 1.018))
        fillPath5.addCurve(to: CGPoint(x: 0.88, y: 0.132), control1: CGPoint(x: -0.001, y: 0.531), control2: CGPoint(x: 0.392, y: 0.134))
        fillPath5.addLine(to: CGPoint(x: 36.956001, y: 0))
        fillPath5.addCurve(to: CGPoint(x: 37.841999, y: 0.879), control1: CGPoint(x: 37.443001, y: -0.002), control2: CGPoint(x: 37.84, y: 0.392))
        fillPath5.addLine(to: CGPoint(x: 37.848, y: 2.513))
        fillPath5.addCurve(to: CGPoint(x: 36.967999, y: 3.399), control1: CGPoint(x: 37.848999, y: 3.001), control2: CGPoint(x: 37.456001, y: 3.397))

        let fillPath6 = CGMutablePath()
        fillPath6.move(to: CGPoint(x: 21.964001, y: 24.409))
        fillPath6.addCurve(to: CGPoint(x: 21.628, y: 23.298), control1: CGPoint(x: 21.851, y: 24.035999), control2: CGPoint(x: 21.740999, y: 23.667))
        fillPath6.addCurve(to: CGPoint(x: 20.531, y: 20.237), control1: CGPoint(x: 21.312, y: 22.26), control2: CGPoint(x: 20.948, y: 21.239))
        fillPath6.addCurve(to: CGPoint(x: 18.409, y: 16.43), control1: CGPoint(x: 19.969, y: 18.886999), control2: CGPoint(x: 19.25, y: 17.624001))
        fillPath6.addCurve(to: CGPoint(x: 17.712999, y: 15.588), control1: CGPoint(x: 18.200001, y: 16.132999), control2: CGPoint(x: 17.952999, y: 15.861))
        fillPath6.addCurve(to: CGPoint(x: 17.735001, y: 15.363), control1: CGPoint(x: 17.624001, y: 15.488), control2: CGPoint(x: 17.639, y: 15.445))
        fillPath6.addCurve(to: CGPoint(x: 20.184999, y: 9.776), control1: CGPoint(x: 19.451, y: 13.896), control2: CGPoint(x: 20.275999, y: 12.012))
        fillPath6.addCurve(to: CGPoint(x: 16.788, y: 4.059), control1: CGPoint(x: 20.084, y: 7.283), control2: CGPoint(x: 18.993999, y: 5.309))
        fillPath6.addCurve(to: CGPoint(x: 9.612, y: 5.361), control1: CGPoint(x: 14.44, y: 2.729), control2: CGPoint(x: 11.464, y: 3.292))
        fillPath6.addCurve(to: CGPoint(x: 10.146, y: 15.204), control1: CGPoint(x: 7.083, y: 8.184), control2: CGPoint(x: 7.331, y: 12.758))
        fillPath6.addCurve(to: CGPoint(x: 10.199, y: 15.776), control1: CGPoint(x: 10.447, y: 15.465), control2: CGPoint(x: 10.447, y: 15.466))
        fillPath6.addCurve(to: CGPoint(x: 8.446, y: 18.363001), control1: CGPoint(x: 9.546, y: 16.591999), control2: CGPoint(x: 8.981, y: 17.469999))
        fillPath6.addCurve(to: CGPoint(x: 7.821, y: 19.738001), control1: CGPoint(x: 8.19, y: 18.792999), control2: CGPoint(x: 8.025, y: 19.277))
        fillPath6.addCurve(to: CGPoint(x: 6.266, y: 24.237), control1: CGPoint(x: 7.173, y: 21.193001), control2: CGPoint(x: 6.707, y: 22.709999))
        fillPath6.addCurve(to: CGPoint(x: 6.206, y: 24.431999), control1: CGPoint(x: 6.247, y: 24.301001), control2: CGPoint(x: 6.227, y: 24.364))
        fillPath6.addCurve(to: CGPoint(x: 1.41, y: 10.959), control1: CGPoint(x: 2.555, y: 21.763), control2: CGPoint(x: 0.058, y: 16.603001))
        fillPath6.addCurve(to: CGPoint(x: 13.766, y: 1.04), control1: CGPoint(x: 2.767, y: 5.289), control2: CGPoint(x: 7.9, y: 1.168))
        fillPath6.addCurve(to: CGPoint(x: 26.552999, y: 10.307), control1: CGPoint(x: 19.806999, y: 0.909), control2: CGPoint(x: 24.916, y: 4.845))
        fillPath6.addCurve(to: CGPoint(x: 21.964001, y: 24.409), control1: CGPoint(x: 28.256001, y: 15.989), control2: CGPoint(x: 25.895, y: 21.506001))
        fillPath6.move(to: CGPoint(x: 10.72, y: 14.305))
        fillPath6.addCurve(to: CGPoint(x: 10.56, y: 5.896), control1: CGPoint(x: 8.393, y: 12.116), control2: CGPoint(x: 8.318, y: 8.172))
        fillPath6.addCurve(to: CGPoint(x: 17.968, y: 6.371), control1: CGPoint(x: 12.711, y: 3.711), control2: CGPoint(x: 16.108999, y: 3.929))
        fillPath6.addCurve(to: CGPoint(x: 19.198, y: 9.996), control1: CGPoint(x: 18.767, y: 7.42), control2: CGPoint(x: 19.188999, y: 8.665))
        fillPath6.addCurve(to: CGPoint(x: 17.174999, y: 14.502), control1: CGPoint(x: 19.165001, y: 11.786), control2: CGPoint(x: 18.559, y: 13.329))
        fillPath6.addCurve(to: CGPoint(x: 10.72, y: 14.305), control1: CGPoint(x: 15.251, y: 16.132999), control2: CGPoint(x: 12.562, y: 16.038))
        fillPath6.move(to: CGPoint(x: 20.872, y: 25.157))
        fillPath6.addCurve(to: CGPoint(x: 16.712999, y: 26.806999), control1: CGPoint(x: 19.579, y: 25.943001), control2: CGPoint(x: 18.195, y: 26.497))
        fillPath6.addCurve(to: CGPoint(x: 14.097, y: 27.077), control1: CGPoint(x: 15.85, y: 26.988001), control2: CGPoint(x: 14.978, y: 27.076))
        fillPath6.addCurve(to: CGPoint(x: 7.328, y: 25.208), control1: CGPoint(x: 11.667, y: 27.084999), control2: CGPoint(x: 9.415, y: 26.448999))
        fillPath6.addCurve(to: CGPoint(x: 7.162, y: 24.804001), control1: CGPoint(x: 7.157, y: 25.106001), control2: CGPoint(x: 7.101, y: 25.018))
        fillPath6.addCurve(to: CGPoint(x: 8.31, y: 21.237), control1: CGPoint(x: 7.505, y: 23.601999), control2: CGPoint(x: 7.849, y: 22.399))
        fillPath6.addCurve(to: CGPoint(x: 10.339, y: 17.337), control1: CGPoint(x: 8.852, y: 19.870001), control2: CGPoint(x: 9.456, y: 18.528999))
        fillPath6.addCurve(to: CGPoint(x: 11.193, y: 16.218), control1: CGPoint(x: 10.619, y: 16.959999), control2: CGPoint(x: 10.912, y: 16.594))
        fillPath6.addCurve(to: CGPoint(x: 11.449, y: 16.166), control1: CGPoint(x: 11.271, y: 16.115), control2: CGPoint(x: 11.332, y: 16.110001))
        fillPath6.addCurve(to: CGPoint(x: 16.622999, y: 16.162001), control1: CGPoint(x: 13.173, y: 17.006001), control2: CGPoint(x: 14.901, y: 16.982))
        fillPath6.addCurve(to: CGPoint(x: 16.941999, y: 16.233999), control1: CGPoint(x: 16.771999, y: 16.091), control2: CGPoint(x: 16.844999, y: 16.108))
        fillPath6.addCurve(to: CGPoint(x: 19.483999, y: 20.483999), control1: CGPoint(x: 17.962, y: 17.548), control2: CGPoint(x: 18.847, y: 18.938999))
        fillPath6.addCurve(to: CGPoint(x: 20.978001, y: 24.915001), control1: CGPoint(x: 20.08, y: 21.93), control2: CGPoint(x: 20.563, y: 23.41))
        fillPath6.addCurve(to: CGPoint(x: 20.872, y: 25.157), control1: CGPoint(x: 21.016001, y: 25.052999), control2: CGPoint(x: 20.968, y: 25.098))
        fillPath6.move(to: CGPoint(x: 14.023, y: 0))
        fillPath6.addCurve(to: CGPoint(x: 0, y: 14.126), control1: CGPoint(x: 6.259, y: 0.028), control2: CGPoint(x: -0.036, y: 6.37))
        fillPath6.addCurve(to: CGPoint(x: 14.089, y: 28.143), control1: CGPoint(x: 0.035, y: 21.881001), control2: CGPoint(x: 6.353, y: 28.158001))
        fillPath6.addCurve(to: CGPoint(x: 28.143999, y: 14.02), control1: CGPoint(x: 21.829, y: 28.129), control2: CGPoint(x: 28.173, y: 21.85))
        fillPath6.addCurve(to: CGPoint(x: 14.023, y: 0), control1: CGPoint(x: 28.115, y: 6.243), control2: CGPoint(x: 21.784, y: -0.029))

        let strokePath1 = CGMutablePath()
        strokePath1.move(to: CGPoint(x: 0, y: 0.41))
        strokePath1.addLine(to: CGPoint(x: 107.448997, y: 0.59))
        strokePath1.closeSubpath()
        strokePath1.move(to: CGPoint(x: 0, y: 0.41))

        let fillPath7 = CGMutablePath()
        fillPath7.move(to: CGPoint(x: 36.967999, y: 3.399))
        fillPath7.addLine(to: CGPoint(x: 0.892, y: 3.531))
        fillPath7.addCurve(to: CGPoint(x: 0.006, y: 2.652), control1: CGPoint(x: 0.405, y: 3.533), control2: CGPoint(x: 0.008, y: 3.139))
        fillPath7.addLine(to: CGPoint(x: 0, y: 1.018))
        fillPath7.addCurve(to: CGPoint(x: 0.88, y: 0.132), control1: CGPoint(x: -0.001, y: 0.531), control2: CGPoint(x: 0.392, y: 0.134))
        fillPath7.addLine(to: CGPoint(x: 36.956001, y: 0))
        fillPath7.addCurve(to: CGPoint(x: 37.841999, y: 0.879), control1: CGPoint(x: 37.443001, y: -0.002), control2: CGPoint(x: 37.84, y: 0.392))
        fillPath7.addLine(to: CGPoint(x: 37.848, y: 2.513))
        fillPath7.addCurve(to: CGPoint(x: 36.967999, y: 3.399), control1: CGPoint(x: 37.848999, y: 3.001), control2: CGPoint(x: 37.456001, y: 3.397))

        let strokePath2 = CGMutablePath()
        strokePath2.move(to: CGPoint(x: 48.928001, y: 25.714001))
        strokePath2.addCurve(to: CGPoint(x: 25.714001, y: 48.928001), control1: CGPoint(x: 48.928001, y: 38.535), control2: CGPoint(x: 38.535, y: 48.928001))
        strokePath2.addCurve(to: CGPoint(x: 2.5, y: 25.714001), control1: CGPoint(x: 12.893, y: 48.928001), control2: CGPoint(x: 2.5, y: 38.535))
        strokePath2.addCurve(to: CGPoint(x: 25.714001, y: 2.5), control1: CGPoint(x: 2.5, y: 12.893), control2: CGPoint(x: 12.893, y: 2.5))
        strokePath2.addCurve(to: CGPoint(x: 48.928001, y: 25.714001), control1: CGPoint(x: 38.535, y: 2.5), control2: CGPoint(x: 48.928001, y: 12.893))
        strokePath2.closeSubpath()
        strokePath2.move(to: CGPoint(x: 48.928001, y: 25.714001))

        let strokePath3 = CGMutablePath()
        strokePath3.move(to: CGPoint(x: 0, y: 0))
        strokePath3.addLine(to: CGPoint(x: 10.125, y: 10.125))
        strokePath3.closeSubpath()
        strokePath3.move(to: CGPoint(x: 0, y: 0))

        // ID
        //
        let iDLayer = CALayer()
        iDLayer.name = "ID"
        iDLayer.bounds = CGRect(x: 0, y: 0, width: 118.927091, height: 75.207084)
        iDLayer.position = CGPoint(x: 3, y: 2.729758)
        iDLayer.anchorPoint = CGPoint(x: 0, y: 0)
        iDLayer.contentsGravity = .center
        iDLayer.contentsScale = 2
        iDLayer.allowsEdgeAntialiasing = true
        iDLayer.allowsGroupOpacity = true
        iDLayer.sublayerTransform = CATransform3D( m11: 0.95, m12: 0, m13: 0, m14: 0,
                                                   m21: 0, m22: 0.95, m23: 0, m24: 0,
                                                   m31: 0, m32: 0, m33: 1, m34: 0,
                                                   m41: 0, m42: 0, m43: 0, m44: 1 )

            // ID Sublayers
            //

            // Layer
            //
            let layerLayer = CALayer()
            layerLayer.name = "Layer"
            layerLayer.bounds = CGRect(x: 0, y: 0, width: 118.927091, height: 75.207084)
            layerLayer.position = CGPoint(x: 0, y: 0)
            layerLayer.anchorPoint = CGPoint(x: 0, y: 0)
            layerLayer.contentsGravity = .center
            layerLayer.shadowOffset = CGSize(width: 0, height: 1)
            layerLayer.allowsEdgeAntialiasing = true
            layerLayer.allowsGroupOpacity = true
            layerLayer.fillMode = .forwards

                // Layer Sublayers
                //

                // Stroke 1
                //
                let strokeLayer = CAShapeLayer()
                strokeLayer.name = "Stroke 1"
                strokeLayer.bounds = CGRect(x: 0, y: 0, width: 118.927091, height: 75.207084)
                strokeLayer.position = CGPoint(x: 0, y: 0)
                strokeLayer.anchorPoint = CGPoint(x: 0, y: 0)
                strokeLayer.contentsGravity = .center
                strokeLayer.contentsScale = 2
                strokeLayer.allowsEdgeAntialiasing = true
                strokeLayer.allowsGroupOpacity = true
                strokeLayer.path = strokePath
                strokeLayer.fillColor = fillColor.cgColor
                strokeLayer.strokeColor = strokeColor.cgColor
                strokeLayer.fillRule = .evenOdd
                strokeLayer.lineWidth = 4

                layerLayer.addSublayer(strokeLayer)

            iDLayer.addSublayer(layerLayer)

            // Fill 3
            //
            let fillLayer = CAShapeLayer()
            fillLayer.name = "Fill 3"
            fillLayer.bounds = CGRect(x: 0, y: 0, width: 20.256009, height: 3.467015)
            fillLayer.position = CGPoint(x: 48.045441, y: 61.690934)
            fillLayer.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer.contentsGravity = .center
            fillLayer.contentsScale = 2
            fillLayer.allowsEdgeAntialiasing = true
            fillLayer.allowsGroupOpacity = true
            fillLayer.path = fillPath
            fillLayer.fillColor = fillColor1.cgColor
            fillLayer.strokeColor = fillColor.cgColor
            fillLayer.fillRule = .evenOdd
            fillLayer.lineWidth = 0

            iDLayer.addSublayer(fillLayer)

            // Fill 5
            //
            let fillLayer1 = CAShapeLayer()
            fillLayer1.name = "Fill 5"
            fillLayer1.bounds = CGRect(x: 0, y: 0, width: 11.964009, height: 3.436015)
            fillLayer1.position = CGPoint(x: 97.852841, y: 41.745134)
            fillLayer1.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer1.contentsGravity = .center
            fillLayer1.contentsScale = 2
            fillLayer1.allowsEdgeAntialiasing = true
            fillLayer1.allowsGroupOpacity = true
            fillLayer1.path = fillPath1
            fillLayer1.fillColor = fillColor1.cgColor
            fillLayer1.strokeColor = fillColor.cgColor
            fillLayer1.fillRule = .evenOdd
            fillLayer1.lineWidth = 0

            iDLayer.addSublayer(fillLayer1)

            // Fill 7
            //
            let fillLayer2 = CAShapeLayer()
            fillLayer2.name = "Fill 7"
            fillLayer2.bounds = CGRect(x: 0, y: 0, width: 11.964009, height: 3.436015)
            fillLayer2.position = CGPoint(x: 97.816541, y: 31.848534)
            fillLayer2.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer2.contentsGravity = .center
            fillLayer2.contentsScale = 2
            fillLayer2.allowsEdgeAntialiasing = true
            fillLayer2.allowsGroupOpacity = true
            fillLayer2.path = fillPath2
            fillLayer2.fillColor = fillColor1.cgColor
            fillLayer2.strokeColor = fillColor.cgColor
            fillLayer2.fillRule = .evenOdd
            fillLayer2.lineWidth = 0

            iDLayer.addSublayer(fillLayer2)

            // Fill 9
            //
            let fillLayer3 = CAShapeLayer()
            fillLayer3.name = "Fill 9"
            fillLayer3.bounds = CGRect(x: 0, y: 0, width: 37.848004, height: 3.531015)
            fillLayer3.position = CGPoint(x: 48.008847, y: 51.729734)
            fillLayer3.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer3.contentsGravity = .center
            fillLayer3.contentsScale = 2
            fillLayer3.allowsEdgeAntialiasing = true
            fillLayer3.allowsGroupOpacity = true
            fillLayer3.path = fillPath3
            fillLayer3.fillColor = fillColor1.cgColor
            fillLayer3.strokeColor = fillColor.cgColor
            fillLayer3.fillRule = .evenOdd
            fillLayer3.lineWidth = 0

            iDLayer.addSublayer(fillLayer3)

            // Fill 11
            //
            let fillLayer4 = CAShapeLayer()
            fillLayer4.name = "Fill 11"
            fillLayer4.bounds = CGRect(x: 0, y: 0, width: 37.848004, height: 3.531015)
            fillLayer4.position = CGPoint(x: 47.972547, y: 41.833234)
            fillLayer4.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer4.contentsGravity = .center
            fillLayer4.contentsScale = 2
            fillLayer4.allowsEdgeAntialiasing = true
            fillLayer4.allowsGroupOpacity = true
            fillLayer4.path = fillPath4
            fillLayer4.fillColor = fillColor1.cgColor
            fillLayer4.strokeColor = fillColor.cgColor
            fillLayer4.fillRule = .evenOdd
            fillLayer4.lineWidth = 0

            iDLayer.addSublayer(fillLayer4)

            // Fill 13
            //
            let fillLayer5 = CAShapeLayer()
            fillLayer5.name = "Fill 13"
            fillLayer5.bounds = CGRect(x: 0, y: 0, width: 37.848004, height: 3.531015)
            fillLayer5.position = CGPoint(x: 47.936247, y: 31.936634)
            fillLayer5.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer5.contentsGravity = .center
            fillLayer5.contentsScale = 2
            fillLayer5.allowsEdgeAntialiasing = true
            fillLayer5.allowsGroupOpacity = true
            fillLayer5.path = fillPath5
            fillLayer5.fillColor = fillColor1.cgColor
            fillLayer5.strokeColor = fillColor.cgColor
            fillLayer5.fillRule = .evenOdd
            fillLayer5.lineWidth = 0

            iDLayer.addSublayer(fillLayer5)

            // Fill 15
            //
            let fillLayer6 = CAShapeLayer()
            fillLayer6.name = "Fill 15"
            fillLayer6.bounds = CGRect(x: 0, y: 0, width: 28.144253, height: 28.143127)
            fillLayer6.position = CGPoint(x: 9.109195, y: 34.635742)
            fillLayer6.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer6.contentsGravity = .center
            fillLayer6.contentsScale = 2
            fillLayer6.allowsEdgeAntialiasing = true
            fillLayer6.allowsGroupOpacity = true
            fillLayer6.path = fillPath6
            fillLayer6.fillColor = fillColor1.cgColor
            fillLayer6.strokeColor = fillColor.cgColor
            fillLayer6.fillRule = .evenOdd
            fillLayer6.lineWidth = 0

            iDLayer.addSublayer(fillLayer6)

            // Stroke 23
            //
            let strokeLayer1 = CAShapeLayer()
            strokeLayer1.name = "Stroke 23"
            strokeLayer1.bounds = CGRect(x: 0, y: 0, width: 107.449, height: 1)
            strokeLayer1.position = CGPoint(x: 7.738449, y: 21.5059)
            strokeLayer1.anchorPoint = CGPoint(x: 0, y: 0)
            strokeLayer1.contentsGravity = .center
            strokeLayer1.contentsScale = 2
            strokeLayer1.allowsEdgeAntialiasing = true
            strokeLayer1.allowsGroupOpacity = true
            strokeLayer1.path = strokePath1
            strokeLayer1.fillColor = fillColor.cgColor
            strokeLayer1.strokeColor = fillColor1.cgColor
            strokeLayer1.fillRule = .evenOdd
            strokeLayer1.lineWidth = 1

            iDLayer.addSublayer(strokeLayer1)

            // Fill 24
            //
            let fillLayer7 = CAShapeLayer()
            fillLayer7.name = "Fill 24"
            fillLayer7.bounds = CGRect(x: 0, y: 0, width: 37.848004, height: 3.531015)
            fillLayer7.position = CGPoint(x: 7.738047, y: 11.365592)
            fillLayer7.anchorPoint = CGPoint(x: 0, y: 0)
            fillLayer7.contentsGravity = .center
            fillLayer7.contentsScale = 2
            fillLayer7.allowsEdgeAntialiasing = true
            fillLayer7.allowsGroupOpacity = true
            fillLayer7.path = fillPath7
            fillLayer7.fillColor = fillColor1.cgColor
            fillLayer7.strokeColor = fillColor.cgColor
            fillLayer7.fillRule = .evenOdd
            fillLayer7.lineWidth = 0

            iDLayer.addSublayer(fillLayer7)

        self.layer.addSublayer(iDLayer)

        // magnifier
        //
        let magnifierLayer = CALayer()
        magnifierLayer.name = "magnifier"
        magnifierLayer.bounds = CGRect(x: 0, y: 0, width: 50.0465, height: 50.9067)
        magnifierLayer.position = CGPoint(x: 0, y: 23.8663)
        magnifierLayer.anchorPoint = CGPoint(x: 0, y: 0)
        magnifierLayer.contentsGravity = .center
        magnifierLayer.contentsScale = 2
        magnifierLayer.allowsEdgeAntialiasing = true
        magnifierLayer.allowsGroupOpacity = true

            // magnifier Animations
            //

            // position
            //
            let positionAnimation = CAKeyframeAnimation()
            positionAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            positionAnimation.duration = 1.5
            positionAnimation.fillMode = .both
            positionAnimation.isRemovedOnCompletion = false
            positionAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.111726, -0.055537, 0.85845, 1.053796)
            positionAnimation.keyPath = "position"
            positionAnimation.values = [ CGPoint(x: 0, y: 23), CGPoint(x: 63, y: 23) ]
            positionAnimation.keyTimes = [ 0.000595, 1 ]
            positionAnimation.timingFunctions = [ CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut) ]
            positionAnimation.calculationMode = .linear

            magnifierLayer.add(positionAnimation, forKey: "positionAnimation")

            // magnifier Sublayers
            //

            // Well-Rounded
            //
            let wellRoundedLayer = CALayer()
            wellRoundedLayer.name = "Well-Rounded"
            wellRoundedLayer.bounds = CGRect(x: 0, y: 0, width: 46.428, height: 46.428)
            wellRoundedLayer.position = CGPoint(x: 0, y: 0)
            wellRoundedLayer.anchorPoint = CGPoint(x: 0, y: 0)
            wellRoundedLayer.contentsGravity = .center
            wellRoundedLayer.shadowOffset = CGSize(width: 0, height: 1)
            wellRoundedLayer.allowsEdgeAntialiasing = true
            wellRoundedLayer.allowsGroupOpacity = true
            wellRoundedLayer.fillMode = .forwards

                // Well-Rounded Sublayers
                //

                // Stroke 18
                //
                let strokeLayer2 = CAShapeLayer()
                strokeLayer2.name = "Stroke 18"
                strokeLayer2.bounds = CGRect(x: 0, y: 0, width: 46.428, height: 46.428)
                strokeLayer2.position = CGPoint(x: 0, y: 0)
                strokeLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                strokeLayer2.contentsGravity = .center
                strokeLayer2.contentsScale = 2
                strokeLayer2.allowsEdgeAntialiasing = true
                strokeLayer2.allowsGroupOpacity = true
                strokeLayer2.path = strokePath2
                strokeLayer2.fillColor = fillColor.cgColor
                strokeLayer2.strokeColor = strokeColor1.cgColor
                strokeLayer2.fillRule = .evenOdd
                strokeLayer2.lineWidth = 5

                wellRoundedLayer.addSublayer(strokeLayer2)

                // Stroke 20
                //
                let strokeLayer3 = CAShapeLayer()
                strokeLayer3.name = "Stroke 20"
                strokeLayer3.bounds = CGRect(x: 0, y: 0, width: 10.125, height: 10.125)
                strokeLayer3.position = CGPoint(x: 42.9215, y: 41.7817)
                strokeLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                strokeLayer3.contentsGravity = .center
                strokeLayer3.contentsScale = 2
                strokeLayer3.allowsEdgeAntialiasing = true
                strokeLayer3.allowsGroupOpacity = true
                strokeLayer3.path = strokePath3
                strokeLayer3.fillColor = fillColor.cgColor
                strokeLayer3.strokeColor = strokeColor1.cgColor
                strokeLayer3.fillRule = .evenOdd
                strokeLayer3.lineCap = .round
                strokeLayer3.lineJoin = .round
                strokeLayer3.lineWidth = 5

                wellRoundedLayer.addSublayer(strokeLayer3)

            magnifierLayer.addSublayer(wellRoundedLayer)

        self.layer.addSublayer(magnifierLayer)

    }

    // MARK: - Responder

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let location = touches.first?.location(in: self.superview),
              let hitLayer = self.layer.presentation()?.hitTest(location) else { return }

        print("Layer \(hitLayer.name ?? String(describing: hitLayer)) was tapped.")
    }
}
