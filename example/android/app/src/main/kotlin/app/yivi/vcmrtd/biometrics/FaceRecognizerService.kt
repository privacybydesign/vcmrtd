package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import kotlin.math.sqrt

class FaceRecognizerService(private val context: Context) {

    private var interpreter: Interpreter? = null

    companion object {
        private const val TAG            = "FaceRecognizer"
        private const val MODEL_FILE     = "GhostFaceNet.tflite"
        private const val INPUT_SIZE     = 112
        private const val EMBEDDING_SIZE = 512
    }

    private val preprocessInput  = Array(1) { Array(INPUT_SIZE) { Array(INPUT_SIZE) { FloatArray(3) } } }
    private val preprocessPixels = IntArray(INPUT_SIZE * INPUT_SIZE)
    private val outputScratch    = Array(1) { FloatArray(EMBEDDING_SIZE) }

    fun initialize() {
        val model   = loadModelFile()
        val options = Interpreter.Options().apply { numThreads = 4 }
        interpreter = Interpreter(model, options)
    }

    fun generateEmbedding(face: Bitmap): FloatArray {
        android.util.Log.d(TAG, "Generating embedding for face")
        preprocessFace(face)
        interpreter?.run(preprocessInput, outputScratch)
        android.util.Log.d(TAG, "Normalize embedding")
        return normalize(outputScratch[0])
    }

    private fun normalize(embedding: FloatArray): FloatArray {
        val norm = sqrt(embedding.sumOf { it * it.toDouble() }).toFloat()
        return if (norm > 0) FloatArray(embedding.size) { embedding[it] / norm } else embedding
    }

    /**
     * Cosine similarity clamped to [0.0, 1.0].
     * Raw cosine is in [-1, 1] — negative values mean "opposite direction"
     * which has no meaningful interpretation as a face match score, so we
     * clamp to 0 as the minimum.
     */
    fun cosineSimilarity(a: FloatArray, b: FloatArray): Float {
        var dot = 0f
        for (i in a.indices) dot += a[i] * b[i]
        return dot.coerceIn(0f, 1f)
    }

    private fun preprocessFace(bitmap: Bitmap) {
        bitmap.getPixels(preprocessPixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
        for (y in 0 until INPUT_SIZE) {
            for (x in 0 until INPUT_SIZE) {
                val pixel = preprocessPixels[y * INPUT_SIZE + x]
                preprocessInput[0][y][x][0] = (Color.red(pixel)   - 127.5f) / 127.5f
                preprocessInput[0][y][x][1] = (Color.green(pixel) - 127.5f) / 127.5f
                preprocessInput[0][y][x][2] = (Color.blue(pixel)  - 127.5f) / 127.5f
            }
        }
    }

    private fun loadModelFile(): MappedByteBuffer =
        context.assets.openFd(MODEL_FILE).use { afd ->
            FileInputStream(afd.fileDescriptor).use { fis ->
                fis.channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
            }
        }

    fun close() {
        interpreter?.close()
        interpreter = null
    }
}
