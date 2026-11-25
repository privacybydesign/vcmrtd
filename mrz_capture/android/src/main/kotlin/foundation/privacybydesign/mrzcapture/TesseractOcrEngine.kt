package foundation.privacybydesign.mrzcapture

import android.content.Context
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File
import java.io.FileOutputStream

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

    /** Reads [pixels]: 8-bit grey, [width] bytes per row, the MRZ already cut out and cleaned up in Dart. */
    fun ocr(pixels: ByteArray, width: Int, height: Int, lang: String): String {
        ensureTesseractInitialized(lang)
        synchronized(tessLock) {
            val t = tess ?: throw IllegalStateException("Tesseract not initialized")
            t.setImage(pixels, width, height, 1, width)
            val result = (t.getUTF8Text() ?: "").trim()
            t.clear()
            return result
        }
    }

    // ─── Cleanup ───────────────────────────────────────────────────────────────

    fun close() {
        synchronized(tessLock) {
            tess?.recycle()
            tess = null
        }
    }
}