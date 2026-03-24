package foundation.privacybydesign.vcmrtd.ocr

import org.opencv.core.*
import org.opencv.imgproc.Imgproc

object MrzZoneDetector {

    private const val TARGET_HEIGHT = 600

    data class RoiResult(
        val left: Double,
        val top: Double,
        val width: Double,
        val height: Double,
    )

    fun detect(src: Mat): RoiResult? {
        // 1. Convert to grayscale
        val gray = Mat()
        if (src.channels() > 1) {
            Imgproc.cvtColor(src, gray, Imgproc.COLOR_RGBA2GRAY)
        } else {
            src.copyTo(gray)
        }

        // 2. Scale to fixed height for consistent parameters
        val scale = TARGET_HEIGHT.toDouble() / gray.rows()
        val resized = Mat()
        Imgproc.resize(gray, resized, Size(gray.cols() * scale, TARGET_HEIGHT.toDouble()))
        gray.release()

        val w = resized.cols()
        val h = resized.rows()

        // 3. Calculate contrast
        val mean = MatOfDouble()
        val stddev = MatOfDouble()
        Core.meanStdDev(resized, mean, stddev)
        val contrast = stddev.get(0, 0)[0]
        mean.release()
        stddev.release()

        // 4. Contrast correction with CLAHE
        Core.normalize(resized, resized, 0.0, 255.0, Core.NORM_MINMAX, CvType.CV_8U)
        val clipLimit = when {
            contrast < 20 -> 10.0
            contrast < 35 -> 6.0
            else -> 3.0
        }
        val clahe = Imgproc.createCLAHE(clipLimit, Size(4.0, 4.0))
        clahe.apply(resized, resized)

        // 5. Gaussian Blur
        val blurred = Mat()
        Imgproc.GaussianBlur(resized, blurred, Size(3.0, 3.0), 0.0)
        resized.release()

        // 6. Blackhat morph to isolate dark text on bright background
        val rectKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(15.0, 7.0))
        val blackhat = Mat()
        Imgproc.morphologyEx(blurred, blackhat, Imgproc.MORPH_BLACKHAT, rectKernel)
        blurred.release()

        // 7. Sobel gradient to detect vertical text edges
        val gradX = Mat()
        Imgproc.Sobel(blackhat, gradX, CvType.CV_32F, 1, 0, -1)
        blackhat.release()
        Core.convertScaleAbs(gradX, gradX)
        Core.normalize(gradX, gradX, 0.0, 255.0, Core.NORM_MINMAX, CvType.CV_8U)

        // 8. Closing to merge nearby letters into lines
        Imgproc.morphologyEx(gradX, gradX, Imgproc.MORPH_CLOSE, rectKernel)
        rectKernel.release()

        // 9. Otsu threshold
        val thresh = Mat()
        Imgproc.threshold(gradX, thresh, 0.0, 255.0,
            Imgproc.THRESH_BINARY or Imgproc.THRESH_OTSU)
        gradX.release()

        // 10. Pass 1: Horizontal projection
        var result = tryHorizontalProjection(thresh, w, h)

        // 11. Pass 2: Contour detection fallback
        if (result == null) {
            result = tryContourDetection(thresh, w, h)
        } else {
            thresh.release()
        }

        // 12. Final fallback: fixed ROI bottom of image
        if (result == null) {
            result = RoiResult(0.02, 0.70, 0.96, 0.28)
        }

