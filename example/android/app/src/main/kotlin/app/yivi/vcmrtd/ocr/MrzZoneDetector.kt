package foundation.privacybydesign.vcmrtd.ocr

import android.graphics.Bitmap
import android.util.Log
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc

object MrzZoneDetector {

    private const val TAG = "MRZ_ZONE"
    private const val MIN_ASPECT = 5.0
    private const val MIN_COVERAGE = 0.75
    private const val TARGET_HEIGHT = 600

    fun detect(bmp: Bitmap): RoiResult? {
        // Stap 1: Bitmap → grayscale Mat
        val src = Mat()
        Utils.bitmapToMat(bmp, src)
        val gray = Mat()
        Imgproc.cvtColor(src, gray, Imgproc.COLOR_RGBA2GRAY)
        src.release()

        // Stap 2: Resize naar 600px hoogte
        val scale = TARGET_HEIGHT.toDouble() / gray.rows()
        val resized = Mat()
        Imgproc.resize(gray, resized, Size(gray.cols() * scale, TARGET_HEIGHT.toDouble()))
        gray.release()

        val w = resized.cols()
        val h = resized.rows()

        // Stap 3: Gaussian blur (3x3)
        val blurred = Mat()
        Imgproc.GaussianBlur(resized, blurred, Size(3.0, 3.0), 0.0)
        resized.release()

        // Stap 4: Blackhat (13x5)
        val rectKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(13.0, 5.0))
        val blackhat = Mat()
        Imgproc.morphologyEx(blurred, blackhat, Imgproc.MORPH_BLACKHAT, rectKernel)
        blurred.release()

        // Stap 5: Scharr gradient op x-as + min/max scaling
        val gradX = Mat()
        Imgproc.Scharr(blackhat, gradX, CvType.CV_32F, 1, 0)
        blackhat.release()
        Core.convertScaleAbs(gradX, gradX)
        Core.normalize(gradX, gradX, 0.0, 255.0, Core.NORM_MINMAX, CvType.CV_8U)

        // Stap 6: Closing met rechthoekige kernel (13x5)
        val closedRect = Mat()
        Imgproc.morphologyEx(gradX, closedRect, Imgproc.MORPH_CLOSE, rectKernel)
        gradX.release()
        rectKernel.release()

        // Stap 7: Otsu threshold
        val thresh = Mat()
        Imgproc.threshold(closedRect, thresh, 0.0, 255.0, Imgproc.THRESH_BINARY or Imgproc.THRESH_OTSU)
        closedRect.release()

        // Stap 8: Closing met vierkante kernel (21x21)
        val sqKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(21.0, 21.0))
        Imgproc.morphologyEx(thresh, thresh, Imgproc.MORPH_CLOSE, sqKernel)
        sqKernel.release()

        // Stap 9: Erosie x4
        val erodeKernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
        Imgproc.erode(thresh, thresh, erodeKernel, Point(-1.0, -1.0), 4)
        erodeKernel.release()

        // Stap 10: Border removal 5% links/rechts
        val borderP = (w * 0.05).toInt()
        thresh.submat(0, h, 0, borderP).setTo(Scalar(0.0))
        thresh.submat(0, h, w - borderP, w).setTo(Scalar(0.0))

        // Stap 11: Contours zoeken
        val contours = mutableListOf<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(thresh, contours, hierarchy, Imgproc.RETR_EXTERNAL, Imgproc.CHAIN_APPROX_SIMPLE)
        thresh.release()
        hierarchy.release()

        contours.sortByDescending { Imgproc.contourArea(it) }

        var result: RoiResult? = null

        for (contour in contours) {
            val rect = Imgproc.boundingRect(contour)
            val ar = rect.width.toDouble() / rect.height
            val crWidth = rect.width.toDouble() / w

            if (ar <= MIN_ASPECT || crWidth <= MIN_COVERAGE) continue

            val pX = ((rect.x + rect.width) * 0.03).toInt()
            val pY = ((rect.y + rect.height) * 0.03).toInt()

            val left   = (rect.x - pX).coerceAtLeast(0).toDouble() / w
            val top    = (rect.y - pY).coerceAtLeast(0).toDouble() / h
            val right  = (rect.x + rect.width + pX).coerceAtMost(w).toDouble() / w
            val bottom = (rect.y + rect.height + pY).coerceAtMost(h).toDouble() / h

            Log.i(TAG, "MRZ zone: ar=${"%.1f".format(ar)} coverage=${"%.2f".format(crWidth)}")
            result = RoiResult(left, top, right - left, bottom - top)
            break
        }

        contours.forEach { it.release() }

        if (result == null) Log.d(TAG, "Geen MRZ contour gevonden")
        return result
    }

    data class RoiResult(
        val left: Double,
        val top: Double,
        val width: Double,
        val height: Double,
    )
}
