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
        private const val MATCH_THRESHOLD = 0.5f
    }

    fun initialize() {
        val model   = loadModelFile()
        val options = Interpreter.Options().apply { numThreads = 4 }
        interpreter = Interpreter(model, options)
    }

    fun generateEmbedding(face: Bitmap): FloatArray {
        android.util.Log.d(TAG, "Generating embedding for face")
        val input  = preprocessFace(face)
        val output = Array(1) { FloatArray(EMBEDDING_SIZE) }
        interpreter?.run(input, output)
        android.util.Log.d(TAG, "Normalize embedding")
        return normalize(output[0])
    }

    private fun normalize(embedding: FloatArray): FloatArray {
        val norm = sqrt(embedding.sumOf { (it * it).toDouble() }.toFloat())
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

    fun isMatch(similarity: Float): Boolean = similarity > MATCH_THRESHOLD

    private fun preprocessFace(bitmap: Bitmap): Array<Array<Array<FloatArray>>> {
        val input = Array(1) { Array(INPUT_SIZE) { Array(INPUT_SIZE) { FloatArray(3) } } }
        for (y in 0 until INPUT_SIZE) {
            for (x in 0 until INPUT_SIZE) {
                val pixel = bitmap.getPixel(x, y)
                input[0][y][x][0] = (Color.red(pixel)   - 127.5f) / 127.5f
                input[0][y][x][1] = (Color.green(pixel) - 127.5f) / 127.5f
                input[0][y][x][2] = (Color.blue(pixel)  - 127.5f) / 127.5f
            }
        }
        return input
    }

    private fun loadModelFile(): MappedByteBuffer {
        val afd     = context.assets.openFd(MODEL_FILE)
        val fis     = FileInputStream(afd.fileDescriptor)
        val channel = fis.channel
        return channel.map(FileChannel.MapMode.READ_ONLY, afd.startOffset, afd.declaredLength)
    }

    fun close() {
        interpreter?.close()
        interpreter = null
    }
}