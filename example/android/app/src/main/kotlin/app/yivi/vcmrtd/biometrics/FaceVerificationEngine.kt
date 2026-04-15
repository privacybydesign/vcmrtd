package foundation.privacybydesign.vcmrtd.biometrics

import android.content.Context

class FaceVerificationEngine(private val context: Context) {

    private val detector = FaceDetectorService(context)
    private val recognizer = FaceRecognizerService(context)

    fun initialize() {
        detector.initialize()
        recognizer.initialize()
    }

    /**
     * Compare NFC photo with selfie.
     */
    fun verify(nfcImageBytes: ByteArray, selfieBytes: ByteArray): Float {
        // Detect and crop face from NFC passport/photo
        val nfcFace = detector.detectAndCrop(nfcImageBytes)
            ?: throw IllegalStateException("No face found in NFC photo")

        // Detect and crop face from selfie
        val selfieFace = detector.detectAndCrop(selfieBytes)
            ?: throw IllegalStateException("No face found in selfie")

        // Generate face embeddings
        val nfcEmbedding = recognizer.generateEmbedding(nfcFace)
        val selfieEmbedding = recognizer.generateEmbedding(selfieFace)

        // Compute and return similarity
        return recognizer.cosineSimilarity(nfcEmbedding, selfieEmbedding)
    }

    fun close() {
        detector.close()
        recognizer.close()
    }
}