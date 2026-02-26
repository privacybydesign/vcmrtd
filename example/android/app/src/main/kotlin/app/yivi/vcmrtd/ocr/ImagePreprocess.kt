package foundation.privacybydesign.vcmrtd.ocr

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.util.Log
import java.io.File
import java.io.FileOutputStream

object ImagePreprocess {

    fun toGrayBitmap(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)

        for (i in px.indices) {
            val c = px[i]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            val y = (0.299 * r + 0.587 * g + 0.114 * b).toInt().coerceIn(0, 255)
            px[i] = (0xFF shl 24) or (y shl 16) or (y shl 8) or y
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    fun meanGray(bmp: Bitmap): Double {
        val w = bmp.width
        val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        var sum = 0L
        for (c in px) sum += (c and 0xFF)
        return sum.toDouble() / (w * h)
    }

    fun invertGray(bmp: Bitmap): Bitmap {
        val w = bmp.width
        val h = bmp.height
        val px = IntArray(w * h)
        bmp.getPixels(px, 0, w, 0, 0, w, h)
        for (i in px.indices) {
            val g = px[i] and 0xFF
            val inv = 255 - g
            px[i] = (0xFF shl 24) or (inv shl 16) or (inv shl 8) or inv
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    fun contrastStretchGray(src: Bitmap): Bitmap {
        val w = src.width
        val h = src.height
        val px = IntArray(w * h)
        src.getPixels(px, 0, w, 0, 0, w, h)

        var min = 255
        var max = 0
        for (c in px) {
            val g = c and 0xFF
            if (g < min) min = g
            if (g > max) max = g
        }

        val range = (max - min).coerceAtLeast(1)
        for (i in px.indices) {
            val g = px[i] and 0xFF
            val v = ((g - min) * 255) / range
            px[i] = (0xFF shl 24) or (v shl 16) or (v shl 8) or v
        }

        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
    }

    fun addBorder(src: Bitmap, pad: Int = 10, bg: Int = Color.WHITE): Bitmap {
        val out = Bitmap.createBitmap(src.width + 2 * pad, src.height + 2 * pad, Bitmap.Config.ARGB_8888)
        Canvas(out).apply {
            drawColor(bg)
            drawBitmap(src, pad.toFloat(), pad.toFloat(), null)
        }
        return out
    }

    fun cropToNormalizedRoi(src: Bitmap, roiLeft: Double, roiTop: Double, roiWidth: Double, roiHeight: Double): Bitmap {
        val x = (roiLeft * src.width).toInt().coerceIn(0, src.width - 1)
        val y = (roiTop * src.height).toInt().coerceIn(0, src.height - 1)
        val w0 = (roiWidth * src.width).toInt().coerceIn(1, src.width - x)
        val h0 = (roiHeight * src.height).toInt().coerceIn(1, src.height - y)
        return Bitmap.createBitmap(src, x, y, w0, h0)
    }

    fun saveOcrInputImage(context: Context, bmp: Bitmap, tag: String) {
        try {
            val ts = System.currentTimeMillis()
            val fileName = "${tag}_ocr_input_$ts.png"
            val f = File(context.filesDir, fileName)
            FileOutputStream(f).use { out ->
                bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            Log.i("OCR_DEBUG", "Saved OCR input [$tag]: ${bmp.width}x${bmp.height} -> ${f.absolutePath}")
        } catch (e: Exception) {
            Log.e("OCR_DEBUG", "Failed to save OCR input", e)
        }
    }
}