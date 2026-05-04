package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context
import android.graphics.Bitmap

class FaceVerificationEngine(private val context: Context) {

    private val detector = FaceDetectorService(context)
    private val recognizer = FaceRecognizerService(context)

    fun initialize() {
        detector.initialize()
        recognizer.initialize()
    }

    /**
     * Compare NFC photo with selfie captured as a live camera bitmap.
     * Skips JPEG encode/decode for the selfie.
     */
    fun verify(nfcImageBytes: ByteArray, selfieBitmap: Bitmap): Float {
        val nfcFace = detector.detectAndCrop(nfcImageBytes)
            ?: throw IllegalStateException("No face found in NFC photo")
        val nfcEmbedding = try {
            recognizer.generateEmbedding(nfcFace)
        } finally {
            if (!nfcFace.isRecycled) nfcFace.recycle()
        }

        val selfieFace = detector.detectAndCrop(selfieBitmap)
            ?: throw IllegalStateException("No face found in selfie")
        val selfieEmbedding = try {
            recognizer.generateEmbedding(selfieFace)
        } finally {
            if (!selfieFace.isRecycled) selfieFace.recycle()
        }

        return recognizer.cosineSimilarity(nfcEmbedding, selfieEmbedding)
    }

    /**
     * Compare NFC photo with selfie, both as image bytes.
     */
    fun verify(nfcImageBytes: ByteArray, selfieBytes: ByteArray): Float {
        val nfcFace = detector.detectAndCrop(nfcImageBytes)
            ?: throw IllegalStateException("No face found in NFC photo")
        val nfcEmbedding = try {
            recognizer.generateEmbedding(nfcFace)
        } finally {
            if (!nfcFace.isRecycled) nfcFace.recycle()
        }

        val selfieFace = detector.detectAndCrop(selfieBytes)
            ?: throw IllegalStateException("No face found in selfie")
        val selfieEmbedding = try {
            recognizer.generateEmbedding(selfieFace)
        } finally {
            if (!selfieFace.isRecycled) selfieFace.recycle()
        }

        return recognizer.cosineSimilarity(nfcEmbedding, selfieEmbedding)
    }

    fun close() {
        detector.close()
        recognizer.close()
    }
}