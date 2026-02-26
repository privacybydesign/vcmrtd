package foundation.privacybydesign.vcmrtd.ocr

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.googlecode.tesseract.android.TessBaseAPI
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream

class TesseractOcrEngine(private val context: Context) {

    private var tess: TessBaseAPI? = null
    private val tessLock = Any()

    private var tessOsd: TessBaseAPI? = null
    private val osdLock = Any()

    // ─── Initialisatie ─────────────────────────────────────────────────────────

    private fun ensureTesseractInitialized(lang: String) {
        if (tess != null) return
        val dataPath = context.filesDir.absolutePath
        copyTrainedDataIfNeeded(dataPath, lang)
        tess = TessBaseAPI().apply {
            if (!init(dataPath, lang, TessBaseAPI.OEM_LSTM_ONLY)) {
                throw IllegalStateException("Tesseract init failed for lang=$lang")
            }
        }
        Log.i("OCR_NATIVE", "Tesseract4Android geïnitialiseerd: lang=$lang")
    }

    private fun ensureOsdInitialized() {
        if (tessOsd != null) return
        try {
            val dataPath = context.filesDir.absolutePath
            copyTrainedDataIfNeeded(dataPath, "osd")
            val t = TessBaseAPI()
            if (t.init(dataPath, "osd", TessBaseAPI.OEM_TESSERACT_ONLY)) {
                tessOsd = t
                Log.i("OCR_OSD", "OSD engine geïnitialiseerd")
            } else {
                Log.w("OCR_OSD", "OSD init mislukt — orientatiecorrectie uitgeschakeld")
                t.recycle()
            }
        } catch (e: Exception) {
            Log.w("OCR_OSD", "osd.traineddata niet gevonden — OSD overgeslagen: ${e.message}")
            tessOsd = null
        }
    }

    private fun copyTrainedDataIfNeeded(dataPath: String, lang: String) {
        val tessDir = File("$dataPath/tessdata")
        if (!tessDir.exists()) tessDir.mkdirs()

        val trainedFile = File(tessDir, "$lang.traineddata")
        if (trainedFile.exists()) return

        try {
            context.assets.open("$lang.traineddata").use { input ->
                FileOutputStream(trainedFile).use { output ->
                    input.copyTo(output)
                }
            }
            Log.i("OCR_NATIVE", "Gekopieerd: $lang.traineddata")
        } catch (e: Exception) {
            Log.e("OCR_NATIVE", "Kon asset niet openen: $lang.traineddata", e)
            throw e
        }
    }

    // ─── OSD orientatiedetectie ────────────────────────────────────────────────

    private fun detectOsdAngle(bmp: Bitmap): Int = synchronized(osdLock) {
        val t = tessOsd ?: return 0
        return try {
            t.pageSegMode = TessBaseAPI.PageSegMode.PSM_OSD_ONLY
            t.setImage(bmp)
            val hocr = t.getHOCRText(0) ?: ""
            t.clear()

            val match = Regex("""rotate\s+(\d+)""").find(hocr)
            val angle = match?.groupValues?.get(1)?.toIntOrNull() ?: 0

            Log.i("OCR_OSD", "OSD HOCR rotate=$angle")
            angle
        } catch (e: Exception) {
            Log.w("OCR_OSD", "OSD detectie mislukt: ${e.message}")
            try { t.clear() } catch (_: Exception) {}
            0
        }
    }