        return result
    }

    /**
     * Horizontal projection — detect MRZ as a dense horizontal band
     * in the bottom half of the image.
     */
    private fun tryHorizontalProjection(thresh: Mat, w: Int, h: Int): RoiResult? {
        val searchStartY = (h * 0.45).toInt()
        val bottomHalf = thresh.submat(searchStartY, h, 0, w)
        val bh = bottomHalf.rows()

        // Row density
        val rowSums = Mat()
        Core.reduce(bottomHalf, rowSums, 1, Core.REDUCE_AVG, CvType.CV_64F)

        val density = DoubleArray(bh) { y -> rowSums.get(y, 0)[0] / 255.0 }
        rowSums.release()

        // Smooth density profile
        val smoothW = 5
        val smoothed = DoubleArray(bh) { y ->
            var total = 0.0
            var count = 0
            for (dy in -smoothW..smoothW) {
                val yy = y + dy
                if (yy in 0 until bh) {
                    total += density[yy]
                    count++
                }
            }
            total / count
        }

        // Find densest 70px band (typical MRZ height)
        var bestScore = 0.0
        var bestStart = 0
        val bestWindow = 70

        for (y in 0..(bh - 70)) {
            var score = 0.0
            for (dy in 0 until 70) score += smoothed[y + dy]
            score /= 70.0
            if (score > bestScore) {
                bestScore = score
                bestStart = y
            }
        }

        if (bestScore < 0.10) return null

        // Expand band until density drops
        val cutoff = bestScore * 0.25
        var mrzTop = bestStart
        var mrzBottom = minOf(bestStart + bestWindow, bh - 1)

        for (y in (bestStart - 1) downTo 0) {
            if (smoothed[y] < cutoff) { mrzTop = y + 1; break }
            mrzTop = y
        }
        for (y in (bestStart + bestWindow) until bh) {
            if (smoothed[y] < cutoff) { mrzBottom = y - 1; break }
            mrzBottom = y
        }

        // Translate to full image coordinates + margin
        var absTop = mrzTop + searchStartY
        var absBottom = mrzBottom + searchStartY
        val padY = ((absBottom - absTop) * 0.15).toInt()
        absTop = maxOf(0, absTop - padY)
        absBottom = minOf(h - 1, absBottom + padY)

        val roiTop = absTop.toDouble() / h
        val roiHeight = (absBottom - absTop).toDouble() / h

        // Validate reasonable MRZ height
        if (roiHeight < 0.08 || roiHeight > 0.45) return null

        return RoiResult(0.02, roiTop, 0.96, roiHeight)
    }

    /**
     * Contour detection fallback — group contours and filter on aspect ratio.
     */
    private fun tryContourDetection(thresh: Mat, w: Int, h: Int): RoiResult? {
        // Morph ops to merge lines/words into blocks
        val smallClose = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(9.0, 9.0))
        Imgproc.morphologyEx(thresh, thresh, Imgproc.MORPH_CLOSE, smallClose)
        smallClose.release()

        val vErode = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(1.0, 15.0))
        Imgproc.erode(thresh, thresh, vErode, Point(-1.0, -1.0), 2)
        vErode.release()

        val hErode = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(5.0, 1.0))
        Imgproc.erode(thresh, thresh, hErode, Point(-1.0, -1.0), 1)
        hErode.release()

        val hClose = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(31.0, 1.0))
        Imgproc.morphologyEx(thresh, thresh, Imgproc.MORPH_CLOSE, hClose)
        hClose.release()

        val vClose = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(1.0, 21.0))
        Imgproc.morphologyEx(thresh, thresh, Imgproc.MORPH_CLOSE, vClose)
        vClose.release()

        val hDilate = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(31.0, 5.0))
        Imgproc.dilate(thresh, thresh, hDilate, Point(-1.0, -1.0), 4)
        hDilate.release()

        // Ignore image borders
        val borderP = (w * 0.05).toInt()
        thresh.submat(0, h, 0, borderP).setTo(Scalar(0.0))
        thresh.submat(0, h, w - borderP, w).setTo(Scalar(0.0))

        // Find contours
        val contours = mutableListOf<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(thresh, contours, hierarchy,
            Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE)
        thresh.release()
        hierarchy.release()

        contours.sortByDescending { Imgproc.contourArea(it) }

        var best: RoiResult? = null
        var bestCenterY = 0.0

        for (contour in contours) {
            val rect = Imgproc.boundingRect(contour)
            val ar = rect.width.toDouble() / rect.height
            val crWidth = rect.width.toDouble() / w
            val areaRatio = (rect.width * rect.height).toDouble() / (w * h)
            val heightRatio = rect.height.toDouble() / h
            val centerY = (rect.y + rect.height / 2.0) / h

            if (areaRatio > 0.40) continue
            if (heightRatio > 0.35) continue
            if (centerY < 0.4) continue

            if (ar > 2.5 && crWidth > 0.25 && rect.height > 15 && areaRatio > 0.05) {
                if (centerY > bestCenterY) {
                    val pX = (rect.width * 0.08).toInt()
                    val pY = (rect.height * 0.20).toInt()

                    val left = maxOf(rect.x - pX, 0).toDouble() / w
                    val top = maxOf(rect.y - pY, 0).toDouble() / h
                    val right = minOf(rect.x + rect.width + pX, w).toDouble() / w
                    val bottom = minOf(rect.y + rect.height + pY, h).toDouble() / h

                    best = RoiResult(left, top, right - left, bottom - top)
                    bestCenterY = centerY
                }
            }
        }

        contours.forEach { it.release() }
        return best
    }
}