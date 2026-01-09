import UIKit

class NFCScanningAnimationViewRed: UIView
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

    // MARK: - Setup Layers

    private func setupLayers()
    {
        // Colors
        //
        let backgroundColor = UIColor(red: 0.423529, green: 0.145098, blue: 0.168627, alpha: 1)
        let backgroundColor1 = UIColor(red: 0, green: 0.156863, blue: 0.27451, alpha: 1)
        let backgroundColor2 = UIColor(red: 0.05098, green: 0.043137, blue: 0.05098, alpha: 1)
        let backgroundColor3 = UIColor(red: 0.258824, green: 0.552941, blue: 0.462745, alpha: 1)
        let backgroundColor4 = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let fillColor = UIColor.white
        let strokeColor = UIColor.black
        let fillColor1 = UIColor(red: 0.980392, green: 0.980392, blue: 0.980392, alpha: 1)
        let backgroundColor5 = UIColor(red: 0.964706, green: 0.94902, blue: 0.909804, alpha: 1)
        let strokeColor1 = UIColor(red: 0.419608, green: 0.419608, blue: 0.419608, alpha: 1)
        let borderColor = UIColor(red: 0.795254, green: 0.795254, blue: 0.795254, alpha: 1)
        let fillColor2 = UIColor(red: 0.109806, green: 0.113802, blue: 0.109804, alpha: 1)
        let strokeColor2 = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let fillColor3 = UIColor(red: 0.094118, green: 0.352941, blue: 0.737255, alpha: 1)
        let fillColor4 = UIColor(red: 0.168627, green: 0.486275, blue: 0.823529, alpha: 1)
        let fillColor5 = UIColor(red: 0.254902, green: 0.643137, blue: 0.929412, alpha: 1)
        let backgroundColor6 = UIColor(red: 0.160784, green: 0.498039, blue: 0.713725, alpha: 1)
        let backgroundColor7 = UIColor(red: 0.65098, green: 0.698039, blue: 0.709804, alpha: 1)

        // Paths
        //
        let pathPath = CGMutablePath()
        pathPath.move(to: CGPoint(x: 7.402, y: -0.001))
        pathPath.addCurve(to: CGPoint(x: 14.502, y: -0.001), control1: CGPoint(x: 9.768, y: -0.001), control2: CGPoint(x: 12.132, y: -0.001))
        pathPath.addCurve(to: CGPoint(x: 14.782, y: 0.271), control1: CGPoint(x: 14.718, y: -0.001), control2: CGPoint(x: 14.784, y: 0.053))
        pathPath.addCurve(to: CGPoint(x: 14.782, y: 3.655), control1: CGPoint(x: 14.772, y: 1.399), control2: CGPoint(x: 14.774, y: 2.527))
        pathPath.addCurve(to: CGPoint(x: 14.533, y: 3.916), control1: CGPoint(x: 14.782, y: 3.842), control2: CGPoint(x: 14.736, y: 3.916))
        pathPath.addCurve(to: CGPoint(x: 10.68, y: 3.916), control1: CGPoint(x: 13.249, y: 3.908), control2: CGPoint(x: 11.964, y: 3.909))
        pathPath.addCurve(to: CGPoint(x: 10.424, y: 3.726), control1: CGPoint(x: 10.536, y: 3.916), control2: CGPoint(x: 10.47, y: 3.888))
        pathPath.addLine(to: CGPoint(x: 10.424, y: 3.726))
        pathPath.addCurve(to: CGPoint(x: 8.112, y: 1.444), control1: CGPoint(x: 10.162, y: 2.581), control2: CGPoint(x: 9.26, y: 1.691))
        pathPath.addLine(to: CGPoint(x: 8.112, y: 1.444))
        pathPath.addCurve(to: CGPoint(x: 4.536, y: 3.223), control1: CGPoint(x: 6.645, y: 1.08), control2: CGPoint(x: 5.13, y: 1.833))
        pathPath.addLine(to: CGPoint(x: 4.536, y: 3.223))
        pathPath.addCurve(to: CGPoint(x: 4.367, y: 3.707), control1: CGPoint(x: 4.458, y: 3.376), control2: CGPoint(x: 4.401, y: 3.538))
        pathPath.addCurve(to: CGPoint(x: 4.078, y: 3.919), control1: CGPoint(x: 4.337, y: 3.9), control2: CGPoint(x: 4.237, y: 3.919))
        pathPath.addCurve(to: CGPoint(x: 0.271, y: 3.919), control1: CGPoint(x: 2.809, y: 3.919), control2: CGPoint(x: 1.54, y: 3.912))
        pathPath.addCurve(to: CGPoint(x: 0.002, y: 3.655), control1: CGPoint(x: 0.071, y: 3.919), control2: CGPoint(x: 0, y: 3.865))
        pathPath.addCurve(to: CGPoint(x: 0.002, y: 0.271), control1: CGPoint(x: 0.01, y: 2.527), control2: CGPoint(x: 0.012, y: 1.399))
        pathPath.addCurve(to: CGPoint(x: 0.287, y: 0.002), control1: CGPoint(x: 0.002, y: 0.045), control2: CGPoint(x: 0.079, y: 0.002))
        pathPath.addCurve(to: CGPoint(x: 7.402, y: -0.001), control1: CGPoint(x: 3.839, y: 0.004), control2: CGPoint(x: 3.839, y: 0.004))
        pathPath.closeSubpath()
        pathPath.move(to: CGPoint(x: 7.402, y: -0.001))

        let pathPath1 = CGMutablePath()
        pathPath1.move(to: CGPoint(x: 7.388, y: 3.88))
        pathPath1.addLine(to: CGPoint(x: 0.339, y: 3.88))
        pathPath1.addCurve(to: CGPoint(x: 0, y: 3.545), control1: CGPoint(x: 0.001, y: 3.88), control2: CGPoint(x: 0, y: 3.88))
        pathPath1.addCurve(to: CGPoint(x: 0, y: 0.302), control1: CGPoint(x: 0, y: 2.464), control2: CGPoint(x: 0, y: 1.382))
        pathPath1.addCurve(to: CGPoint(x: 0.284, y: 0.002), control1: CGPoint(x: 0, y: 0.086), control2: CGPoint(x: 0.048, y: 0.002))
        pathPath1.addCurve(to: CGPoint(x: 4.067, y: 0.002), control1: CGPoint(x: 1.545, y: 0.012), control2: CGPoint(x: 2.806, y: 0.002))
        pathPath1.addCurve(to: CGPoint(x: 4.367, y: 0.202), control1: CGPoint(x: 4.223, y: 0.002), control2: CGPoint(x: 4.315, y: 0.022))
        pathPath1.addLine(to: CGPoint(x: 4.367, y: 0.202))
        pathPath1.addCurve(to: CGPoint(x: 8.176, y: 2.439), control1: CGPoint(x: 4.801, y: 1.872), control2: CGPoint(x: 6.506, y: 2.873))
        pathPath1.addCurve(to: CGPoint(x: 10.242, y: 0.687), control1: CGPoint(x: 9.095, y: 2.2), control2: CGPoint(x: 9.855, y: 1.555))
        pathPath1.addLine(to: CGPoint(x: 10.242, y: 0.687))
        pathPath1.addCurve(to: CGPoint(x: 10.416, y: 0.205), control1: CGPoint(x: 10.316, y: 0.533), control2: CGPoint(x: 10.374, y: 0.371))
        pathPath1.addCurve(to: CGPoint(x: 10.688, y: -0.003), control1: CGPoint(x: 10.449, y: 0.036), control2: CGPoint(x: 10.529, y: -0.005))
        pathPath1.addCurve(to: CGPoint(x: 14.518, y: -0.003), control1: CGPoint(x: 11.964, y: -0.003), control2: CGPoint(x: 13.241, y: 0.004))
        pathPath1.addCurve(to: CGPoint(x: 14.782, y: 0.271), control1: CGPoint(x: 14.73, y: -0.003), control2: CGPoint(x: 14.784, y: 0.069))
        pathPath1.addCurve(to: CGPoint(x: 14.782, y: 3.56), control1: CGPoint(x: 14.774, y: 1.371), control2: CGPoint(x: 14.782, y: 2.465))
        pathPath1.addCurve(to: CGPoint(x: 14.47, y: 3.875), control1: CGPoint(x: 14.782, y: 3.875), control2: CGPoint(x: 14.782, y: 3.875))
        pathPath1.closeSubpath()
        pathPath1.move(to: CGPoint(x: 7.388, y: 3.88))

        let pathPath2 = CGMutablePath()
        pathPath2.move(to: CGPoint(x: 0.001, y: 2.08))
        pathPath2.addLine(to: CGPoint(x: 0.001, y: 2.08))
        pathPath2.addCurve(to: CGPoint(x: 2.087, y: 0.01), control1: CGPoint(x: 0.005, y: 0.933), control2: CGPoint(x: 0.939, y: 0.006))
        pathPath2.addCurve(to: CGPoint(x: 4.157, y: 2.096), control1: CGPoint(x: 3.234, y: 0.015), control2: CGPoint(x: 4.161, y: 0.949))
        pathPath2.addCurve(to: CGPoint(x: 2.082, y: 4.166), control1: CGPoint(x: 4.152, y: 3.24), control2: CGPoint(x: 3.225, y: 4.165))
        pathPath2.addLine(to: CGPoint(x: 2.082, y: 4.166))
        pathPath2.addCurve(to: CGPoint(x: 0.001, y: 2.085), control1: CGPoint(x: 0.932, y: 4.166), control2: CGPoint(x: 0.001, y: 3.234))
        pathPath2.addCurve(to: CGPoint(x: 0.001, y: 2.08), control1: CGPoint(x: 0.001, y: 2.084), control2: CGPoint(x: 0.001, y: 2.082))
        pathPath2.closeSubpath()
        pathPath2.move(to: CGPoint(x: 0.001, y: 2.08))

        let pathPath3 = CGMutablePath()
        pathPath3.move(to: CGPoint(x: 26.937, y: 52.596001))
        pathPath3.addCurve(to: CGPoint(x: 0.021, y: 27.337999), control1: CGPoint(x: 12.968, y: 53.068001), control2: CGPoint(x: 0.579, y: 41.351002))
        pathPath3.addLine(to: CGPoint(x: 0.021, y: 27.337999))
        pathPath3.addCurve(to: CGPoint(x: 25.266001, y: 0.01), control1: CGPoint(x: -0.554, y: 12.82), control2: CGPoint(x: 10.748, y: 0.585))
        pathPath3.addCurve(to: CGPoint(x: 52.594002, y: 25.254999), control1: CGPoint(x: 39.783001, y: -0.565), control2: CGPoint(x: 52.018002, y: 10.737))
        pathPath3.addCurve(to: CGPoint(x: 27.349001, y: 52.583), control1: CGPoint(x: 53.168999, y: 39.771999), control2: CGPoint(x: 41.866001, y: 52.007999))
        pathPath3.addCurve(to: CGPoint(x: 26.937, y: 52.596001), control1: CGPoint(x: 27.211, y: 52.588001), control2: CGPoint(x: 27.073999, y: 52.592999))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 24.851, y: 37.206001))
        pathPath3.addLine(to: CGPoint(x: 24.851, y: 27.782))
        pathPath3.addLine(to: CGPoint(x: 14.823, y: 27.782))
        pathPath3.addLine(to: CGPoint(x: 14.823, y: 27.782))
        pathPath3.addCurve(to: CGPoint(x: 16.844999, y: 36.935001), control1: CGPoint(x: 14.978, y: 30.924999), control2: CGPoint(x: 15.661, y: 34.019001))
        pathPath3.addLine(to: CGPoint(x: 16.844999, y: 36.935001))
        pathPath3.addCurve(to: CGPoint(x: 17.229, y: 37.194), control1: CGPoint(x: 16.924999, y: 37.077), control2: CGPoint(x: 17.066999, y: 37.173))
        pathPath3.addCurve(to: CGPoint(x: 24.851, y: 37.206001), control1: CGPoint(x: 19.752001, y: 37.209), control2: CGPoint(x: 22.274, y: 37.206001))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 28.000999, y: 37.206001))
        pathPath3.addCurve(to: CGPoint(x: 35.571999, y: 37.189999), control1: CGPoint(x: 30.573999, y: 37.206001), control2: CGPoint(x: 33.073002, y: 37.213001))
        pathPath3.addLine(to: CGPoint(x: 35.571999, y: 37.189999))
        pathPath3.addCurve(to: CGPoint(x: 36.048, y: 36.824001), control1: CGPoint(x: 35.778999, y: 37.148998), control2: CGPoint(x: 35.955002, y: 37.014))
        pathPath3.addCurve(to: CGPoint(x: 36.706001, y: 35.009998), control1: CGPoint(x: 36.299, y: 36.231998), control2: CGPoint(x: 36.504002, y: 35.624001))
        pathPath3.addLine(to: CGPoint(x: 36.706001, y: 35.009998))
        pathPath3.addCurve(to: CGPoint(x: 38.039001, y: 27.750999), control1: CGPoint(x: 37.473, y: 32.660999), control2: CGPoint(x: 37.921001, y: 30.219))
        pathPath3.addLine(to: CGPoint(x: 28.000999, y: 27.750999))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 14.829, y: 24.629))
        pathPath3.addLine(to: CGPoint(x: 24.858999, y: 24.629))
        pathPath3.addLine(to: CGPoint(x: 24.858999, y: 15.414))
        pathPath3.addCurve(to: CGPoint(x: 17.146999, y: 15.425), control1: CGPoint(x: 22.259001, y: 15.414), control2: CGPoint(x: 19.705, y: 15.414))
        pathPath3.addCurve(to: CGPoint(x: 16.834, y: 15.7), control1: CGPoint(x: 17.040001, y: 15.425), control2: CGPoint(x: 16.881001, y: 15.581))
        pathPath3.addLine(to: CGPoint(x: 16.834, y: 15.7))
        pathPath3.addCurve(to: CGPoint(x: 14.829, y: 24.629), control1: CGPoint(x: 15.678, y: 18.545), control2: CGPoint(x: 15, y: 21.562))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 38.008999, y: 24.639999))
        pathPath3.addLine(to: CGPoint(x: 38.008999, y: 24.639999))
        pathPath3.addCurve(to: CGPoint(x: 36.085999, y: 15.805), control1: CGPoint(x: 37.839001, y: 21.612), control2: CGPoint(x: 37.189999, y: 18.629999))
        pathPath3.addLine(to: CGPoint(x: 36.085999, y: 15.805))
        pathPath3.addCurve(to: CGPoint(x: 35.426998, y: 15.405), control1: CGPoint(x: 35.999001, y: 15.524), control2: CGPoint(x: 35.716, y: 15.353))
        pathPath3.addCurve(to: CGPoint(x: 28.499001, y: 15.412), control1: CGPoint(x: 33.118, y: 15.415), control2: CGPoint(x: 30.809999, y: 15.405))
        pathPath3.addCurve(to: CGPoint(x: 28.014999, y: 15.446), control1: CGPoint(x: 28.332001, y: 15.412), control2: CGPoint(x: 28.164, y: 15.435))
        pathPath3.addLine(to: CGPoint(x: 28.014999, y: 24.639999))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 11.731, y: 27.788))
        pathPath3.addLine(to: CGPoint(x: 3.219, y: 27.788))
        pathPath3.addLine(to: CGPoint(x: 3.219, y: 27.788))
        pathPath3.addCurve(to: CGPoint(x: 3.196, y: 28.011), control1: CGPoint(x: 3.205, y: 27.861), control2: CGPoint(x: 3.198, y: 27.936001))
        pathPath3.addLine(to: CGPoint(x: 3.196, y: 28.011))
        pathPath3.addCurve(to: CGPoint(x: 5.734, y: 36.896999), control1: CGPoint(x: 3.41, y: 31.118), control2: CGPoint(x: 4.275, y: 34.145))
        pathPath3.addLine(to: CGPoint(x: 5.734, y: 36.896999))
        pathPath3.addCurve(to: CGPoint(x: 6.334, y: 37.196999), control1: CGPoint(x: 5.879, y: 37.081001), control2: CGPoint(x: 6.099, y: 37.191002))
        pathPath3.addCurve(to: CGPoint(x: 13.078, y: 37.208), control1: CGPoint(x: 8.582, y: 37.217999), control2: CGPoint(x: 10.834, y: 37.212002))
        pathPath3.addCurve(to: CGPoint(x: 13.59, y: 37.159), control1: CGPoint(x: 13.224, y: 37.208), control2: CGPoint(x: 13.37, y: 37.18))
        pathPath3.addLine(to: CGPoint(x: 13.59, y: 37.159))
        pathPath3.addCurve(to: CGPoint(x: 11.732, y: 27.789), control1: CGPoint(x: 12.505, y: 34.146), control2: CGPoint(x: 11.879, y: 30.988001))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 13.605, y: 15.388))
        pathPath3.addCurve(to: CGPoint(x: 6.116, y: 15.404), control1: CGPoint(x: 11.044, y: 15.388), control2: CGPoint(x: 8.581, y: 15.38))
        pathPath3.addLine(to: CGPoint(x: 6.116, y: 15.404))
        pathPath3.addCurve(to: CGPoint(x: 5.631, y: 15.775), control1: CGPoint(x: 5.904, y: 15.443), control2: CGPoint(x: 5.724, y: 15.581))
        pathPath3.addCurve(to: CGPoint(x: 3.703, y: 21.104), control1: CGPoint(x: 4.962, y: 17.541), control2: CGPoint(x: 4.247, y: 19.297001))
        pathPath3.addLine(to: CGPoint(x: 3.703, y: 21.104))
        pathPath3.addCurve(to: CGPoint(x: 3.109, y: 24.613001), control1: CGPoint(x: 3.428, y: 22.259001), control2: CGPoint(x: 3.229, y: 23.431))
        pathPath3.addLine(to: CGPoint(x: 11.735, y: 24.613001))
        pathPath3.addLine(to: CGPoint(x: 11.735, y: 24.613001))
        pathPath3.addCurve(to: CGPoint(x: 13.606, y: 15.391), control1: CGPoint(x: 11.908, y: 21.464001), control2: CGPoint(x: 12.538, y: 18.358))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 39.271, y: 37.137001))
        pathPath3.addLine(to: CGPoint(x: 39.271, y: 37.137001))
        pathPath3.addCurve(to: CGPoint(x: 39.480999, y: 37.195999), control1: CGPoint(x: 39.338001, y: 37.164001), control2: CGPoint(x: 39.409, y: 37.183998))
        pathPath3.addCurve(to: CGPoint(x: 46.458, y: 37.185001), control1: CGPoint(x: 41.807999, y: 37.195999), control2: CGPoint(x: 44.132999, y: 37.210999))
        pathPath3.addLine(to: CGPoint(x: 46.458, y: 37.185001))
        pathPath3.addCurve(to: CGPoint(x: 46.991001, y: 36.785), control1: CGPoint(x: 46.688999, y: 37.143002), control2: CGPoint(x: 46.886002, y: 36.994999))
        pathPath3.addLine(to: CGPoint(x: 46.991001, y: 36.785))
        pathPath3.addCurve(to: CGPoint(x: 48.691002, y: 32.312), control1: CGPoint(x: 47.633999, y: 35.324001), control2: CGPoint(x: 48.201, y: 33.831001))
        pathPath3.addCurve(to: CGPoint(x: 49.591, y: 27.76), control1: CGPoint(x: 49.113998, y: 30.846001), control2: CGPoint(x: 49.291, y: 29.312))
        pathPath3.addLine(to: CGPoint(x: 41.132, y: 27.76))
        pathPath3.addLine(to: CGPoint(x: 41.132, y: 27.76))
        pathPath3.addCurve(to: CGPoint(x: 39.271999, y: 37.139999), control1: CGPoint(x: 40.965, y: 30.959999), control2: CGPoint(x: 40.338001, y: 34.118999))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 49.437, y: 24.631001))
        pathPath3.addLine(to: CGPoint(x: 49.437, y: 24.631001))
        pathPath3.addCurve(to: CGPoint(x: 49.457001, y: 24.379999), control1: CGPoint(x: 49.451, y: 24.548), control2: CGPoint(x: 49.457001, y: 24.464001))
        pathPath3.addLine(to: CGPoint(x: 49.457001, y: 24.379999))
        pathPath3.addCurve(to: CGPoint(x: 46.995998, y: 15.714), control1: CGPoint(x: 49.235001, y: 21.354), control2: CGPoint(x: 48.396999, y: 18.405001))
        pathPath3.addLine(to: CGPoint(x: 46.995998, y: 15.714))
        pathPath3.addCurve(to: CGPoint(x: 46.396, y: 15.42), control1: CGPoint(x: 46.848999, y: 15.532), control2: CGPoint(x: 46.629002, y: 15.424))
        pathPath3.addCurve(to: CGPoint(x: 40.944, y: 15.407), control1: CGPoint(x: 44.578999, y: 15.397), control2: CGPoint(x: 42.762001, y: 15.407))
        pathPath3.addLine(to: CGPoint(x: 39.243999, y: 15.407))
        pathPath3.addLine(to: CGPoint(x: 39.243999, y: 15.407))
        pathPath3.addCurve(to: CGPoint(x: 41.125, y: 24.629999), control1: CGPoint(x: 40.303001, y: 18.377001), control2: CGPoint(x: 40.936001, y: 21.482))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 21.059, y: 3.723))
        pathPath3.addLine(to: CGPoint(x: 21.059, y: 3.723))
        pathPath3.addCurve(to: CGPoint(x: 7.786, y: 12.336), control1: CGPoint(x: 15.764, y: 4.954), control2: CGPoint(x: 11.067, y: 8.002))
        pathPath3.addCurve(to: CGPoint(x: 14.437, y: 12.347), control1: CGPoint(x: 10.1, y: 12.336), control2: CGPoint(x: 12.269, y: 12.323))
        pathPath3.addLine(to: CGPoint(x: 14.437, y: 12.347))
        pathPath3.addCurve(to: CGPoint(x: 15.19, y: 11.868), control1: CGPoint(x: 14.765, y: 12.368), control2: CGPoint(x: 15.07, y: 12.174))
        pathPath3.addLine(to: CGPoint(x: 15.19, y: 11.868))
        pathPath3.addCurve(to: CGPoint(x: 17.514999, y: 8.077), control1: CGPoint(x: 15.9, y: 10.566), control2: CGPoint(x: 16.676001, y: 9.3))
        pathPath3.addCurve(to: CGPoint(x: 21.059, y: 3.723), control1: CGPoint(x: 18.606001, y: 6.588), control2: CGPoint(x: 19.844, y: 5.204))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 7.839, y: 40.282001))
        pathPath3.addLine(to: CGPoint(x: 7.839, y: 40.282001))
        pathPath3.addCurve(to: CGPoint(x: 21.139, y: 48.915001), control1: CGPoint(x: 11.137, y: 44.615002), control2: CGPoint(x: 15.838, y: 47.667))
        pathPath3.addCurve(to: CGPoint(x: 21.087999, y: 48.745998), control1: CGPoint(x: 21.108999, y: 48.814999), control2: CGPoint(x: 21.111, y: 48.769001))
        pathPath3.addLine(to: CGPoint(x: 21.087999, y: 48.745998))
        pathPath3.addCurve(to: CGPoint(x: 15.064, y: 40.575001), control1: CGPoint(x: 18.650999, y: 46.366001), control2: CGPoint(x: 16.615999, y: 43.606998))
        pathPath3.addLine(to: CGPoint(x: 15.064, y: 40.575001))
        pathPath3.addCurve(to: CGPoint(x: 14.518, y: 40.292999), control1: CGPoint(x: 14.933, y: 40.403999), control2: CGPoint(x: 14.733, y: 40.299999))
        pathPath3.addCurve(to: CGPoint(x: 10.471, y: 40.282001), control1: CGPoint(x: 13.169, y: 40.27), control2: CGPoint(x: 11.818, y: 40.282001))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 31.739, y: 3.702))
        pathPath3.addLine(to: CGPoint(x: 31.739, y: 3.702))
        pathPath3.addCurve(to: CGPoint(x: 31.839001, y: 3.92), control1: CGPoint(x: 31.764, y: 3.778), control2: CGPoint(x: 31.798, y: 3.851))
        pathPath3.addLine(to: CGPoint(x: 31.839001, y: 3.92))
        pathPath3.addCurve(to: CGPoint(x: 37.778, y: 12.01), control1: CGPoint(x: 34.244999, y: 6.276), control2: CGPoint(x: 36.250999, y: 9.008))
        pathPath3.addLine(to: CGPoint(x: 37.778, y: 12.01))
        pathPath3.addCurve(to: CGPoint(x: 38.367001, y: 12.322), control1: CGPoint(x: 37.917, y: 12.197), control2: CGPoint(x: 38.133999, y: 12.311))
        pathPath3.addCurve(to: CGPoint(x: 42.766998, y: 12.337), control1: CGPoint(x: 39.831001, y: 12.348), control2: CGPoint(x: 41.299, y: 12.337))
        pathPath3.addLine(to: CGPoint(x: 44.926998, y: 12.337))
        pathPath3.addLine(to: CGPoint(x: 44.926998, y: 12.337))
        pathPath3.addCurve(to: CGPoint(x: 31.74, y: 3.702), control1: CGPoint(x: 41.667, y: 8.015), control2: CGPoint(x: 37.005001, y: 4.962))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 31.677999, y: 48.91))
        pathPath3.addLine(to: CGPoint(x: 31.677999, y: 48.91))
        pathPath3.addCurve(to: CGPoint(x: 44.838001, y: 40.262001), control1: CGPoint(x: 36.93, y: 47.630001), control2: CGPoint(x: 41.578999, y: 44.575001))
        pathPath3.addCurve(to: CGPoint(x: 38.431999, y: 40.251999), control1: CGPoint(x: 42.603001, y: 40.262001), control2: CGPoint(x: 40.516998, y: 40.272999))
        pathPath3.addLine(to: CGPoint(x: 38.431999, y: 40.251999))
        pathPath3.addCurve(to: CGPoint(x: 37.674, y: 40.723), control1: CGPoint(x: 38.101002, y: 40.215), control2: CGPoint(x: 37.787998, y: 40.41))
        pathPath3.addLine(to: CGPoint(x: 37.674, y: 40.723))
        pathPath3.addCurve(to: CGPoint(x: 33.896, y: 46.423), control1: CGPoint(x: 36.643002, y: 42.764999), control2: CGPoint(x: 35.375, y: 44.678001))
        pathPath3.addCurve(to: CGPoint(x: 31.679001, y: 48.91), control1: CGPoint(x: 33.205002, y: 47.233002), control2: CGPoint(x: 32.479, y: 48.014999))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 24.868999, y: 4.652))
        pathPath3.addLine(to: CGPoint(x: 24.868999, y: 4.652))
        pathPath3.addCurve(to: CGPoint(x: 18.469, y: 12.298), control1: CGPoint(x: 22.289, y: 6.791), control2: CGPoint(x: 20.121, y: 9.382))
        pathPath3.addLine(to: CGPoint(x: 24.868999, y: 12.298))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 18.469, y: 40.304001))
        pathPath3.addLine(to: CGPoint(x: 18.469, y: 40.304001))
        pathPath3.addCurve(to: CGPoint(x: 24.851999, y: 47.942001), control1: CGPoint(x: 20.120001, y: 43.213001), control2: CGPoint(x: 22.282, y: 45.799999))
        pathPath3.addLine(to: CGPoint(x: 24.851999, y: 40.304001))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 27.996, y: 12.285))
        pathPath3.addLine(to: CGPoint(x: 34.390999, y: 12.285))
        pathPath3.addLine(to: CGPoint(x: 34.390999, y: 12.285))
        pathPath3.addCurve(to: CGPoint(x: 27.996, y: 4.66), control1: CGPoint(x: 32.731998, y: 9.382), control2: CGPoint(x: 30.566, y: 6.799))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 27.996, y: 47.958))
        pathPath3.addLine(to: CGPoint(x: 27.996, y: 47.958))
        pathPath3.addCurve(to: CGPoint(x: 34.375999, y: 40.296001), control1: CGPoint(x: 30.559, y: 45.800999), control2: CGPoint(x: 32.719002, y: 43.207001))
        pathPath3.addLine(to: CGPoint(x: 27.996, y: 40.296001))
        pathPath3.closeSubpath()
        pathPath3.move(to: CGPoint(x: 27.996, y: 47.958))

        let pathPath4 = CGMutablePath()
        pathPath4.move(to: CGPoint(x: 2.102, y: 4.563))
        pathPath4.addLine(to: CGPoint(x: 2.102, y: 4.563))
        pathPath4.addCurve(to: CGPoint(x: 0.582, y: 3.963), control1: CGPoint(x: 1.535, y: 4.58), control2: CGPoint(x: 0.985, y: 4.363))
        pathPath4.addLine(to: CGPoint(x: 0.582, y: 3.963))
        pathPath4.addCurve(to: CGPoint(x: 0.002, y: 2.393), control1: CGPoint(x: 0.184, y: 3.54), control2: CGPoint(x: -0.025, y: 2.974))
        pathPath4.addLine(to: CGPoint(x: 0.002, y: 2.263))
        pathPath4.addLine(to: CGPoint(x: 0.002, y: 2.263))
        pathPath4.addCurve(to: CGPoint(x: 0.252, y: 1.093), control1: CGPoint(x: -0.006, y: 1.859), control2: CGPoint(x: 0.08, y: 1.459))
        pathPath4.addLine(to: CGPoint(x: 0.252, y: 1.093))
        pathPath4.addCurve(to: CGPoint(x: 1.002, y: 0.283), control1: CGPoint(x: 0.422, y: 0.758), control2: CGPoint(x: 0.681, y: 0.478))
        pathPath4.addLine(to: CGPoint(x: 1.002, y: 0.283))
        pathPath4.addCurve(to: CGPoint(x: 2.002, y: 0.003), control1: CGPoint(x: 1.302, y: 0.097), control2: CGPoint(x: 1.649, y: 0))
        pathPath4.addLine(to: CGPoint(x: 2.002, y: 0.003))
        pathPath4.addCurve(to: CGPoint(x: 3.372, y: 0.563), control1: CGPoint(x: 2.521, y: -0.029), control2: CGPoint(x: 3.025, y: 0.177))
        pathPath4.addLine(to: CGPoint(x: 3.372, y: 0.563))
        pathPath4.addCurve(to: CGPoint(x: 3.862, y: 2.183), control1: CGPoint(x: 3.728, y: 1.025), control2: CGPoint(x: 3.902, y: 1.602))
        pathPath4.addLine(to: CGPoint(x: 3.862, y: 2.563))
        pathPath4.addLine(to: CGPoint(x: 1.002, y: 2.563))
        pathPath4.addLine(to: CGPoint(x: 1.002, y: 2.563))
        pathPath4.addCurve(to: CGPoint(x: 1.372, y: 3.433), control1: CGPoint(x: 1.014, y: 2.889), control2: CGPoint(x: 1.146, y: 3.199))
        pathPath4.addLine(to: CGPoint(x: 1.372, y: 3.433))
        pathPath4.addCurve(to: CGPoint(x: 2.172, y: 3.743), control1: CGPoint(x: 1.586, y: 3.642), control2: CGPoint(x: 1.875, y: 3.754))
        pathPath4.addLine(to: CGPoint(x: 2.172, y: 3.743))
        pathPath4.addCurve(to: CGPoint(x: 3.272, y: 3.193), control1: CGPoint(x: 2.607, y: 3.752), control2: CGPoint(x: 3.019, y: 3.547))
        pathPath4.addLine(to: CGPoint(x: 3.802, y: 3.703))
        pathPath4.addLine(to: CGPoint(x: 3.802, y: 3.703))
        pathPath4.addCurve(to: CGPoint(x: 3.102, y: 4.313), control1: CGPoint(x: 3.629, y: 3.967), control2: CGPoint(x: 3.387, y: 4.178))
        pathPath4.addLine(to: CGPoint(x: 3.102, y: 4.313))
        pathPath4.addCurve(to: CGPoint(x: 2.102, y: 4.563), control1: CGPoint(x: 2.795, y: 4.478), control2: CGPoint(x: 2.451, y: 4.564))
        pathPath4.closeSubpath()
        pathPath4.move(to: CGPoint(x: 2.002, y: 0.793))
        pathPath4.addLine(to: CGPoint(x: 2.002, y: 0.793))
        pathPath4.addCurve(to: CGPoint(x: 1.352, y: 1.073), control1: CGPoint(x: 1.755, y: 0.784), control2: CGPoint(x: 1.516, y: 0.886))
        pathPath4.addLine(to: CGPoint(x: 1.352, y: 1.073))
        pathPath4.addCurve(to: CGPoint(x: 1.002, y: 1.863), control1: CGPoint(x: 1.159, y: 1.296), control2: CGPoint(x: 1.037, y: 1.571))
        pathPath4.addLine(to: CGPoint(x: 2.892, y: 1.863))
        pathPath4.addLine(to: CGPoint(x: 2.892, y: 1.793))
        pathPath4.addLine(to: CGPoint(x: 2.892, y: 1.793))
        pathPath4.addCurve(to: CGPoint(x: 2.622, y: 1.043), control1: CGPoint(x: 2.894, y: 1.519), control2: CGPoint(x: 2.798, y: 1.254))
        pathPath4.addLine(to: CGPoint(x: 2.622, y: 1.043))
        pathPath4.addCurve(to: CGPoint(x: 2.002, y: 0.793), control1: CGPoint(x: 2.462, y: 0.873), control2: CGPoint(x: 2.236, y: 0.782))
        pathPath4.closeSubpath()
        pathPath4.move(to: CGPoint(x: 2.002, y: 0.793))

        let pathPath5 = CGMutablePath()
        pathPath5.move(to: CGPoint(x: 1, y: 3.723))
        pathPath5.addLine(to: CGPoint(x: 1, y: 5.913))
        pathPath5.addLine(to: CGPoint(x: 0, y: 5.913))
        pathPath5.addLine(to: CGPoint(x: 0, y: 0.003))
        pathPath5.addLine(to: CGPoint(x: 2.25, y: 0.003))
        pathPath5.addLine(to: CGPoint(x: 2.25, y: 0.003))
        pathPath5.addCurve(to: CGPoint(x: 3.8, y: 0.523), control1: CGPoint(x: 2.814, y: -0.025), control2: CGPoint(x: 3.367, y: 0.16))
        pathPath5.addLine(to: CGPoint(x: 3.8, y: 0.523))
        pathPath5.addCurve(to: CGPoint(x: 4.39, y: 1.883), control1: CGPoint(x: 4.193, y: 0.863), control2: CGPoint(x: 4.41, y: 1.363))
        pathPath5.addLine(to: CGPoint(x: 4.39, y: 1.883))
        pathPath5.addCurve(to: CGPoint(x: 3.82, y: 3.233), control1: CGPoint(x: 4.418, y: 2.397), control2: CGPoint(x: 4.208, y: 2.895))
        pathPath5.addLine(to: CGPoint(x: 3.82, y: 3.233))
        pathPath5.addCurve(to: CGPoint(x: 2.25, y: 3.723), control1: CGPoint(x: 3.372, y: 3.579), control2: CGPoint(x: 2.815, y: 3.753))
        pathPath5.closeSubpath()
        pathPath5.move(to: CGPoint(x: 1, y: 2.893))
        pathPath5.addLine(to: CGPoint(x: 2.25, y: 2.893))
        pathPath5.addLine(to: CGPoint(x: 2.25, y: 2.893))
        pathPath5.addCurve(to: CGPoint(x: 3.09, y: 2.633), control1: CGPoint(x: 2.553, y: 2.914), control2: CGPoint(x: 2.852, y: 2.821))
        pathPath5.addLine(to: CGPoint(x: 3.09, y: 2.633))
        pathPath5.addCurve(to: CGPoint(x: 3.38, y: 1.893), control1: CGPoint(x: 3.285, y: 2.437), control2: CGPoint(x: 3.39, y: 2.169))
        pathPath5.addLine(to: CGPoint(x: 3.38, y: 1.893))
        pathPath5.addCurve(to: CGPoint(x: 3.08, y: 1.123), control1: CGPoint(x: 3.396, y: 1.605), control2: CGPoint(x: 3.286, y: 1.324))
        pathPath5.addLine(to: CGPoint(x: 3.08, y: 1.123))
        pathPath5.addCurve(to: CGPoint(x: 2.25, y: 0.833), control1: CGPoint(x: 2.856, y: 0.914), control2: CGPoint(x: 2.555, y: 0.809))
        pathPath5.addLine(to: CGPoint(x: 1, y: 0.833))
        pathPath5.closeSubpath()
        pathPath5.move(to: CGPoint(x: 1, y: 2.893))

        let pathPath6 = CGMutablePath()
        pathPath6.move(to: CGPoint(x: 2.771, y: 4.472))
        pathPath6.addLine(to: CGPoint(x: 2.771, y: 4.472))
        pathPath6.addCurve(to: CGPoint(x: 2.651, y: 4.062), control1: CGPoint(x: 2.713, y: 4.341), control2: CGPoint(x: 2.673, y: 4.203))
        pathPath6.addLine(to: CGPoint(x: 2.651, y: 4.062))
        pathPath6.addCurve(to: CGPoint(x: 1.501, y: 4.562), control1: CGPoint(x: 2.359, y: 4.387), control2: CGPoint(x: 1.939, y: 4.57))
        pathPath6.addLine(to: CGPoint(x: 1.501, y: 4.562))
        pathPath6.addCurve(to: CGPoint(x: 0.421, y: 4.182), control1: CGPoint(x: 1.106, y: 4.577), control2: CGPoint(x: 0.72, y: 4.441))
        pathPath6.addLine(to: CGPoint(x: 0.421, y: 4.182))
        pathPath6.addCurve(to: CGPoint(x: 0.001, y: 3.252), control1: CGPoint(x: 0.15, y: 3.95), control2: CGPoint(x: -0.004, y: 3.609))
        pathPath6.addLine(to: CGPoint(x: 0.001, y: 3.252))
        pathPath6.addCurve(to: CGPoint(x: 0.531, y: 2.172), control1: CGPoint(x: -0.018, y: 2.825), control2: CGPoint(x: 0.182, y: 2.418))
        pathPath6.addLine(to: CGPoint(x: 0.531, y: 2.172))
        pathPath6.addCurve(to: CGPoint(x: 2.021, y: 1.802), control1: CGPoint(x: 0.977, y: 1.895), control2: CGPoint(x: 1.498, y: 1.766))
        pathPath6.addLine(to: CGPoint(x: 2.621, y: 1.802))
        pathPath6.addLine(to: CGPoint(x: 2.621, y: 1.502))
        pathPath6.addLine(to: CGPoint(x: 2.621, y: 1.502))
        pathPath6.addCurve(to: CGPoint(x: 2.431, y: 0.952), control1: CGPoint(x: 2.632, y: 1.301), control2: CGPoint(x: 2.564, y: 1.103))
        pathPath6.addLine(to: CGPoint(x: 2.431, y: 0.952))
        pathPath6.addCurve(to: CGPoint(x: 1.851, y: 0.752), control1: CGPoint(x: 2.273, y: 0.809), control2: CGPoint(x: 2.064, y: 0.737))
        pathPath6.addLine(to: CGPoint(x: 1.851, y: 0.752))
        pathPath6.addCurve(to: CGPoint(x: 1.301, y: 0.922), control1: CGPoint(x: 1.653, y: 0.74), control2: CGPoint(x: 1.458, y: 0.801))
        pathPath6.addLine(to: CGPoint(x: 1.301, y: 0.922))
        pathPath6.addCurve(to: CGPoint(x: 1.081, y: 1.342), control1: CGPoint(x: 1.165, y: 1.018), control2: CGPoint(x: 1.083, y: 1.175))
        pathPath6.addLine(to: CGPoint(x: 0.081, y: 1.342))
        pathPath6.addLine(to: CGPoint(x: 0.081, y: 1.342))
        pathPath6.addCurve(to: CGPoint(x: 0.321, y: 0.672), control1: CGPoint(x: 0.083, y: 1.098), control2: CGPoint(x: 0.168, y: 0.862))
        pathPath6.addLine(to: CGPoint(x: 0.321, y: 0.672))
        pathPath6.addCurve(to: CGPoint(x: 0.971, y: 0.172), control1: CGPoint(x: 0.49, y: 0.451), control2: CGPoint(x: 0.714, y: 0.279))
        pathPath6.addLine(to: CGPoint(x: 0.971, y: 0.172))
        pathPath6.addCurve(to: CGPoint(x: 1.891, y: 0.002), control1: CGPoint(x: 1.264, y: 0.056), control2: CGPoint(x: 1.577, y: -0.001))
        pathPath6.addLine(to: CGPoint(x: 1.891, y: 0.002))
        pathPath6.addCurve(to: CGPoint(x: 3.121, y: 0.382), control1: CGPoint(x: 2.333, y: -0.018), control2: CGPoint(x: 2.768, y: 0.116))
        pathPath6.addLine(to: CGPoint(x: 3.121, y: 0.382))
        pathPath6.addCurve(to: CGPoint(x: 3.591, y: 1.472), control1: CGPoint(x: 3.43, y: 0.659), control2: CGPoint(x: 3.601, y: 1.057))
        pathPath6.addLine(to: CGPoint(x: 3.591, y: 3.472))
        pathPath6.addLine(to: CGPoint(x: 3.591, y: 3.472))
        pathPath6.addCurve(to: CGPoint(x: 3.751, y: 4.472), control1: CGPoint(x: 3.569, y: 3.813), control2: CGPoint(x: 3.624, y: 4.155))
        pathPath6.addLine(to: CGPoint(x: 3.751, y: 4.542))
        pathPath6.closeSubpath()
        pathPath6.move(to: CGPoint(x: 1.681, y: 3.762))
        pathPath6.addLine(to: CGPoint(x: 1.681, y: 3.762))
        pathPath6.addCurve(to: CGPoint(x: 2.251, y: 3.622), control1: CGPoint(x: 1.88, y: 3.765), control2: CGPoint(x: 2.077, y: 3.717))
        pathPath6.addLine(to: CGPoint(x: 2.251, y: 3.622))
        pathPath6.addCurve(to: CGPoint(x: 2.641, y: 3.232), control1: CGPoint(x: 2.418, y: 3.535), control2: CGPoint(x: 2.554, y: 3.399))
        pathPath6.addLine(to: CGPoint(x: 2.641, y: 2.412))
        pathPath6.addLine(to: CGPoint(x: 2.111, y: 2.412))
        pathPath6.addLine(to: CGPoint(x: 2.111, y: 2.412))
        pathPath6.addCurve(to: CGPoint(x: 1.251, y: 2.562), control1: CGPoint(x: 1.816, y: 2.37), control2: CGPoint(x: 1.515, y: 2.423))
        pathPath6.addLine(to: CGPoint(x: 1.251, y: 2.562))
        pathPath6.addCurve(to: CGPoint(x: 0.971, y: 3.102), control1: CGPoint(x: 1.065, y: 2.676), control2: CGPoint(x: 0.958, y: 2.884))
        pathPath6.addLine(to: CGPoint(x: 0.971, y: 3.102))
        pathPath6.addCurve(to: CGPoint(x: 1.161, y: 3.552), control1: CGPoint(x: 0.961, y: 3.273), control2: CGPoint(x: 1.031, y: 3.44))
        pathPath6.addLine(to: CGPoint(x: 1.161, y: 3.552))
        pathPath6.addCurve(to: CGPoint(x: 1.681, y: 3.762), control1: CGPoint(x: 1.3, y: 3.688), control2: CGPoint(x: 1.487, y: 3.763))
        pathPath6.closeSubpath()
        pathPath6.move(to: CGPoint(x: 1.681, y: 3.762))

        let pathPath7 = CGMutablePath()
        pathPath7.move(to: CGPoint(x: 2.74, y: 3.272))
        pathPath7.addLine(to: CGPoint(x: 2.74, y: 3.272))
        pathPath7.addCurve(to: CGPoint(x: 2.52, y: 2.872), control1: CGPoint(x: 2.745, y: 3.108), control2: CGPoint(x: 2.661, y: 2.955))
        pathPath7.addLine(to: CGPoint(x: 2.52, y: 2.872))
        pathPath7.addCurve(to: CGPoint(x: 1.8, y: 2.632), control1: CGPoint(x: 2.295, y: 2.752), control2: CGPoint(x: 2.052, y: 2.671))
        pathPath7.addLine(to: CGPoint(x: 1.8, y: 2.632))
        pathPath7.addCurve(to: CGPoint(x: 0.96, y: 2.362), control1: CGPoint(x: 1.51, y: 2.575), control2: CGPoint(x: 1.228, y: 2.484))
        pathPath7.addLine(to: CGPoint(x: 0.96, y: 2.362))
        pathPath7.addCurve(to: CGPoint(x: 0.22, y: 1.362), control1: CGPoint(x: 0.534, y: 2.209), control2: CGPoint(x: 0.242, y: 1.814))
        pathPath7.addLine(to: CGPoint(x: 0.22, y: 1.362))
        pathPath7.addCurve(to: CGPoint(x: 0.7, y: 0.412), control1: CGPoint(x: 0.222, y: 0.987), control2: CGPoint(x: 0.399, y: 0.635))
        pathPath7.addLine(to: CGPoint(x: 0.7, y: 0.412))
        pathPath7.addCurve(to: CGPoint(x: 1.89, y: 0.002), control1: CGPoint(x: 1.037, y: 0.142), control2: CGPoint(x: 1.458, y: -0.003))
        pathPath7.addLine(to: CGPoint(x: 1.89, y: 0.002))
        pathPath7.addCurve(to: CGPoint(x: 3.16, y: 0.392), control1: CGPoint(x: 2.345, y: -0.017), control2: CGPoint(x: 2.793, y: 0.121))
        pathPath7.addLine(to: CGPoint(x: 3.16, y: 0.392))
        pathPath7.addCurve(to: CGPoint(x: 3.65, y: 1.392), control1: CGPoint(x: 3.476, y: 0.626), control2: CGPoint(x: 3.659, y: 0.998))
        pathPath7.addLine(to: CGPoint(x: 2.65, y: 1.392))
        pathPath7.addLine(to: CGPoint(x: 2.65, y: 1.392))
        pathPath7.addCurve(to: CGPoint(x: 2.44, y: 0.912), control1: CGPoint(x: 2.653, y: 1.209), control2: CGPoint(x: 2.576, y: 1.034))
        pathPath7.addLine(to: CGPoint(x: 2.44, y: 0.912))
        pathPath7.addCurve(to: CGPoint(x: 1.89, y: 0.732), control1: CGPoint(x: 2.284, y: 0.788), control2: CGPoint(x: 2.089, y: 0.725))
        pathPath7.addLine(to: CGPoint(x: 1.89, y: 0.732))
        pathPath7.addCurve(to: CGPoint(x: 1.36, y: 0.882), control1: CGPoint(x: 1.702, y: 0.724), control2: CGPoint(x: 1.516, y: 0.776))
        pathPath7.addLine(to: CGPoint(x: 1.36, y: 0.882))
        pathPath7.addCurve(to: CGPoint(x: 1.16, y: 1.292), control1: CGPoint(x: 1.231, y: 0.978), control2: CGPoint(x: 1.157, y: 1.131))
        pathPath7.addLine(to: CGPoint(x: 1.16, y: 1.292))
        pathPath7.addCurve(to: CGPoint(x: 1.35, y: 1.642), control1: CGPoint(x: 1.155, y: 1.434), control2: CGPoint(x: 1.227, y: 1.569))
        pathPath7.addLine(to: CGPoint(x: 1.35, y: 1.642))
        pathPath7.addCurve(to: CGPoint(x: 2.12, y: 1.892), control1: CGPoint(x: 1.591, y: 1.766), control2: CGPoint(x: 1.851, y: 1.851))
        pathPath7.addLine(to: CGPoint(x: 2.12, y: 1.892))
        pathPath7.addCurve(to: CGPoint(x: 3.03, y: 2.202), control1: CGPoint(x: 2.436, y: 1.955), control2: CGPoint(x: 2.742, y: 2.059))
        pathPath7.addLine(to: CGPoint(x: 3.03, y: 2.202))
        pathPath7.addCurve(to: CGPoint(x: 3.52, y: 2.622), control1: CGPoint(x: 3.224, y: 2.301), control2: CGPoint(x: 3.392, y: 2.445))
        pathPath7.addLine(to: CGPoint(x: 3.52, y: 2.622))
        pathPath7.addCurve(to: CGPoint(x: 3.68, y: 3.222), control1: CGPoint(x: 3.631, y: 2.802), control2: CGPoint(x: 3.687, y: 3.01))
        pathPath7.addLine(to: CGPoint(x: 3.68, y: 3.222))
        pathPath7.addCurve(to: CGPoint(x: 3.19, y: 4.222), control1: CGPoint(x: 3.706, y: 3.618), control2: CGPoint(x: 3.519, y: 3.999))
        pathPath7.addLine(to: CGPoint(x: 3.19, y: 4.222))
        pathPath7.addCurve(to: CGPoint(x: 1.89, y: 4.562), control1: CGPoint(x: 2.806, y: 4.476), control2: CGPoint(x: 2.349, y: 4.595))
        pathPath7.addLine(to: CGPoint(x: 1.89, y: 4.562))
        pathPath7.addCurve(to: CGPoint(x: 0.89, y: 4.362), control1: CGPoint(x: 1.546, y: 4.572), control2: CGPoint(x: 1.204, y: 4.504))
        pathPath7.addLine(to: CGPoint(x: 0.89, y: 4.362))
        pathPath7.addCurve(to: CGPoint(x: 0.23, y: 3.832), control1: CGPoint(x: 0.626, y: 4.248), control2: CGPoint(x: 0.398, y: 4.065))
        pathPath7.addLine(to: CGPoint(x: 0.23, y: 3.832))
        pathPath7.addCurve(to: CGPoint(x: 0, y: 3.092), control1: CGPoint(x: 0.081, y: 3.614), control2: CGPoint(x: 0.001, y: 3.356))
        pathPath7.addLine(to: CGPoint(x: 1, y: 3.092))
        pathPath7.addLine(to: CGPoint(x: 1, y: 3.092))
        pathPath7.addCurve(to: CGPoint(x: 1.26, y: 3.632), control1: CGPoint(x: 0.997, y: 3.303), control2: CGPoint(x: 1.093, y: 3.503))
        pathPath7.addLine(to: CGPoint(x: 1.26, y: 3.632))
        pathPath7.addCurve(to: CGPoint(x: 2.5, y: 3.672), control1: CGPoint(x: 1.635, y: 3.87), control2: CGPoint(x: 2.11, y: 3.885))
        pathPath7.addLine(to: CGPoint(x: 2.5, y: 3.672))
        pathPath7.addCurve(to: CGPoint(x: 2.74, y: 3.272), control1: CGPoint(x: 2.645, y: 3.59), control2: CGPoint(x: 2.736, y: 3.438))
        pathPath7.closeSubpath()
        pathPath7.move(to: CGPoint(x: 2.74, y: 3.272))

        let pathPath8 = CGMutablePath()
        pathPath8.move(to: CGPoint(x: 2.7, y: 3.242))
        pathPath8.addLine(to: CGPoint(x: 2.7, y: 3.242))
        pathPath8.addCurve(to: CGPoint(x: 2.48, y: 2.842), control1: CGPoint(x: 2.705, y: 3.079), control2: CGPoint(x: 2.621, y: 2.926))
        pathPath8.addLine(to: CGPoint(x: 2.48, y: 2.842))
        pathPath8.addCurve(to: CGPoint(x: 1.76, y: 2.602), control1: CGPoint(x: 2.255, y: 2.722), control2: CGPoint(x: 2.012, y: 2.641))
        pathPath8.addLine(to: CGPoint(x: 1.76, y: 2.602))
        pathPath8.addCurve(to: CGPoint(x: 0.92, y: 2.332), control1: CGPoint(x: 1.47, y: 2.545), control2: CGPoint(x: 1.188, y: 2.455))
        pathPath8.addLine(to: CGPoint(x: 0.92, y: 2.332))
        pathPath8.addCurve(to: CGPoint(x: 0.18, y: 1.332), control1: CGPoint(x: 0.494, y: 2.179), control2: CGPoint(x: 0.202, y: 1.784))
        pathPath8.addLine(to: CGPoint(x: 0.18, y: 1.332))
        pathPath8.addCurve(to: CGPoint(x: 0.66, y: 0.382), control1: CGPoint(x: 0.177, y: 0.956), control2: CGPoint(x: 0.356, y: 0.602))
        pathPath8.addLine(to: CGPoint(x: 0.66, y: 0.382))
        pathPath8.addCurve(to: CGPoint(x: 1.88, y: 0.002), control1: CGPoint(x: 1.009, y: 0.116), control2: CGPoint(x: 1.441, y: -0.018))
        pathPath8.addLine(to: CGPoint(x: 1.88, y: 0.002))
        pathPath8.addCurve(to: CGPoint(x: 3.15, y: 0.392), control1: CGPoint(x: 2.335, y: -0.016), control2: CGPoint(x: 2.783, y: 0.121))
        pathPath8.addLine(to: CGPoint(x: 3.15, y: 0.392))
        pathPath8.addCurve(to: CGPoint(x: 3.64, y: 1.392), control1: CGPoint(x: 3.466, y: 0.626), control2: CGPoint(x: 3.649, y: 0.999))
        pathPath8.addLine(to: CGPoint(x: 2.64, y: 1.392))
        pathPath8.addLine(to: CGPoint(x: 2.64, y: 1.392))
        pathPath8.addCurve(to: CGPoint(x: 2.43, y: 0.912), control1: CGPoint(x: 2.643, y: 1.209), control2: CGPoint(x: 2.566, y: 1.034))
        pathPath8.addLine(to: CGPoint(x: 2.43, y: 0.912))
        pathPath8.addCurve(to: CGPoint(x: 1.87, y: 0.722), control1: CGPoint(x: 2.273, y: 0.783), control2: CGPoint(x: 2.074, y: 0.715))
        pathPath8.addLine(to: CGPoint(x: 1.87, y: 0.722))
        pathPath8.addCurve(to: CGPoint(x: 1.34, y: 0.872), control1: CGPoint(x: 1.682, y: 0.714), control2: CGPoint(x: 1.496, y: 0.767))
        pathPath8.addLine(to: CGPoint(x: 1.34, y: 0.872))
        pathPath8.addCurve(to: CGPoint(x: 1.14, y: 1.282), control1: CGPoint(x: 1.207, y: 0.965), control2: CGPoint(x: 1.131, y: 1.12))
        pathPath8.addLine(to: CGPoint(x: 1.14, y: 1.282))
        pathPath8.addCurve(to: CGPoint(x: 1.33, y: 1.632), control1: CGPoint(x: 1.134, y: 1.425), control2: CGPoint(x: 1.207, y: 1.559))
        pathPath8.addLine(to: CGPoint(x: 1.33, y: 1.632))
        pathPath8.addCurve(to: CGPoint(x: 2.1, y: 1.882), control1: CGPoint(x: 1.571, y: 1.757), control2: CGPoint(x: 1.831, y: 1.841))
        pathPath8.addLine(to: CGPoint(x: 2.1, y: 1.882))
        pathPath8.addCurve(to: CGPoint(x: 3.01, y: 2.192), control1: CGPoint(x: 2.415, y: 1.947), control2: CGPoint(x: 2.721, y: 2.051))
        pathPath8.addLine(to: CGPoint(x: 3.01, y: 2.192))
        pathPath8.addCurve(to: CGPoint(x: 3.5, y: 2.612), control1: CGPoint(x: 3.204, y: 2.291), control2: CGPoint(x: 3.372, y: 2.435))
        pathPath8.addLine(to: CGPoint(x: 3.5, y: 2.612))
        pathPath8.addCurve(to: CGPoint(x: 3.66, y: 3.212), control1: CGPoint(x: 3.611, y: 2.792), control2: CGPoint(x: 3.667, y: 3.001))
        pathPath8.addLine(to: CGPoint(x: 3.66, y: 3.212))
        pathPath8.addCurve(to: CGPoint(x: 3.17, y: 4.212), control1: CGPoint(x: 3.686, y: 3.609), control2: CGPoint(x: 3.499, y: 3.989))
        pathPath8.addLine(to: CGPoint(x: 3.17, y: 4.212))
        pathPath8.addCurve(to: CGPoint(x: 1.89, y: 4.532), control1: CGPoint(x: 2.789, y: 4.455), control2: CGPoint(x: 2.34, y: 4.567))
        pathPath8.addLine(to: CGPoint(x: 1.89, y: 4.532))
        pathPath8.addCurve(to: CGPoint(x: 0.89, y: 4.332), control1: CGPoint(x: 1.546, y: 4.542), control2: CGPoint(x: 1.204, y: 4.474))
        pathPath8.addLine(to: CGPoint(x: 0.89, y: 4.332))
        pathPath8.addCurve(to: CGPoint(x: 0.23, y: 3.802), control1: CGPoint(x: 0.626, y: 4.218), control2: CGPoint(x: 0.398, y: 4.035))
        pathPath8.addLine(to: CGPoint(x: 0.23, y: 3.802))
        pathPath8.addCurve(to: CGPoint(x: 0, y: 3.062), control1: CGPoint(x: 0.081, y: 3.584), control2: CGPoint(x: 0.001, y: 3.326))
        pathPath8.addLine(to: CGPoint(x: 1, y: 3.062))
        pathPath8.addLine(to: CGPoint(x: 1, y: 3.062))
        pathPath8.addCurve(to: CGPoint(x: 1.26, y: 3.602), control1: CGPoint(x: 0.997, y: 3.273), control2: CGPoint(x: 1.093, y: 3.473))
        pathPath8.addLine(to: CGPoint(x: 1.26, y: 3.602))
        pathPath8.addCurve(to: CGPoint(x: 2.5, y: 3.642), control1: CGPoint(x: 1.635, y: 3.84), control2: CGPoint(x: 2.11, y: 3.856))
        pathPath8.addLine(to: CGPoint(x: 2.5, y: 3.642))
        pathPath8.addCurve(to: CGPoint(x: 2.7, y: 3.242), control1: CGPoint(x: 2.63, y: 3.551), control2: CGPoint(x: 2.705, y: 3.401))
        pathPath8.closeSubpath()
        pathPath8.move(to: CGPoint(x: 2.7, y: 3.242))

        let pathPath9 = CGMutablePath()
        pathPath9.move(to: CGPoint(x: 3.81, y: 2.322))
        pathPath9.addLine(to: CGPoint(x: 3.81, y: 2.322))
        pathPath9.addCurve(to: CGPoint(x: 3.35, y: 3.942), control1: CGPoint(x: 3.842, y: 2.899), control2: CGPoint(x: 3.68, y: 3.469))
        pathPath9.addLine(to: CGPoint(x: 3.35, y: 3.942))
        pathPath9.addCurve(to: CGPoint(x: 2.11, y: 4.562), control1: CGPoint(x: 3.066, y: 4.343), control2: CGPoint(x: 2.601, y: 4.576))
        pathPath9.addLine(to: CGPoint(x: 2.11, y: 4.562))
        pathPath9.addCurve(to: CGPoint(x: 1, y: 4.072), control1: CGPoint(x: 1.687, y: 4.564), control2: CGPoint(x: 1.284, y: 4.386))
        pathPath9.addLine(to: CGPoint(x: 1, y: 6.162))
        pathPath9.addLine(to: CGPoint(x: 0, y: 6.162))
        pathPath9.addLine(to: CGPoint(x: 0, y: 0.082))
        pathPath9.addLine(to: CGPoint(x: 0.91, y: 0.082))
        pathPath9.addLine(to: CGPoint(x: 0.91, y: 0.522))
        pathPath9.addLine(to: CGPoint(x: 0.91, y: 0.522))
        pathPath9.addCurve(to: CGPoint(x: 2.09, y: 0.002), control1: CGPoint(x: 1.199, y: 0.173), control2: CGPoint(x: 1.637, y: -0.02))
        pathPath9.addLine(to: CGPoint(x: 2.09, y: 0.002))
        pathPath9.addCurve(to: CGPoint(x: 3.36, y: 0.562), control1: CGPoint(x: 2.579, y: -0.025), control2: CGPoint(x: 3.051, y: 0.183))
        pathPath9.addLine(to: CGPoint(x: 3.36, y: 0.562))
        pathPath9.addCurve(to: CGPoint(x: 3.81, y: 2.232), control1: CGPoint(x: 3.686, y: 1.056), control2: CGPoint(x: 3.844, y: 1.642))
        pathPath9.closeSubpath()
        pathPath9.move(to: CGPoint(x: 2.81, y: 2.232))
        pathPath9.addLine(to: CGPoint(x: 2.81, y: 2.232))
        pathPath9.addCurve(to: CGPoint(x: 2.55, y: 1.232), control1: CGPoint(x: 2.82, y: 1.881), control2: CGPoint(x: 2.729, y: 1.534))
        pathPath9.addLine(to: CGPoint(x: 2.55, y: 1.232))
        pathPath9.addCurve(to: CGPoint(x: 1.8, y: 0.842), control1: CGPoint(x: 2.386, y: 0.98), control2: CGPoint(x: 2.101, y: 0.832))
        pathPath9.addLine(to: CGPoint(x: 1.8, y: 0.842))
        pathPath9.addCurve(to: CGPoint(x: 0.93, y: 1.342), control1: CGPoint(x: 1.437, y: 0.822), control2: CGPoint(x: 1.096, y: 1.018))
        pathPath9.addLine(to: CGPoint(x: 0.93, y: 3.342))
        pathPath9.addLine(to: CGPoint(x: 0.93, y: 3.342))
        pathPath9.addCurve(to: CGPoint(x: 1.81, y: 3.852), control1: CGPoint(x: 1.094, y: 3.674), control2: CGPoint(x: 1.441, y: 3.875))
        pathPath9.addLine(to: CGPoint(x: 1.81, y: 3.852))
        pathPath9.addCurve(to: CGPoint(x: 2.55, y: 3.472), control1: CGPoint(x: 2.106, y: 3.863), control2: CGPoint(x: 2.386, y: 3.719))
        pathPath9.addLine(to: CGPoint(x: 2.55, y: 3.472))
        pathPath9.addCurve(to: CGPoint(x: 2.83, y: 2.232), control1: CGPoint(x: 2.772, y: 3.099), control2: CGPoint(x: 2.87, y: 2.665))
        pathPath9.closeSubpath()
        pathPath9.move(to: CGPoint(x: 2.81, y: 2.232))

        let pathPath10 = CGMutablePath()
        pathPath10.move(to: CGPoint(x: 0.023, y: 2.232))
        pathPath10.addLine(to: CGPoint(x: 0.023, y: 2.232))
        pathPath10.addCurve(to: CGPoint(x: 0.283, y: 1.072), control1: CGPoint(x: 0.018, y: 1.83), control2: CGPoint(x: 0.107, y: 1.433))
        pathPath10.addLine(to: CGPoint(x: 0.283, y: 1.072))
        pathPath10.addCurve(to: CGPoint(x: 1.003, y: 0.272), control1: CGPoint(x: 0.439, y: 0.74), control2: CGPoint(x: 0.69, y: 0.462))
        pathPath10.addLine(to: CGPoint(x: 1.003, y: 0.272))
        pathPath10.addCurve(to: CGPoint(x: 2.063, y: 0.002), control1: CGPoint(x: 1.324, y: 0.085), control2: CGPoint(x: 1.691, y: -0.008))
        pathPath10.addLine(to: CGPoint(x: 2.063, y: 0.002))
        pathPath10.addCurve(to: CGPoint(x: 3.503, y: 0.562), control1: CGPoint(x: 2.6, y: -0.021), control2: CGPoint(x: 3.122, y: 0.182))
        pathPath10.addLine(to: CGPoint(x: 3.503, y: 0.562))
        pathPath10.addCurve(to: CGPoint(x: 4.103, y: 2.082), control1: CGPoint(x: 3.886, y: 0.975), control2: CGPoint(x: 4.1, y: 1.518))
        pathPath10.addLine(to: CGPoint(x: 4.103, y: 2.312))
        pathPath10.addLine(to: CGPoint(x: 4.103, y: 2.312))
        pathPath10.addCurve(to: CGPoint(x: 3.853, y: 3.472), control1: CGPoint(x: 4.111, y: 2.713), control2: CGPoint(x: 4.026, y: 3.11))
        pathPath10.addLine(to: CGPoint(x: 3.853, y: 3.472))
        pathPath10.addCurve(to: CGPoint(x: 3.143, y: 4.262), control1: CGPoint(x: 3.701, y: 3.8), control2: CGPoint(x: 3.453, y: 4.075))
        pathPath10.addLine(to: CGPoint(x: 3.143, y: 4.262))
        pathPath10.addCurve(to: CGPoint(x: 2.073, y: 4.562), control1: CGPoint(x: 2.822, y: 4.461), control2: CGPoint(x: 2.451, y: 4.565))
        pathPath10.addLine(to: CGPoint(x: 2.073, y: 4.562))
        pathPath10.addCurve(to: CGPoint(x: 0.563, y: 3.932), control1: CGPoint(x: 1.501, y: 4.587), control2: CGPoint(x: 0.947, y: 4.356))
        pathPath10.addLine(to: CGPoint(x: 0.563, y: 3.932))
        pathPath10.addCurve(to: CGPoint(x: 0.003, y: 2.282), control1: CGPoint(x: 0.173, y: 3.473), control2: CGPoint(x: -0.027, y: 2.883))
        pathPath10.closeSubpath()
        pathPath10.move(to: CGPoint(x: 1.023, y: 2.322))
        pathPath10.addLine(to: CGPoint(x: 1.023, y: 2.322))
        pathPath10.addCurve(to: CGPoint(x: 1.303, y: 3.382), control1: CGPoint(x: 1, y: 2.696), control2: CGPoint(x: 1.098, y: 3.068))
        pathPath10.addLine(to: CGPoint(x: 1.303, y: 3.382))
        pathPath10.addCurve(to: CGPoint(x: 2.083, y: 3.762), control1: CGPoint(x: 1.483, y: 3.631), control2: CGPoint(x: 1.776, y: 3.773))
        pathPath10.addLine(to: CGPoint(x: 2.083, y: 3.762))
        pathPath10.addCurve(to: CGPoint(x: 2.853, y: 3.372), control1: CGPoint(x: 2.39, y: 3.775), control2: CGPoint(x: 2.682, y: 3.627))
        pathPath10.addLine(to: CGPoint(x: 2.853, y: 3.372))
        pathPath10.addCurve(to: CGPoint(x: 3.133, y: 2.232), control1: CGPoint(x: 3.063, y: 3.03), control2: CGPoint(x: 3.161, y: 2.632))
        pathPath10.addLine(to: CGPoint(x: 3.133, y: 2.232))
        pathPath10.addCurve(to: CGPoint(x: 2.853, y: 1.232), control1: CGPoint(x: 3.144, y: 1.878), control2: CGPoint(x: 3.046, y: 1.529))
        pathPath10.addLine(to: CGPoint(x: 2.853, y: 1.232))
        pathPath10.addCurve(to: CGPoint(x: 1.446, y: 1.089), control1: CGPoint(x: 2.504, y: 0.804), control2: CGPoint(x: 1.874, y: 0.74))
        pathPath10.addCurve(to: CGPoint(x: 1.303, y: 1.232), control1: CGPoint(x: 1.394, y: 1.131), control2: CGPoint(x: 1.346, y: 1.179))
        pathPath10.addLine(to: CGPoint(x: 1.303, y: 1.232))
        pathPath10.addCurve(to: CGPoint(x: 1.013, y: 2.322), control1: CGPoint(x: 1.1, y: 1.558), control2: CGPoint(x: 0.999, y: 1.938))
        pathPath10.closeSubpath()
        pathPath10.move(to: CGPoint(x: 1.023, y: 2.322))

        let pathPath11 = CGMutablePath()
        pathPath11.move(to: CGPoint(x: 2.32, y: 0.98))
        pathPath11.addLine(to: CGPoint(x: 2.32, y: 0.98))
        pathPath11.addCurve(to: CGPoint(x: 1.91, y: 0.98), control1: CGPoint(x: 2.184, y: 0.97), control2: CGPoint(x: 2.046, y: 0.97))
        pathPath11.addLine(to: CGPoint(x: 1.91, y: 0.98))
        pathPath11.addCurve(to: CGPoint(x: 1, y: 1.5), control1: CGPoint(x: 1.527, y: 0.941), control2: CGPoint(x: 1.161, y: 1.15))
        pathPath11.addLine(to: CGPoint(x: 1, y: 4.5))
        pathPath11.addLine(to: CGPoint(x: 0, y: 4.5))
        pathPath11.addLine(to: CGPoint(x: 0, y: 0.08))
        pathPath11.addLine(to: CGPoint(x: 0.94, y: 0.08))
        pathPath11.addLine(to: CGPoint(x: 0.94, y: 0.57))
        pathPath11.addLine(to: CGPoint(x: 0.94, y: 0.57))
        pathPath11.addCurve(to: CGPoint(x: 2.29, y: 0.05), control1: CGPoint(x: 1.219, y: 0.109), control2: CGPoint(x: 1.774, y: -0.105))
        pathPath11.closeSubpath()
        pathPath11.move(to: CGPoint(x: 2.32, y: 0.98))

        let pathPath12 = CGMutablePath()
        pathPath12.move(to: CGPoint(x: 1.74, y: 0))
        pathPath12.addLine(to: CGPoint(x: 1.74, y: 1.07))
        pathPath12.addLine(to: CGPoint(x: 2.51, y: 1.07))
        pathPath12.addLine(to: CGPoint(x: 2.51, y: 1.8))
        pathPath12.addLine(to: CGPoint(x: 1.74, y: 1.8))
        pathPath12.addLine(to: CGPoint(x: 1.74, y: 4.25))
        pathPath12.addLine(to: CGPoint(x: 1.74, y: 4.25))
        pathPath12.addCurve(to: CGPoint(x: 1.84, y: 4.61), control1: CGPoint(x: 1.726, y: 4.378), control2: CGPoint(x: 1.761, y: 4.507))
        pathPath12.addLine(to: CGPoint(x: 1.84, y: 4.61))
        pathPath12.addCurve(to: CGPoint(x: 2.19, y: 4.72), control1: CGPoint(x: 1.934, y: 4.698), control2: CGPoint(x: 2.063, y: 4.739))
        pathPath12.addLine(to: CGPoint(x: 2.19, y: 4.72))
        pathPath12.addCurve(to: CGPoint(x: 2.54, y: 4.72), control1: CGPoint(x: 2.306, y: 4.735), control2: CGPoint(x: 2.424, y: 4.735))
        pathPath12.addLine(to: CGPoint(x: 2.54, y: 5.45))
        pathPath12.addLine(to: CGPoint(x: 2.54, y: 5.45))
        pathPath12.addCurve(to: CGPoint(x: 1.89, y: 5.54), control1: CGPoint(x: 2.328, y: 5.508), control2: CGPoint(x: 2.11, y: 5.538))
        pathPath12.addCurve(to: CGPoint(x: 0.75, y: 4.28), control1: CGPoint(x: 0.75, y: 5.54), control2: CGPoint(x: 0.75, y: 5.54))
        pathPath12.addLine(to: CGPoint(x: 0.75, y: 1.8))
        pathPath12.addLine(to: CGPoint(x: 0, y: 1.8))
        pathPath12.addLine(to: CGPoint(x: 0, y: 1.07))
        pathPath12.addLine(to: CGPoint(x: 0.72, y: 1.07))
        pathPath12.addLine(to: CGPoint(x: 0.72, y: 0))
        pathPath12.closeSubpath()
        pathPath12.move(to: CGPoint(x: 1.74, y: 0))

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

        let ellipsePath = CGMutablePath()
        ellipsePath.move(to: CGPoint(x: 46.736, y: 23.368))
        ellipsePath.addCurve(to: CGPoint(x: 23.368, y: 46.736), control1: CGPoint(x: 46.736, y: 36.273998), control2: CGPoint(x: 36.273998, y: 46.736))
        ellipsePath.addCurve(to: CGPoint(x: 0, y: 23.368), control1: CGPoint(x: 10.462, y: 46.736), control2: CGPoint(x: 0, y: 36.273998))
        ellipsePath.addCurve(to: CGPoint(x: 23.368, y: 0), control1: CGPoint(x: 0, y: 10.462), control2: CGPoint(x: 10.462, y: 0))
        ellipsePath.addCurve(to: CGPoint(x: 46.736, y: 23.368), control1: CGPoint(x: 36.273998, y: 0), control2: CGPoint(x: 46.736, y: 10.462))
        ellipsePath.closeSubpath()
        ellipsePath.move(to: CGPoint(x: 46.736, y: 23.368))

        let ellipsePath1 = CGMutablePath()
        ellipsePath1.move(to: CGPoint(x: 32.375999, y: 16.188))
        ellipsePath1.addCurve(to: CGPoint(x: 16.188, y: 32.375999), control1: CGPoint(x: 32.375999, y: 25.128), control2: CGPoint(x: 25.128, y: 32.375999))
        ellipsePath1.addCurve(to: CGPoint(x: 0, y: 16.188), control1: CGPoint(x: 7.248, y: 32.375999), control2: CGPoint(x: 0, y: 25.128))
        ellipsePath1.addCurve(to: CGPoint(x: 16.188, y: 0), control1: CGPoint(x: 0, y: 7.248), control2: CGPoint(x: 7.248, y: 0))
        ellipsePath1.addCurve(to: CGPoint(x: 32.375999, y: 16.188), control1: CGPoint(x: 25.128, y: 0), control2: CGPoint(x: 32.375999, y: 7.248))
        ellipsePath1.closeSubpath()
        ellipsePath1.move(to: CGPoint(x: 32.375999, y: 16.188))

        let ellipsePath2 = CGMutablePath()
        ellipsePath2.move(to: CGPoint(x: 18.634001, y: 9.317))
        ellipsePath2.addCurve(to: CGPoint(x: 9.317, y: 18.634001), control1: CGPoint(x: 18.634001, y: 14.463), control2: CGPoint(x: 14.463, y: 18.634001))
        ellipsePath2.addCurve(to: CGPoint(x: 0, y: 9.317), control1: CGPoint(x: 4.171, y: 18.634001), control2: CGPoint(x: 0, y: 14.463))
        ellipsePath2.addCurve(to: CGPoint(x: 9.317, y: 0), control1: CGPoint(x: 0, y: 4.171), control2: CGPoint(x: 4.171, y: 0))
        ellipsePath2.addCurve(to: CGPoint(x: 18.634001, y: 9.317), control1: CGPoint(x: 14.463, y: 0), control2: CGPoint(x: 18.634001, y: 4.171))
        ellipsePath2.closeSubpath()
        ellipsePath2.move(to: CGPoint(x: 18.634001, y: 9.317))

        let pathPath13 = CGMutablePath()
        pathPath13.move(to: CGPoint(x: 7.928, y: 14.613))
        pathPath13.addLine(to: CGPoint(x: 7.928, y: 14.613))
        pathPath13.addCurve(to: CGPoint(x: 3.001, y: 28.450001), control1: CGPoint(x: 8.046, y: 19.674), control2: CGPoint(x: 6.292, y: 24.601999))
        pathPath13.addLine(to: CGPoint(x: 3.001, y: 28.450001))
        pathPath13.addCurve(to: CGPoint(x: 1.801, y: 29.757), control1: CGPoint(x: 2.627, y: 28.908001), control2: CGPoint(x: 2.226, y: 29.344999))
        pathPath13.addCurve(to: CGPoint(x: 0.286, y: 29.921), control1: CGPoint(x: 1.266, y: 30.268999), control2: CGPoint(x: 0.693, y: 30.308001))
        pathPath13.addCurve(to: CGPoint(x: 0.476, y: 28.447001), control1: CGPoint(x: -0.145, y: 29.507999), control2: CGPoint(x: -0.093, y: 29.045))
        pathPath13.addLine(to: CGPoint(x: 0.476, y: 28.447001))
        pathPath13.addCurve(to: CGPoint(x: 0.729, y: 2.022), control1: CGPoint(x: 7.727, y: 21.171), control2: CGPoint(x: 7.84, y: 9.435))
        pathPath13.addCurve(to: CGPoint(x: 0.395, y: 1.679), control1: CGPoint(x: 0.621, y: 1.904), control2: CGPoint(x: 0.504, y: 1.796))
        pathPath13.addCurve(to: CGPoint(x: 0.269, y: 0.307), control1: CGPoint(x: -0.09, y: 1.158), control2: CGPoint(x: -0.13, y: 0.71))
        pathPath13.addLine(to: CGPoint(x: 0.269, y: 0.307))
        pathPath13.addCurve(to: CGPoint(x: 1.671, y: 0.276), control1: CGPoint(x: 0.648, y: -0.089), control2: CGPoint(x: 1.276, y: -0.103))
        pathPath13.addCurve(to: CGPoint(x: 1.779, y: 0.397), control1: CGPoint(x: 1.711, y: 0.313), control2: CGPoint(x: 1.746, y: 0.353))
        pathPath13.addLine(to: CGPoint(x: 1.779, y: 0.397))
        pathPath13.addCurve(to: CGPoint(x: 4.491, y: 3.797), control1: CGPoint(x: 2.753, y: 1.472), control2: CGPoint(x: 3.659, y: 2.608))
        pathPath13.addLine(to: CGPoint(x: 4.491, y: 3.797))
        pathPath13.addCurve(to: CGPoint(x: 7.928, y: 14.613), control1: CGPoint(x: 6.635, y: 7.005), control2: CGPoint(x: 7.827, y: 10.755))
        pathPath13.closeSubpath()
        pathPath13.move(to: CGPoint(x: 7.928, y: 14.613))

        let pathPath14 = CGMutablePath()
        pathPath14.move(to: CGPoint(x: 6.362, y: 11.393))
        pathPath14.addLine(to: CGPoint(x: 6.362, y: 11.393))
        pathPath14.addCurve(to: CGPoint(x: 2.1, y: 21.856001), control1: CGPoint(x: 6.295, y: 15.29), control2: CGPoint(x: 4.775, y: 19.021))
        pathPath14.addCurve(to: CGPoint(x: 1.716, y: 22.243), control1: CGPoint(x: 1.975, y: 21.989), control2: CGPoint(x: 1.851, y: 22.122))
        pathPath14.addLine(to: CGPoint(x: 1.716, y: 22.243))
        pathPath14.addCurve(to: CGPoint(x: 0.283, y: 22.358), control1: CGPoint(x: 1.352, y: 22.67), control2: CGPoint(x: 0.71, y: 22.722))
        pathPath14.addCurve(to: CGPoint(x: 0.253, y: 22.332001), control1: CGPoint(x: 0.273, y: 22.349001), control2: CGPoint(x: 0.263, y: 22.341))
        pathPath14.addCurve(to: CGPoint(x: 0.415, y: 20.893999), control1: CGPoint(x: -0.131, y: 21.957001), control2: CGPoint(x: -0.078, y: 21.399))
        pathPath14.addLine(to: CGPoint(x: 0.415, y: 20.893999))
        pathPath14.addCurve(to: CGPoint(x: 4.408, y: 11.423), control1: CGPoint(x: 2.962, y: 18.399), control2: CGPoint(x: 4.4, y: 14.987))
        pathPath14.addLine(to: CGPoint(x: 4.408, y: 11.423))
        pathPath14.addCurve(to: CGPoint(x: 0.624, y: 1.929), control1: CGPoint(x: 4.445, y: 7.884), control2: CGPoint(x: 3.086, y: 4.472))
        pathPath14.addCurve(to: CGPoint(x: 0.386, y: 1.686), control1: CGPoint(x: 0.547, y: 1.845), control2: CGPoint(x: 0.463, y: 1.768))
        pathPath14.addCurve(to: CGPoint(x: 0.235, y: 0.299), control1: CGPoint(x: -0.068, y: 1.204), control2: CGPoint(x: -0.124, y: 0.669))
        pathPath14.addLine(to: CGPoint(x: 0.235, y: 0.299))
        pathPath14.addCurve(to: CGPoint(x: 1.606, y: 0.271), control1: CGPoint(x: 0.606, y: -0.087), control2: CGPoint(x: 1.22, y: -0.1))
        pathPath14.addCurve(to: CGPoint(x: 1.689, y: 0.363), control1: CGPoint(x: 1.635, y: 0.3), control2: CGPoint(x: 1.663, y: 0.33))
        pathPath14.addLine(to: CGPoint(x: 1.689, y: 0.363))
        pathPath14.addCurve(to: CGPoint(x: 3.589, y: 2.585), control1: CGPoint(x: 2.376, y: 1.056), control2: CGPoint(x: 3.011, y: 1.798))
        pathPath14.addLine(to: CGPoint(x: 3.589, y: 2.585))
        pathPath14.addCurve(to: CGPoint(x: 6.362, y: 11.393), control1: CGPoint(x: 5.435, y: 5.147), control2: CGPoint(x: 6.408, y: 8.235))
        pathPath14.closeSubpath()
        pathPath14.move(to: CGPoint(x: 6.362, y: 11.393))

        let pathPath15 = CGMutablePath()
        pathPath15.move(to: CGPoint(x: 4.934, y: 7.856))
        pathPath15.addLine(to: CGPoint(x: 4.934, y: 7.856))
        pathPath15.addCurve(to: CGPoint(x: 1.866, y: 14.977), control1: CGPoint(x: 4.884, y: 10.54), control2: CGPoint(x: 3.783, y: 13.097))
        pathPath15.addCurve(to: CGPoint(x: 1.666, y: 15.164), control1: CGPoint(x: 1.802, y: 15.041), control2: CGPoint(x: 1.738, y: 15.105))
        pathPath15.addLine(to: CGPoint(x: 1.666, y: 15.164))
        pathPath15.addCurve(to: CGPoint(x: 0.311, y: 15.247), control1: CGPoint(x: 1.315, y: 15.561), control2: CGPoint(x: 0.708, y: 15.598))
        pathPath15.addCurve(to: CGPoint(x: 0.266, y: 15.205), control1: CGPoint(x: 0.296, y: 15.233), control2: CGPoint(x: 0.281, y: 15.219))
        pathPath15.addLine(to: CGPoint(x: 0.266, y: 15.205))
        pathPath15.addCurve(to: CGPoint(x: 0.291, y: 13.883), control1: CGPoint(x: -0.092, y: 14.833), control2: CGPoint(x: -0.081, y: 14.241))
        pathPath15.addCurve(to: CGPoint(x: 0.366, y: 13.818), control1: CGPoint(x: 0.315, y: 13.86), control2: CGPoint(x: 0.34, y: 13.838))
        pathPath15.addLine(to: CGPoint(x: 0.366, y: 13.818))
        pathPath15.addCurve(to: CGPoint(x: 0.679, y: 2.007), control1: CGPoint(x: 3.677, y: 10.626), control2: CGPoint(x: 3.817, y: 5.369))
        pathPath15.addCurve(to: CGPoint(x: 0.217, y: 1.507), control1: CGPoint(x: 0.528, y: 1.838), control2: CGPoint(x: 0.351, y: 1.689))
        pathPath15.addLine(to: CGPoint(x: 0.217, y: 1.507))
        pathPath15.addCurve(to: CGPoint(x: 0.349, y: 0.216), control1: CGPoint(x: -0.103, y: 1.114), control2: CGPoint(x: -0.044, y: 0.536))
        pathPath15.addCurve(to: CGPoint(x: 1.404, y: 0.144), control1: CGPoint(x: 0.65, y: -0.029), control2: CGPoint(x: 1.072, y: -0.058))
        pathPath15.addLine(to: CGPoint(x: 1.404, y: 0.144))
        pathPath15.addCurve(to: CGPoint(x: 2.022, y: 0.672), control1: CGPoint(x: 1.63, y: 0.295), control2: CGPoint(x: 1.838, y: 0.472))
        pathPath15.addLine(to: CGPoint(x: 2.022, y: 0.672))
        pathPath15.addCurve(to: CGPoint(x: 4.934, y: 7.856), control1: CGPoint(x: 3.898, y: 2.592), control2: CGPoint(x: 4.943, y: 5.172))
        pathPath15.closeSubpath()
        pathPath15.move(to: CGPoint(x: 4.934, y: 7.856))

        let pathPath16 = CGMutablePath()
        pathPath16.move(to: CGPoint(x: 3.7, y: 4.748))
        pathPath16.addLine(to: CGPoint(x: 3.7, y: 4.748))
        pathPath16.addCurve(to: CGPoint(x: 1.79, y: 8.611), control1: CGPoint(x: 3.667, y: 6.255), control2: CGPoint(x: 2.967, y: 7.669))
        pathPath16.addLine(to: CGPoint(x: 1.79, y: 8.611))
        pathPath16.addCurve(to: CGPoint(x: 0.677, y: 8.926), control1: CGPoint(x: 1.475, y: 8.858), control2: CGPoint(x: 1.075, y: 8.971))
        pathPath16.addCurve(to: CGPoint(x: 0.362, y: 7.403), control1: CGPoint(x: -0.072, y: 8.798), control2: CGPoint(x: -0.231, y: 7.977))
        pathPath16.addLine(to: CGPoint(x: 0.362, y: 7.403))
        pathPath16.addCurve(to: CGPoint(x: 1.662, y: 5.391), control1: CGPoint(x: 0.992, y: 6.882), control2: CGPoint(x: 1.446, y: 6.179))
        pathPath16.addLine(to: CGPoint(x: 1.662, y: 5.391))
        pathPath16.addCurve(to: CGPoint(x: 0.798, y: 2.105), control1: CGPoint(x: 1.916, y: 4.221), control2: CGPoint(x: 1.595, y: 2.999))
        pathPath16.addCurve(to: CGPoint(x: 0.426, y: 1.705), control1: CGPoint(x: 0.687, y: 1.962), control2: CGPoint(x: 0.544, y: 1.846))
        pathPath16.addCurve(to: CGPoint(x: 0.308, y: 0.259), control1: CGPoint(x: -0.061, y: 1.136), control2: CGPoint(x: -0.097, y: 0.662))
        pathPath16.addLine(to: CGPoint(x: 0.308, y: 0.259))
        pathPath16.addCurve(to: CGPoint(x: 1.773, y: 0.358), control1: CGPoint(x: 0.74, y: -0.118), control2: CGPoint(x: 1.396, y: -0.074))
        pathPath16.addCurve(to: CGPoint(x: 1.774, y: 0.359), control1: CGPoint(x: 1.773, y: 0.358), control2: CGPoint(x: 1.774, y: 0.359))
        pathPath16.addLine(to: CGPoint(x: 1.774, y: 0.359))
        pathPath16.addCurve(to: CGPoint(x: 3.7, y: 4.748), control1: CGPoint(x: 3.02, y: 1.475), control2: CGPoint(x: 3.722, y: 3.076))
        pathPath16.closeSubpath()
        pathPath16.move(to: CGPoint(x: 3.7, y: 4.748))

        // Closed Passport
        //
        let closedPassportLayer = CALayer()
        closedPassportLayer.name = "Closed Passport"
        closedPassportLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
        closedPassportLayer.position = CGPoint(x: 68.854599, y: 21.900787)
        closedPassportLayer.anchorPoint = CGPoint(x: 0, y: 0)
        closedPassportLayer.contentsGravity = .center
        closedPassportLayer.shadowOffset = CGSize(width: 0, height: 1)
        closedPassportLayer.allowsEdgeAntialiasing = true
        closedPassportLayer.allowsGroupOpacity = true
        closedPassportLayer.fillMode = .forwards

            // Closed Passport Animations
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
            opacityAnimation.values = [ 0, 1, 1, 0 ]
            opacityAnimation.keyTimes = [ 0.0089, 0.0585, 0.167083, 0.229924 ]
            opacityAnimation.calculationMode = .linear

            closedPassportLayer.add(opacityAnimation, forKey: "opacityAnimation")

            // Closed Passport Sublayers
            //

            // Group 12
            //
            let groupLayer = CALayer()
            groupLayer.name = "Group 12"
            groupLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
            groupLayer.position = CGPoint(x: 0, y: 0)
            groupLayer.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer.contentsGravity = .center
            groupLayer.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer.allowsEdgeAntialiasing = true
            groupLayer.allowsGroupOpacity = true
            groupLayer.fillMode = .forwards

                // Group 12 Sublayers
                //

                // Red
                //
                let redLayer = CALayer()
                redLayer.name = "Red"
                redLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
                redLayer.position = CGPoint(x: 0, y: 0)
                redLayer.anchorPoint = CGPoint(x: 0, y: 0)
                redLayer.contentsGravity = .center
                redLayer.backgroundColor = backgroundColor.cgColor
                redLayer.cornerRadius = 7
        if #available(iOS 11.0, *) {
            redLayer.maskedCorners = CACornerMask([.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                redLayer.shadowOffset = CGSize(width: 0, height: 1)
                redLayer.allowsEdgeAntialiasing = true
                redLayer.allowsGroupOpacity = true
                redLayer.fillMode = .forwards

                    // Red Sublayers
                    //

                    // Blue
                    //
                    let blueLayer = CALayer()
                    blueLayer.name = "Blue"
                    blueLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
                    blueLayer.position = CGPoint(x: 0, y: 0)
                    blueLayer.anchorPoint = CGPoint(x: 0, y: 0)
                    blueLayer.contentsGravity = .center
                    blueLayer.isHidden = true
                    blueLayer.backgroundColor = backgroundColor1.cgColor
                    blueLayer.cornerRadius = 7
        if #available(iOS 11.0, *) {
            blueLayer.maskedCorners = CACornerMask([.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                    blueLayer.shadowOffset = CGSize(width: 0, height: 1)
                    blueLayer.allowsEdgeAntialiasing = true
                    blueLayer.allowsGroupOpacity = true
                    blueLayer.fillMode = .forwards

                        // Blue Sublayers
                        //

                        // Black
                        //
                        let blackLayer = CALayer()
                        blackLayer.name = "Black"
                        blackLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
                        blackLayer.position = CGPoint(x: 0, y: 0)
                        blackLayer.anchorPoint = CGPoint(x: 0, y: 0)
                        blackLayer.contentsGravity = .center
                        blackLayer.backgroundColor = backgroundColor2.cgColor
                        blackLayer.cornerRadius = 7
        if #available(iOS 11.0, *) {
            blackLayer.maskedCorners = CACornerMask([.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                        blackLayer.shadowOffset = CGSize(width: 0, height: 1)
                        blackLayer.allowsEdgeAntialiasing = true
                        blackLayer.allowsGroupOpacity = true
                        blackLayer.fillMode = .forwards

                            // Black Sublayers
                            //

                            // Green
                            //
                            let greenLayer = CALayer()
                            greenLayer.name = "Green"
                            greenLayer.bounds = CGRect(x: 0, y: 0, width: 97.290802, height: 136.198425)
                            greenLayer.position = CGPoint(x: 0, y: 0)
                            greenLayer.anchorPoint = CGPoint(x: 0, y: 0)
                            greenLayer.contentsGravity = .center
                            greenLayer.backgroundColor = backgroundColor3.cgColor
                            greenLayer.cornerRadius = 7
        if #available(iOS 11.0, *) {
            greenLayer.maskedCorners = CACornerMask([.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        } else {
            // Fallback on earlier versions
        }
                            greenLayer.shadowOffset = CGSize(width: 0, height: 1)
                            greenLayer.allowsEdgeAntialiasing = true
                            greenLayer.allowsGroupOpacity = true
                            greenLayer.fillMode = .forwards

                            blackLayer.addSublayer(greenLayer)

                        blueLayer.addSublayer(blackLayer)

                    redLayer.addSublayer(blueLayer)

                groupLayer.addSublayer(redLayer)

                // NFC logo
                //
                let nFCLogoLayer = CALayer()
                nFCLogoLayer.name = "NFC logo"
                nFCLogoLayer.bounds = CGRect(x: 0, y: 0, width: 14.7836, height: 8.965912)
                nFCLogoLayer.position = CGPoint(x: 41.253601, y: 113.505219)
                nFCLogoLayer.anchorPoint = CGPoint(x: 0, y: 0)
                nFCLogoLayer.contentsGravity = .center
                nFCLogoLayer.shadowOffset = CGSize(width: 0, height: 1)
                nFCLogoLayer.allowsEdgeAntialiasing = true
                nFCLogoLayer.allowsGroupOpacity = true
                nFCLogoLayer.fillMode = .forwards

                    // NFC logo Sublayers
                    //

                    // Path 5
                    //
                    let pathLayer = CAShapeLayer()
                    pathLayer.name = "Path 5"
                    pathLayer.bounds = CGRect(x: 0, y: 0, width: 14.7836, height: 3.917267)
                    pathLayer.position = CGPoint(x: 0, y: 0)
                    pathLayer.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer.contentsGravity = .center
                    pathLayer.backgroundColor = backgroundColor4.cgColor
                    pathLayer.borderColor = backgroundColor4.cgColor
                    pathLayer.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer.allowsEdgeAntialiasing = true
                    pathLayer.allowsGroupOpacity = true
                    pathLayer.fillMode = .forwards
                    pathLayer.path = pathPath
                    pathLayer.fillColor = fillColor.cgColor
                    pathLayer.strokeColor = strokeColor.cgColor
                    pathLayer.lineWidth = 0

                    nFCLogoLayer.addSublayer(pathLayer)

                    // Path 6
                    //
                    let pathLayer1 = CAShapeLayer()
                    pathLayer1.name = "Path 6"
                    pathLayer1.bounds = CGRect(x: 0, y: 0, width: 14.781952, height: 3.87793)
                    pathLayer1.position = CGPoint(x: 0.000824, y: 5.087982)
                    pathLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer1.contentsGravity = .center
                    pathLayer1.backgroundColor = backgroundColor4.cgColor
                    pathLayer1.borderColor = backgroundColor4.cgColor
                    pathLayer1.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer1.allowsEdgeAntialiasing = true
                    pathLayer1.allowsGroupOpacity = true
                    pathLayer1.fillMode = .forwards
                    pathLayer1.path = pathPath1
                    pathLayer1.fillColor = fillColor.cgColor
                    pathLayer1.strokeColor = strokeColor.cgColor
                    pathLayer1.lineWidth = 0

                    nFCLogoLayer.addSublayer(pathLayer1)

                    // Path 7
                    //
                    let pathLayer2 = CAShapeLayer()
                    pathLayer2.name = "Path 7"
                    pathLayer2.bounds = CGRect(x: 0, y: 0, width: 4.157318, height: 4.176361)
                    pathLayer2.position = CGPoint(x: 5.313141, y: 2.403809)
                    pathLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer2.contentsGravity = .center
                    pathLayer2.backgroundColor = backgroundColor4.cgColor
                    pathLayer2.borderColor = backgroundColor4.cgColor
                    pathLayer2.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer2.allowsEdgeAntialiasing = true
                    pathLayer2.allowsGroupOpacity = true
                    pathLayer2.fillMode = .forwards
                    pathLayer2.path = pathPath2
                    pathLayer2.fillColor = fillColor.cgColor
                    pathLayer2.strokeColor = strokeColor.cgColor
                    pathLayer2.lineWidth = 0

                    nFCLogoLayer.addSublayer(pathLayer2)

                groupLayer.addSublayer(nFCLogoLayer)

                // Globe
                //
                let globeLayer = CALayer()
                globeLayer.name = "Globe"
                globeLayer.bounds = CGRect(x: 0, y: 0, width: 52.614441, height: 52.598663)
                globeLayer.position = CGPoint(x: 22.338181, y: 36.402924)
                globeLayer.anchorPoint = CGPoint(x: 0, y: 0)
                globeLayer.contentsGravity = .center
                globeLayer.shadowOffset = CGSize(width: 0, height: 1)
                globeLayer.allowsEdgeAntialiasing = true
                globeLayer.allowsGroupOpacity = true
                globeLayer.fillMode = .forwards

                    // Globe Sublayers
                    //

                    // Path 8
                    //
                    let pathLayer3 = CAShapeLayer()
                    pathLayer3.name = "Path 8"
                    pathLayer3.bounds = CGRect(x: 0, y: 0, width: 52.614441, height: 52.598633)
                    pathLayer3.position = CGPoint(x: 0, y: 0.000015)
                    pathLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer3.contentsGravity = .center
                    pathLayer3.backgroundColor = backgroundColor4.cgColor
                    pathLayer3.borderColor = backgroundColor4.cgColor
                    pathLayer3.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer3.allowsEdgeAntialiasing = true
                    pathLayer3.allowsGroupOpacity = true
                    pathLayer3.fillMode = .forwards
                    pathLayer3.path = pathPath3
                    pathLayer3.fillColor = fillColor1.cgColor
                    pathLayer3.strokeColor = strokeColor.cgColor
                    pathLayer3.lineWidth = 0

                    globeLayer.addSublayer(pathLayer3)

                groupLayer.addSublayer(globeLayer)

            closedPassportLayer.addSublayer(groupLayer)

            // ePassport
            //
            let ePassportLayer = CALayer()
            ePassportLayer.name = "ePassport"
            ePassportLayer.bounds = CGRect(x: 0, y: 0, width: 64.54245, height: 13.602798)
            ePassportLayer.position = CGPoint(x: 7.574176, y: 11.099213)
            ePassportLayer.anchorPoint = CGPoint(x: 0, y: 0)
            ePassportLayer.contentsGravity = .center
            ePassportLayer.shadowOffset = CGSize(width: 0, height: 1)
            ePassportLayer.allowsEdgeAntialiasing = true
            ePassportLayer.allowsGroupOpacity = true
            ePassportLayer.fillMode = .forwards
            ePassportLayer.transform = CATransform3D( m11: 1, m12: 0, m13: 0, m14: 0,
                                                  m21: 0, m22: 1, m23: 0, m24: 0,
                                                  m31: 0, m32: 0, m33: 1, m34: 0,
                                                  m41: 8.8, m42: 3, m43: 0, m44: 1 )
            ePassportLayer.sublayerTransform = CATransform3D( m11: 1.7, m12: 0, m13: 0, m14: 0,
                                                          m21: 0, m22: 1.7, m23: 0, m24: 0,
                                                          m31: 0, m32: 0, m33: 1, m34: 0,
                                                          m41: 0, m42: 0, m43: 0, m44: 1 )

                // ePassport Sublayers
                //

                // Path 1
                //
                let pathLayer4 = CAShapeLayer()
                pathLayer4.name = "Path 1"
                pathLayer4.bounds = CGRect(x: 0, y: 0, width: 3.868011, height: 4.564224)
                pathLayer4.position = CGPoint(x: 0, y: 1.439484)
                pathLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer4.contentsGravity = .center
                pathLayer4.backgroundColor = backgroundColor4.cgColor
                pathLayer4.borderColor = backgroundColor4.cgColor
                pathLayer4.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer4.allowsEdgeAntialiasing = true
                pathLayer4.allowsGroupOpacity = true
                pathLayer4.fillMode = .forwards
                pathLayer4.path = pathPath4
                pathLayer4.fillColor = fillColor1.cgColor
                pathLayer4.strokeColor = strokeColor.cgColor
                pathLayer4.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer4)

                // Path 2
                //
                let pathLayer5 = CAShapeLayer()
                pathLayer5.name = "Path 2"
                pathLayer5.bounds = CGRect(x: 0, y: 0, width: 4.392502, height: 5.912796)
                pathLayer5.position = CGPoint(x: 4.752457, y: 0)
                pathLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer5.contentsGravity = .center
                pathLayer5.backgroundColor = backgroundColor4.cgColor
                pathLayer5.borderColor = backgroundColor4.cgColor
                pathLayer5.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer5.allowsEdgeAntialiasing = true
                pathLayer5.allowsGroupOpacity = true
                pathLayer5.fillMode = .forwards
                pathLayer5.path = pathPath5
                pathLayer5.fillColor = fillColor1.cgColor
                pathLayer5.strokeColor = strokeColor.cgColor
                pathLayer5.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer5)

                // Path 3
                //
                let pathLayer6 = CAShapeLayer()
                pathLayer6.name = "Path 3"
                pathLayer6.bounds = CGRect(x: 0, y: 0, width: 3.751312, height: 4.56311)
                pathLayer6.position = CGPoint(x: 9.751144, y: 1.440781)
                pathLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer6.contentsGravity = .center
                pathLayer6.backgroundColor = backgroundColor4.cgColor
                pathLayer6.borderColor = backgroundColor4.cgColor
                pathLayer6.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer6.allowsEdgeAntialiasing = true
                pathLayer6.allowsGroupOpacity = true
                pathLayer6.fillMode = .forwards
                pathLayer6.path = pathPath6
                pathLayer6.fillColor = fillColor1.cgColor
                pathLayer6.strokeColor = strokeColor.cgColor
                pathLayer6.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer6)

                // Path 4
                //
                let pathLayer7 = CAShapeLayer()
                pathLayer7.name = "Path 4"
                pathLayer7.bounds = CGRect(x: 0, y: 0, width: 3.682343, height: 4.5672)
                pathLayer7.position = CGPoint(x: 14.112457, y: 1.441147)
                pathLayer7.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer7.contentsGravity = .center
                pathLayer7.backgroundColor = backgroundColor4.cgColor
                pathLayer7.borderColor = backgroundColor4.cgColor
                pathLayer7.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer7.allowsEdgeAntialiasing = true
                pathLayer7.allowsGroupOpacity = true
                pathLayer7.fillMode = .forwards
                pathLayer7.path = pathPath7
                pathLayer7.fillColor = fillColor1.cgColor
                pathLayer7.strokeColor = strokeColor.cgColor
                pathLayer7.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer7)

                // Path 5
                //
                let pathLayer8 = CAShapeLayer()
                pathLayer8.name = "Path 5"
                pathLayer8.bounds = CGRect(x: 0, y: 0, width: 3.662338, height: 4.53833)
                pathLayer8.position = CGPoint(x: 18.442459, y: 1.470749)
                pathLayer8.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer8.contentsGravity = .center
                pathLayer8.backgroundColor = backgroundColor4.cgColor
                pathLayer8.borderColor = backgroundColor4.cgColor
                pathLayer8.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer8.allowsEdgeAntialiasing = true
                pathLayer8.allowsGroupOpacity = true
                pathLayer8.fillMode = .forwards
                pathLayer8.path = pathPath8
                pathLayer8.fillColor = fillColor1.cgColor
                pathLayer8.strokeColor = strokeColor.cgColor
                pathLayer8.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer8)

                // Path 6
                //
                let pathLayer9 = CAShapeLayer()
                pathLayer9.name = "Path 6"
                pathLayer9.bounds = CGRect(x: 0, y: 0, width: 3.814606, height: 6.162369)
                pathLayer9.position = CGPoint(x: 23.002441, y: 1.44043)
                pathLayer9.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer9.contentsGravity = .center
                pathLayer9.backgroundColor = backgroundColor4.cgColor
                pathLayer9.borderColor = backgroundColor4.cgColor
                pathLayer9.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer9.allowsEdgeAntialiasing = true
                pathLayer9.allowsGroupOpacity = true
                pathLayer9.fillMode = .forwards
                pathLayer9.path = pathPath9
                pathLayer9.fillColor = fillColor1.cgColor
                pathLayer9.strokeColor = strokeColor.cgColor
                pathLayer9.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer9)

                // Path 7
                //
                let pathLayer10 = CAShapeLayer()
                pathLayer10.name = "Path 7"
                pathLayer10.bounds = CGRect(x: 0, y: 0, width: 4.103424, height: 4.563736)
                pathLayer10.position = CGPoint(x: 27.439575, y: 1.440994)
                pathLayer10.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer10.contentsGravity = .center
                pathLayer10.backgroundColor = backgroundColor4.cgColor
                pathLayer10.borderColor = backgroundColor4.cgColor
                pathLayer10.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer10.allowsEdgeAntialiasing = true
                pathLayer10.allowsGroupOpacity = true
                pathLayer10.fillMode = .forwards
                pathLayer10.path = pathPath10
                pathLayer10.fillColor = fillColor1.cgColor
                pathLayer10.strokeColor = strokeColor.cgColor
                pathLayer10.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer10)

                // Path 8
                //
                let pathLayer11 = CAShapeLayer()
                pathLayer11.name = "Path 8"
                pathLayer11.bounds = CGRect(x: 0, y: 0, width: 2.320007, height: 4.500259)
                pathLayer11.position = CGPoint(x: 32.362457, y: 1.442535)
                pathLayer11.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer11.contentsGravity = .center
                pathLayer11.backgroundColor = backgroundColor4.cgColor
                pathLayer11.borderColor = backgroundColor4.cgColor
                pathLayer11.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer11.allowsEdgeAntialiasing = true
                pathLayer11.allowsGroupOpacity = true
                pathLayer11.fillMode = .forwards
                pathLayer11.path = pathPath11
                pathLayer11.fillColor = fillColor1.cgColor
                pathLayer11.strokeColor = strokeColor.cgColor
                pathLayer11.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer11)

                // Path 9
                //
                let pathLayer12 = CAShapeLayer()
                pathLayer12.name = "Path 9"
                pathLayer12.bounds = CGRect(x: 0, y: 0, width: 2.540009, height: 5.540009)
                pathLayer12.position = CGPoint(x: 35.002441, y: 0.452789)
                pathLayer12.anchorPoint = CGPoint(x: 0, y: 0)
                pathLayer12.contentsGravity = .center
                pathLayer12.backgroundColor = backgroundColor4.cgColor
                pathLayer12.borderColor = backgroundColor4.cgColor
                pathLayer12.shadowOffset = CGSize(width: 0, height: 1)
                pathLayer12.allowsEdgeAntialiasing = true
                pathLayer12.allowsGroupOpacity = true
                pathLayer12.fillMode = .forwards
                pathLayer12.path = pathPath12
                pathLayer12.fillColor = fillColor1.cgColor
                pathLayer12.strokeColor = strokeColor.cgColor
                pathLayer12.lineWidth = 0

                ePassportLayer.addSublayer(pathLayer12)

            closedPassportLayer.addSublayer(ePassportLayer)

        self.layer.addSublayer(closedPassportLayer)

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

            // Openned Passport Animations
            //

            // opacity
            //
            let opacityAnimation1 = CAKeyframeAnimation()
            opacityAnimation1.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            opacityAnimation1.duration = 6
            opacityAnimation1.repeatCount = 100
            opacityAnimation1.fillMode = .backwards
            opacityAnimation1.isRemovedOnCompletion = false
            opacityAnimation1.keyPath = "opacity"
            opacityAnimation1.values = [ 0, 1, 1, 0 ]
            opacityAnimation1.keyTimes = [ 0.229924, 0.2954, 0.94456, 1 ]
            opacityAnimation1.calculationMode = .linear

            opennedPassportLayer.add(opacityAnimation1, forKey: "opacityAnimation1")

            // Openned Passport Sublayers
            //

            // Group 9
            //
            let groupLayer1 = CALayer()
            groupLayer1.name = "Group 9"
            groupLayer1.bounds = CGRect(x: 0, y: 0, width: 195.149231, height: 136.198486)
            groupLayer1.position = CGPoint(x: 0, y: 0)
            groupLayer1.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer1.contentsGravity = .center
            groupLayer1.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer1.allowsEdgeAntialiasing = true
            groupLayer1.allowsGroupOpacity = true
            groupLayer1.fillMode = .forwards

                // Group 9 Sublayers
                //

                // Group 6
                //
                let groupLayer2 = CALayer()
                groupLayer2.name = "Group 6"
                groupLayer2.bounds = CGRect(x: 0, y: 0, width: 195.149231, height: 136.198486)
                groupLayer2.position = CGPoint(x: 0, y: 0)
                groupLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer2.contentsGravity = .center
                groupLayer2.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer2.allowsEdgeAntialiasing = true
                groupLayer2.allowsGroupOpacity = true
                groupLayer2.fillMode = .forwards

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
                    rectangleLayer.backgroundColor = backgroundColor5.cgColor
                    rectangleLayer.cornerRadius = 5
                    rectangleLayer.shadowOffset = CGSize(width: 0, height: 1)
                    rectangleLayer.allowsEdgeAntialiasing = true
                    rectangleLayer.allowsGroupOpacity = true
                    rectangleLayer.fillMode = .forwards

                    groupLayer2.addSublayer(rectangleLayer)

                    // Group 5
                    //
                    let groupLayer3 = CALayer()
                    groupLayer3.name = "Group 5"
                    groupLayer3.bounds = CGRect(x: 0, y: 0, width: 97.290833, height: 136.198456)
                    groupLayer3.position = CGPoint(x: 97.858398, y: 0.000031)
                    groupLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                    groupLayer3.contentsGravity = .center
                    groupLayer3.shadowOffset = CGSize(width: 0, height: 1)
                    groupLayer3.allowsEdgeAntialiasing = true
                    groupLayer3.allowsGroupOpacity = true
                    groupLayer3.fillMode = .forwards

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
                        rectangleLayer1.backgroundColor = backgroundColor5.cgColor
                        rectangleLayer1.cornerRadius = 5
                        rectangleLayer1.shadowOffset = CGSize(width: 0, height: 1)
                        rectangleLayer1.allowsEdgeAntialiasing = true
                        rectangleLayer1.allowsGroupOpacity = true
                        rectangleLayer1.fillMode = .forwards

                        groupLayer3.addSublayer(rectangleLayer1)

                    groupLayer2.addSublayer(groupLayer3)

                groupLayer1.addSublayer(groupLayer2)

                // Group 7
                //
                let groupLayer4 = CALayer()
                groupLayer4.name = "Group 7"
                groupLayer4.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 26.003601)
                groupLayer4.position = CGPoint(x: 19.765137, y: 22.376282)
                groupLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer4.contentsGravity = .center
                groupLayer4.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer4.allowsEdgeAntialiasing = true
                groupLayer4.allowsGroupOpacity = true
                groupLayer4.fillMode = .forwards

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
                    lineLayer.backgroundColor = backgroundColor4.cgColor
                    lineLayer.borderColor = backgroundColor4.cgColor
                    lineLayer.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer.allowsEdgeAntialiasing = true
                    lineLayer.allowsGroupOpacity = true
                    lineLayer.fillMode = .forwards
                    lineLayer.path = linePath
                    lineLayer.fillColor = backgroundColor4.cgColor
                    lineLayer.strokeColor = strokeColor1.cgColor
                    lineLayer.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer)

                    // Line 2
                    //
                    let lineLayer1 = CAShapeLayer()
                    lineLayer1.name = "Line 2"
                    lineLayer1.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer1.position = CGPoint(x: 0, y: 8.667877)
                    lineLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer1.contentsGravity = .center
                    lineLayer1.backgroundColor = backgroundColor4.cgColor
                    lineLayer1.borderColor = backgroundColor4.cgColor
                    lineLayer1.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer1.allowsEdgeAntialiasing = true
                    lineLayer1.allowsGroupOpacity = true
                    lineLayer1.fillMode = .forwards
                    lineLayer1.path = linePath1
                    lineLayer1.fillColor = backgroundColor4.cgColor
                    lineLayer1.strokeColor = strokeColor1.cgColor
                    lineLayer1.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer1)

                    // Line 3
                    //
                    let lineLayer2 = CAShapeLayer()
                    lineLayer2.name = "Line 3"
                    lineLayer2.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer2.position = CGPoint(x: 0, y: 17.335724)
                    lineLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer2.contentsGravity = .center
                    lineLayer2.backgroundColor = backgroundColor4.cgColor
                    lineLayer2.borderColor = backgroundColor4.cgColor
                    lineLayer2.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer2.allowsEdgeAntialiasing = true
                    lineLayer2.allowsGroupOpacity = true
                    lineLayer2.fillMode = .forwards
                    lineLayer2.path = linePath2
                    lineLayer2.fillColor = backgroundColor4.cgColor
                    lineLayer2.strokeColor = strokeColor1.cgColor
                    lineLayer2.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer2)

                    // Line 4
                    //
                    let lineLayer3 = CAShapeLayer()
                    lineLayer3.name = "Line 4"
                    lineLayer3.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer3.position = CGPoint(x: 0, y: 26.003601)
                    lineLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer3.contentsGravity = .center
                    lineLayer3.backgroundColor = backgroundColor4.cgColor
                    lineLayer3.borderColor = backgroundColor4.cgColor
                    lineLayer3.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer3.allowsEdgeAntialiasing = true
                    lineLayer3.allowsGroupOpacity = true
                    lineLayer3.fillMode = .forwards
                    lineLayer3.path = linePath3
                    lineLayer3.fillColor = backgroundColor4.cgColor
                    lineLayer3.strokeColor = strokeColor1.cgColor
                    lineLayer3.lineWidth = 1

                    groupLayer4.addSublayer(lineLayer3)

                groupLayer1.addSublayer(groupLayer4)

                // Group 8
                //
                let groupLayer5 = CALayer()
                groupLayer5.name = "Group 8"
                groupLayer5.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 26.003632)
                groupLayer5.position = CGPoint(x: 18.119324, y: 87.85083)
                groupLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer5.contentsGravity = .center
                groupLayer5.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer5.allowsEdgeAntialiasing = true
                groupLayer5.allowsGroupOpacity = true
                groupLayer5.fillMode = .forwards

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
                    lineLayer4.backgroundColor = backgroundColor4.cgColor
                    lineLayer4.borderColor = backgroundColor4.cgColor
                    lineLayer4.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer4.allowsEdgeAntialiasing = true
                    lineLayer4.allowsGroupOpacity = true
                    lineLayer4.fillMode = .forwards
                    lineLayer4.path = linePath4
                    lineLayer4.fillColor = backgroundColor4.cgColor
                    lineLayer4.strokeColor = strokeColor1.cgColor
                    lineLayer4.lineWidth = 1

                    groupLayer5.addSublayer(lineLayer4)

                    // Line 6
                    //
                    let lineLayer5 = CAShapeLayer()
                    lineLayer5.name = "Line 6"
                    lineLayer5.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer5.position = CGPoint(x: 0, y: 8.667847)
                    lineLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer5.contentsGravity = .center
                    lineLayer5.backgroundColor = backgroundColor4.cgColor
                    lineLayer5.borderColor = backgroundColor4.cgColor
                    lineLayer5.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer5.allowsEdgeAntialiasing = true
                    lineLayer5.allowsGroupOpacity = true
                    lineLayer5.fillMode = .forwards
                    lineLayer5.path = linePath5
                    lineLayer5.fillColor = backgroundColor4.cgColor
                    lineLayer5.strokeColor = strokeColor1.cgColor
                    lineLayer5.lineWidth = 1

                    groupLayer5.addSublayer(lineLayer5)

                    // Line 7
                    //
                    let lineLayer6 = CAShapeLayer()
                    lineLayer6.name = "Line 7"
                    lineLayer6.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer6.position = CGPoint(x: 0, y: 17.335754)
                    lineLayer6.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer6.contentsGravity = .center
                    lineLayer6.backgroundColor = backgroundColor4.cgColor
                    lineLayer6.borderColor = backgroundColor4.cgColor
                    lineLayer6.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer6.allowsEdgeAntialiasing = true
                    lineLayer6.allowsGroupOpacity = true
                    lineLayer6.fillMode = .forwards
                    lineLayer6.path = linePath6
                    lineLayer6.fillColor = backgroundColor4.cgColor
                    lineLayer6.strokeColor = strokeColor1.cgColor
                    lineLayer6.lineWidth = 1

                    groupLayer5.addSublayer(lineLayer6)

                    // Line 8
                    //
                    let lineLayer7 = CAShapeLayer()
                    lineLayer7.name = "Line 8"
                    lineLayer7.bounds = CGRect(x: 0, y: 0, width: 60.943542, height: 0)
                    lineLayer7.position = CGPoint(x: 0, y: 26.003632)
                    lineLayer7.anchorPoint = CGPoint(x: 0, y: 0)
                    lineLayer7.contentsGravity = .center
                    lineLayer7.backgroundColor = backgroundColor4.cgColor
                    lineLayer7.borderColor = backgroundColor4.cgColor
                    lineLayer7.shadowOffset = CGSize(width: 0, height: 1)
                    lineLayer7.allowsEdgeAntialiasing = true
                    lineLayer7.allowsGroupOpacity = true
                    lineLayer7.fillMode = .forwards
                    lineLayer7.path = linePath7
                    lineLayer7.fillColor = backgroundColor4.cgColor
                    lineLayer7.strokeColor = strokeColor1.cgColor
                    lineLayer7.lineWidth = 1

                    groupLayer5.addSublayer(lineLayer7)

                groupLayer1.addSublayer(groupLayer5)

            opennedPassportLayer.addSublayer(groupLayer1)

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
            middleLineLayer.fillColor = fillColor2.cgColor
            middleLineLayer.strokeColor = strokeColor2.cgColor
            middleLineLayer.lineWidth = 1

            opennedPassportLayer.addSublayer(middleLineLayer)

            // Group 15
            //
            let groupLayer6 = CALayer()
            groupLayer6.name = "Group 15"
            groupLayer6.bounds = CGRect(x: 0, y: 0, width: 46.736572, height: 46.736481)
            groupLayer6.position = CGPoint(x: 123.701416, y: 27.631775)
            groupLayer6.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer6.contentsGravity = .center
            groupLayer6.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer6.allowsEdgeAntialiasing = true
            groupLayer6.allowsGroupOpacity = true
            groupLayer6.fillMode = .forwards

                // Group 15 Sublayers
                //

                // Ellipse 1
                //
                let ellipseLayer = CAShapeLayer()
                ellipseLayer.name = "Ellipse 1"
                ellipseLayer.bounds = CGRect(x: 0, y: 0, width: 46.736572, height: 46.736481)
                ellipseLayer.position = CGPoint(x: 0, y: 0)
                ellipseLayer.anchorPoint = CGPoint(x: 0, y: 0)
                ellipseLayer.contentsGravity = .center
                ellipseLayer.backgroundColor = backgroundColor4.cgColor
                ellipseLayer.borderColor = backgroundColor4.cgColor
                ellipseLayer.shadowOffset = CGSize(width: 0, height: 1)
                ellipseLayer.allowsEdgeAntialiasing = true
                ellipseLayer.allowsGroupOpacity = true
                ellipseLayer.fillMode = .forwards

                    // Ellipse 1 Animations
                    //

                    // opacity
                    //
                    let opacityAnimation2 = CAKeyframeAnimation()
                    opacityAnimation2.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000125
                    opacityAnimation2.duration = 5.999875
                    opacityAnimation2.repeatCount = 100
                    opacityAnimation2.fillMode = .backwards
                    opacityAnimation2.isRemovedOnCompletion = false
                    opacityAnimation2.keyPath = "opacity"
                    opacityAnimation2.values = [ 0, 1, 0, 1, 0 ]
                    opacityAnimation2.keyTimes = [ 0.3229, 0.3826, 0.504156, 0.6067, 0.667076 ]
                    opacityAnimation2.calculationMode = .linear

                    ellipseLayer.add(opacityAnimation2, forKey: "opacityAnimation2")
                ellipseLayer.path = ellipsePath
                ellipseLayer.fillColor = fillColor3.cgColor
                ellipseLayer.strokeColor = strokeColor.cgColor
                ellipseLayer.lineWidth = 0

                groupLayer6.addSublayer(ellipseLayer)

                // Ellipse 2
                //
                let ellipseLayer1 = CAShapeLayer()
                ellipseLayer1.name = "Ellipse 2"
                ellipseLayer1.bounds = CGRect(x: 0, y: 0, width: 32.375244, height: 32.375366)
                ellipseLayer1.position = CGPoint(x: 7.180664, y: 7.180542)
                ellipseLayer1.anchorPoint = CGPoint(x: 0, y: 0)
                ellipseLayer1.contentsGravity = .center
                ellipseLayer1.backgroundColor = backgroundColor4.cgColor
                ellipseLayer1.borderColor = backgroundColor4.cgColor
                ellipseLayer1.shadowOffset = CGSize(width: 0, height: 1)
                ellipseLayer1.allowsEdgeAntialiasing = true
                ellipseLayer1.allowsGroupOpacity = true
                ellipseLayer1.fillMode = .forwards

                    // Ellipse 2 Animations
                    //

                    // opacity
                    //
                    let opacityAnimation3 = CAKeyframeAnimation()
                    opacityAnimation3.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000125
                    opacityAnimation3.duration = 5.999875
                    opacityAnimation3.repeatCount = 100
                    opacityAnimation3.fillMode = .backwards
                    opacityAnimation3.isRemovedOnCompletion = false
                    opacityAnimation3.keyPath = "opacity"
                    opacityAnimation3.values = [ 0, 1, 0, 1, 0 ]
                    opacityAnimation3.keyTimes = [ 0.2735, 0.333617, 0.4604, 0.5717, 0.6296 ]
                    opacityAnimation3.calculationMode = .linear

                    ellipseLayer1.add(opacityAnimation3, forKey: "opacityAnimation3")
                ellipseLayer1.path = ellipsePath1
                ellipseLayer1.fillColor = fillColor4.cgColor
                ellipseLayer1.strokeColor = strokeColor.cgColor
                ellipseLayer1.lineWidth = 0

                groupLayer6.addSublayer(ellipseLayer1)

                // Ellipse 3
                //
                let ellipseLayer2 = CAShapeLayer()
                ellipseLayer2.name = "Ellipse 3"
                ellipseLayer2.bounds = CGRect(x: 0, y: 0, width: 18.633057, height: 18.633087)
                ellipseLayer2.position = CGPoint(x: 14.051758, y: 14.051697)
                ellipseLayer2.anchorPoint = CGPoint(x: 0, y: 0)
                ellipseLayer2.contentsGravity = .center
                ellipseLayer2.backgroundColor = backgroundColor4.cgColor
                ellipseLayer2.borderColor = backgroundColor4.cgColor
                ellipseLayer2.shadowOffset = CGSize(width: 0, height: 1)
                ellipseLayer2.allowsEdgeAntialiasing = true
                ellipseLayer2.allowsGroupOpacity = true
                ellipseLayer2.fillMode = .forwards

                    // Ellipse 3 Animations
                    //

                    // opacity
                    //
                    let opacityAnimation4 = CAKeyframeAnimation()
                    opacityAnimation4.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000125
                    opacityAnimation4.duration = 5.999875
                    opacityAnimation4.repeatCount = 100
                    opacityAnimation4.fillMode = .backwards
                    opacityAnimation4.isRemovedOnCompletion = false
                    opacityAnimation4.keyPath = "opacity"
                    opacityAnimation4.values = [ 0, 1, 0, 1, 0 ]
                    opacityAnimation4.keyTimes = [ 0.229908, 0.291, 0.4146, 0.5381, 0.5946 ]
                    opacityAnimation4.calculationMode = .linear

                    ellipseLayer2.add(opacityAnimation4, forKey: "opacityAnimation4")
                ellipseLayer2.path = ellipsePath2
                ellipseLayer2.fillColor = fillColor5.cgColor
                ellipseLayer2.strokeColor = strokeColor.cgColor
                ellipseLayer2.lineWidth = 0

                groupLayer6.addSublayer(ellipseLayer2)

            opennedPassportLayer.addSublayer(groupLayer6)

        self.layer.addSublayer(opennedPassportLayer)

        // Device
        //
        let deviceLayer = CALayer()
        deviceLayer.name = "Device"
        deviceLayer.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
        deviceLayer.position = CGPoint(x: 137, y: 20)
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
            let opacityAnimation5 = CAKeyframeAnimation()
            opacityAnimation5.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            opacityAnimation5.duration = 5.999999
            opacityAnimation5.repeatCount = 100
            opacityAnimation5.fillMode = .backwards
            opacityAnimation5.isRemovedOnCompletion = false
            opacityAnimation5.keyPath = "opacity"
            opacityAnimation5.values = [ 0, 1, 1, 0 ]
            opacityAnimation5.keyTimes = [ 0.595833, 0.666912, 0.94456, 1 ]
            opacityAnimation5.calculationMode = .linear

            deviceLayer.add(opacityAnimation5, forKey: "opacityAnimation5")

            // position
            //
            let positionAnimation = CAKeyframeAnimation()
            positionAnimation.beginTime = self.layer.convertTime(CACurrentMediaTime(), from: nil) + 0.000001
            positionAnimation.duration = 6
            positionAnimation.repeatCount = 100
            positionAnimation.fillMode = .backwards
            positionAnimation.isRemovedOnCompletion = false
            positionAnimation.keyPath = "position"
            positionAnimation.values = [ CGPoint(x: 0, y: 0), CGPoint(x: -16, y: 0) ]
            positionAnimation.keyTimes = [ 0.6286, 0.7488 ]
            positionAnimation.calculationMode = .linear

            deviceLayer.add(positionAnimation, forKey: "positionAnimation")

            // Device Sublayers
            //

            // Group 14
            //
            let groupLayer7 = CALayer()
            groupLayer7.name = "Group 14"
            groupLayer7.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 157.89444)
            groupLayer7.position = CGPoint(x: 139, y: 28)
            groupLayer7.anchorPoint = CGPoint(x: 0, y: 0)
            groupLayer7.contentsGravity = .center
            groupLayer7.shadowOffset = CGSize(width: 0, height: 1)
            groupLayer7.allowsEdgeAntialiasing = true
            groupLayer7.allowsGroupOpacity = true
            groupLayer7.fillMode = .forwards
            groupLayer7.transform = CATransform3D( m11: 0.95, m12: 0, m13: 0, m14: 0,
                                               m21: 0, m22: 0.95, m23: 0, m24: 0,
                                               m31: 0, m32: 0, m33: 1, m34: 0,
                                               m41: 0, m42: 0, m43: 0, m44: 1 )

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
                rectangleLayer2.backgroundColor = backgroundColor6.cgColor
                rectangleLayer2.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer2.allowsEdgeAntialiasing = true
                rectangleLayer2.allowsGroupOpacity = true
                rectangleLayer2.fillMode = .forwards

                groupLayer7.addSublayer(rectangleLayer2)

                // Rectangle 7
                //
                let rectangleLayer3 = CALayer()
                rectangleLayer3.name = "Rectangle 7"
                rectangleLayer3.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 24.433228)
                rectangleLayer3.position = CGPoint(x: 0, y: 133.461273)
                rectangleLayer3.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer3.contentsGravity = .center
                rectangleLayer3.backgroundColor = strokeColor1.cgColor
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

                groupLayer7.addSublayer(rectangleLayer3)

                // Rectangle 8
                //
                let rectangleLayer4 = CALayer()
                rectangleLayer4.name = "Rectangle 8"
                rectangleLayer4.bounds = CGRect(x: 0, y: 0, width: 90.833862, height: 19.348602)
                rectangleLayer4.position = CGPoint(x: 91, y: 20)
                rectangleLayer4.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer4.contentsGravity = .center
                rectangleLayer4.backgroundColor = strokeColor1.cgColor
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

                groupLayer7.addSublayer(rectangleLayer4)

                // Rectangle 9
                //
                let rectangleLayer5 = CALayer()
                rectangleLayer5.name = "Rectangle 9"
                rectangleLayer5.bounds = CGRect(x: 0, y: 0, width: 21.381104, height: 7.996185)
                rectangleLayer5.position = CGPoint(x: 34.726318, y: 5.67627)
                rectangleLayer5.anchorPoint = CGPoint(x: 0, y: 0)
                rectangleLayer5.contentsGravity = .center
                rectangleLayer5.backgroundColor = backgroundColor7.cgColor
                rectangleLayer5.cornerRadius = 2.438305
                rectangleLayer5.shadowOffset = CGSize(width: 0, height: 1)
                rectangleLayer5.allowsEdgeAntialiasing = true
                rectangleLayer5.allowsGroupOpacity = true
                rectangleLayer5.fillMode = .forwards

                groupLayer7.addSublayer(rectangleLayer5)

                // Group 13
                //
                let groupLayer8 = CALayer()
                groupLayer8.name = "Group 13"
                groupLayer8.bounds = CGRect(x: 0, y: 0, width: 20.375, height: 30.180573)
                groupLayer8.position = CGPoint(x: 35.229736, y: 61.356964)
                groupLayer8.anchorPoint = CGPoint(x: 0, y: 0)
                groupLayer8.contentsGravity = .center
                groupLayer8.shadowOffset = CGSize(width: 0, height: 1)
                groupLayer8.allowsEdgeAntialiasing = true
                groupLayer8.allowsGroupOpacity = true
                groupLayer8.fillMode = .forwards

                    // Group 13 Sublayers
                    //

                    // Path 9
                    //
                    let pathLayer13 = CAShapeLayer()
                    pathLayer13.name = "Path 9"
                    pathLayer13.bounds = CGRect(x: 0, y: 0, width: 7.93103, height: 30.180573)
                    pathLayer13.position = CGPoint(x: 12.44397, y: 0)
                    pathLayer13.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer13.contentsGravity = .center
                    pathLayer13.backgroundColor = backgroundColor4.cgColor
                    pathLayer13.borderColor = backgroundColor4.cgColor
                    pathLayer13.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer13.allowsEdgeAntialiasing = true
                    pathLayer13.allowsGroupOpacity = true
                    pathLayer13.fillMode = .forwards
                    pathLayer13.path = pathPath13
                    pathLayer13.fillColor = fillColor.cgColor
                    pathLayer13.strokeColor = strokeColor.cgColor
                    pathLayer13.lineWidth = 0

                    groupLayer8.addSublayer(pathLayer13)

                    // Path 10
                    //
                    let pathLayer14 = CAShapeLayer()
                    pathLayer14.name = "Path 10"
                    pathLayer14.bounds = CGRect(x: 0, y: 0, width: 6.364502, height: 22.60144)
                    pathLayer14.position = CGPoint(x: 8.136963, y: 3.797516)
                    pathLayer14.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer14.contentsGravity = .center
                    pathLayer14.backgroundColor = backgroundColor4.cgColor
                    pathLayer14.borderColor = backgroundColor4.cgColor
                    pathLayer14.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer14.allowsEdgeAntialiasing = true
                    pathLayer14.allowsGroupOpacity = true
                    pathLayer14.fillMode = .forwards
                    pathLayer14.path = pathPath14
                    pathLayer14.fillColor = fillColor.cgColor
                    pathLayer14.strokeColor = strokeColor.cgColor
                    pathLayer14.lineWidth = 0

                    groupLayer8.addSublayer(pathLayer14)

                    // Path 11
                    //
                    let pathLayer15 = CAShapeLayer()
                    pathLayer15.name = "Path 11"
                    pathLayer15.bounds = CGRect(x: 0, y: 0, width: 4.938965, height: 15.498047)
                    pathLayer15.position = CGPoint(x: 3.893433, y: 7.349426)
                    pathLayer15.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer15.contentsGravity = .center
                    pathLayer15.backgroundColor = backgroundColor4.cgColor
                    pathLayer15.borderColor = backgroundColor4.cgColor
                    pathLayer15.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer15.allowsEdgeAntialiasing = true
                    pathLayer15.allowsGroupOpacity = true
                    pathLayer15.fillMode = .forwards
                    pathLayer15.path = pathPath15
                    pathLayer15.fillColor = fillColor.cgColor
                    pathLayer15.strokeColor = strokeColor.cgColor
                    pathLayer15.lineWidth = 0

                    groupLayer8.addSublayer(pathLayer15)

                    // Path 12
                    //
                    let pathLayer16 = CAShapeLayer()
                    pathLayer16.name = "Path 12"
                    pathLayer16.bounds = CGRect(x: 0, y: 0, width: 3.70166, height: 8.938507)
                    pathLayer16.position = CGPoint(x: -0.000122, y: 10.596069)
                    pathLayer16.anchorPoint = CGPoint(x: 0, y: 0)
                    pathLayer16.contentsGravity = .center
                    pathLayer16.backgroundColor = backgroundColor4.cgColor
                    pathLayer16.borderColor = backgroundColor4.cgColor
                    pathLayer16.shadowOffset = CGSize(width: 0, height: 1)
                    pathLayer16.allowsEdgeAntialiasing = true
                    pathLayer16.allowsGroupOpacity = true
                    pathLayer16.fillMode = .forwards
                    pathLayer16.path = pathPath16
                    pathLayer16.fillColor = fillColor.cgColor
                    pathLayer16.strokeColor = strokeColor.cgColor
                    pathLayer16.lineWidth = 0

                    groupLayer8.addSublayer(pathLayer16)

                groupLayer7.addSublayer(groupLayer8)

            deviceLayer.addSublayer(groupLayer7)

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
