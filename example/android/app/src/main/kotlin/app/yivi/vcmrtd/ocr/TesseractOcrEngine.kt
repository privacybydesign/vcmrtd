package foundation.privacybydesign.vcmrtd.ocr

import android.content.Context
import com.googlecode.tesseract.android.TessBaseAPI
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Scalar
import java.io.File
import java.io.FileOutputStream

data class RoiParams(val left: Double, val top: Double, val width: Double, val height: Double)

class TesseractOcrEngine(private val context: Context) {

    private var tess: TessBaseAPI? = null
    private val tessLock = Any()
    private var currentLang = ""

    // ─── Initialisatie ─────────────────────────────────────────────────────────

    private fun ensureTesseractInitialized(lang: String) {
        synchronized(tessLock) {
            if (tess != null && lang == currentLang) return
            tess?.recycle()

            val dataPath = context.filesDir.absolutePath
            copyTrainedDataIfNeeded(dataPath, lang)

            tess = TessBaseAPI().apply {
                check(init(dataPath, lang, TessBaseAPI.OEM_LSTM_ONLY)) {
                    "Tesseract init failed for lang=$lang"
                }
                setVariable("load_system_dawg", "0")
                setVariable("load_freq_dawg", "0")
                setVariable("user_defined_dpi", "300")
                setVariable(TessBaseAPI.VAR_CHAR_WHITELIST, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
                pageSegMode = TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK
            }
            currentLang = lang
        }
    }

    private fun copyTrainedDataIfNeeded(dataPath: String, lang: String) {
        val tessDir = File("$dataPath/tessdata")
        if (!tessDir.exists()) tessDir.mkdirs()

        val trainedFile = File(tessDir, "$lang.traineddata")
        if (trainedFile.exists() && trainedFile.length() > 0) return

        try {
            context.assets.open("$lang.traineddata").use { input ->
                FileOutputStream(trainedFile).use { output ->
                    input.copyTo(output)
                }
            }
        } catch (e: Exception) {
            throw e
        }
    }

    // ─── OCR op Y-plane (zoals irmamobile) ─────────────────────────────────────

    fun ocrYPlane(
        bytes: ByteArray,
        width: Int,
        height: Int,
        stride: Int,
        rotation: Int,
        lang: String,
        roi: RoiParams,
    ): String {
        ensureTesseractInitialized(lang)

        // 1. Y-plane direct als grayscale Mat
        var mat = Mat(height, stride, CvType.CV_8UC1)
        mat.put(0, 0, bytes)
        if (stride > width) {
            mat = mat.colRange(0, width)
        }

        // 2. ROI crop (rekening houdend met rotatie)
        val lx: Int
        val ly: Int
        val lcw: Int
        val lch: Int

        when (rotation) {
            90 -> {
                lx = (roi.top * width).toInt()
                ly = ((1.0 - roi.left - roi.width) * height).toInt()
                lcw = (roi.height * width).toInt()
                lch = (roi.width * height).toInt()
            }
            270 -> {
                lx = ((1.0 - roi.top - roi.height) * width).toInt()
                ly = (roi.left * height).toInt()
                lcw = (roi.height * width).toInt()
                lch = (roi.width * height).toInt()
            }
            else -> {
                lx = (roi.left * width).toInt()
                ly = (roi.top * height).toInt()
                lcw = (roi.width * width).toInt()
                lch = (roi.height * height).toInt()
            }
        }

        val clampedX = lx.coerceIn(0, mat.cols() - 1)
        val clampedY = ly.coerceIn(0, mat.rows() - 1)
        val clampedW = lcw.coerceIn(1, mat.cols() - clampedX)
        val clampedH = lch.coerceIn(1, mat.rows() - clampedY)

        val cropped = mat.submat(clampedY, clampedY + clampedH, clampedX, clampedX + clampedW).clone()
        mat.release()
        mat = cropped

        // 3. Rotatie
        when (rotation) {
            90 -> Core.rotate(mat, mat, Core.ROTATE_90_CLOCKWISE)
            180 -> Core.rotate(mat, mat, Core.ROTATE_180)
            270 -> Core.rotate(mat, mat, Core.ROTATE_90_COUNTERCLOCKWISE)
        }

        // 4. MRZ Zone Detection (op Mat, niet Bitmap)
        val zone = MrzZoneDetector.detect(mat)

        // 5. MRZ crop
        if (zone != null) {
            val zX = (zone.left * mat.cols()).toInt()
            val zY = (zone.top * mat.rows()).toInt()
            val zW = (zone.width * mat.cols()).toInt()
            val zH = (zone.height * mat.rows()).toInt()
            val mrzCrop = mat.submat(
                maxOf(0, zY), minOf(mat.rows(), zY + zH),
                maxOf(0, zX), minOf(mat.cols(), zX + zW)
            ).clone()
            mat.release()
            mat = mrzCrop
        }

        // 6. Normalize + invert check
        Core.normalize(mat, mat, 0.0, 255.0, Core.NORM_MINMAX)
        if (Core.mean(mat).`val`[0] < 110.0) {
            Core.bitwise_not(mat, mat)
        }

        // 7. Border
        Core.copyMakeBorder(mat, mat, 10, 10, 10, 10, Core.BORDER_CONSTANT, Scalar(255.0))

        // 8. Tesseract OCR
        val w = mat.cols()
        val h = mat.rows()
        val pixels = ByteArray(w * h)
        mat.get(0, 0, pixels)
        mat.release()

        val result: String
        synchronized(tessLock) {
            val t = tess ?: throw IllegalStateException("Tesseract not initialized")
            t.setImage(pixels, w, h, 1, w)
            result = (t.getUTF8Text() ?: "").trim()
            t.clear()
        }
        return result
    }

    // ─── Cleanup ───────────────────────────────────────────────────────────────

    fun close() {
        synchronized(tessLock) {
            tess?.recycle()
            tess = null
        }
    }
}