    private fun rotateBitmap(bmp: Bitmap, degrees: Int): Bitmap {
        if (degrees == 0) return bmp
        val src = Mat()
        Utils.bitmapToMat(bmp, src)
        val dst = Mat()
        val rotCode = when (degrees) {
            90  -> Core.ROTATE_90_CLOCKWISE
            180 -> Core.ROTATE_180
            270 -> Core.ROTATE_90_COUNTERCLOCKWISE
            else -> return bmp
        }
        Core.rotate(src, dst, rotCode)
        src.release()
        val result = Bitmap.createBitmap(dst.cols(), dst.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(dst, result)
        dst.release()
        return result
    }

    // ─── Publieke OCR methodes ─────────────────────────────────────────────────

    fun ocrNv21(
        bytes: ByteArray,
        width: Int,
        height: Int,
        rotation: Int,
        lang: String,
        roiLeft: Double,
        roiTop: Double,
        roiWidth: Double,
        roiHeight: Double,
        useZoneDetector: Boolean = false,
    ): String {
        ensureTesseractInitialized(lang)
        ensureOsdInitialized()

        // 1. NV21 → Mat
        val yuvMat = Mat(height + height / 2, width, CvType.CV_8UC1)
        yuvMat.put(0, 0, bytes)

        // 2. Convert NV21 → RGBA first, while dimensions are still valid
        val rgbFull = Mat()
        Imgproc.cvtColor(yuvMat, rgbFull, Imgproc.COLOR_YUV2RGBA_NV21)
        yuvMat.release()

        // 3. Rotate the RGBA mat safely
        val rotatedMat = Mat()
        when (rotation) {
            90  -> Core.rotate(rgbFull, rotatedMat, Core.ROTATE_90_CLOCKWISE)
            180 -> Core.rotate(rgbFull, rotatedMat, Core.ROTATE_180)
            270 -> Core.rotate(rgbFull, rotatedMat, Core.ROTATE_90_COUNTERCLOCKWISE)
            else -> rgbFull.copyTo(rotatedMat)
        }
        rgbFull.release()

        // 4. Crop the rotated RGBA mat
        val rw = rotatedMat.cols()
        val rh = rotatedMat.rows()
        val x = (roiLeft * rw).toInt().coerceIn(0, rw - 1)
        val y = (roiTop * rh).toInt().coerceIn(0, rh - 1)
        val cw = (roiWidth * rw).toInt().coerceIn(1, rw - x)
        val ch = (roiHeight * rh).toInt().coerceIn(1, rh - y)
        val croppedMat = rotatedMat.submat(y, y + ch, x, x + cw)
        rotatedMat.release()

        // 5. Mat → Bitmap
        var bmp = Bitmap.createBitmap(croppedMat.cols(), croppedMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(croppedMat, bmp)
        croppedMat.release()

        // 6. OSD orientatiecorrectie
        if (tessOsd != null) {
            val angle = detectOsdAngle(bmp)
            if (angle != 0) bmp = rotateBitmap(bmp, angle)
        }

        // 7. MrzZoneDetector op de crop voor verfijnde ROI
        // eerst fallback dan
        if (useZoneDetector) {
            val zone = MrzZoneDetector.detect(bmp)
            if (zone != null) {
                bmp = ImagePreprocess.cropToNormalizedRoi(
                    bmp, zone.left, zone.top, zone.width, zone.height
                )
                Log.i("OCR_NATIVE", "Dynamische MRZ zone gebruikt")
            } else {
                Log.d("OCR_NATIVE", "MRZ detectie mislukt, vaste ROI als fallback")
            }
        }

        // 8. OCR op gecorrigeerde crop
        return ocrBitmapOcrOnly(bmp, tag = "full")
    }

    // ─── Core OCR ─────────────────────────────────────────────────────────────
    private fun ocrBitmapOcrOnly(bmpInput: Bitmap, tag: String): String = synchronized(tessLock) {
        val t = tess ?: throw IllegalStateException("Tesseract not initialized")

        val src = Mat()
        Utils.bitmapToMat(bmpInput, src)
        val grayMat = Mat()
        Imgproc.cvtColor(src, grayMat, Imgproc.COLOR_RGBA2GRAY)
        src.release()
        var bmp = Bitmap.createBitmap(grayMat.cols(), grayMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(grayMat, bmp)
        grayMat.release()

        bmp = ImagePreprocess.contrastStretchGray(bmp)
        if (ImagePreprocess.meanGray(bmp) < 110.0) bmp = ImagePreprocess.invertGray(bmp)
        bmp = ImagePreprocess.addBorder(bmp, pad = 10)
        bmp = Bitmap.createScaledBitmap(bmp, bmp.width * 2, bmp.height * 2, true)

        t.setVariable("load_system_dawg", "0")
        t.setVariable("load_freq_dawg", "0")
        t.setVariable("user_defined_dpi", "300")
        t.setVariable("tessedit_do_invert", "0")
        t.setVariable(TessBaseAPI.VAR_CHAR_WHITELIST, "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")

        t.pageSegMode = TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK
        t.setImage(bmp)
        val ocrText = (t.getUTF8Text() ?: "").trim()
        t.clear()

        Log.i("OCR_NATIVE", "OCR RAW [$tag]:\n$ocrText\n---")
        ocrText
    }

    // ─── Cleanup ───────────────────────────────────────────────────────────────

    fun close() {
        tess?.recycle()
        tess = null
        tessOsd?.recycle()
        tessOsd = null
    }
}
