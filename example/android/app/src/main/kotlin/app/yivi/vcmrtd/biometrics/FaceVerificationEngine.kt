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
        // Detecteer en crop gezicht uit NFC pasfoto
        val nfcFace = detector.detectAndCrop(nfcImageBytes)
            ?: throw IllegalStateException("No face found in NFC photo")

        // Detecteer en crop gezicht uit selfie
        val selfieFace = detector.detectAndCrop(selfieBytes)
            ?: throw IllegalStateException("No face found in selfie")

        // Genereer embeddings
        val nfcEmbedding = recognizer.generateEmbedding(nfcFace)
        val selfieEmbedding = recognizer.generateEmbedding(selfieFace)

        // Bereken en geef similarity terug
        return recognizer.cosineSimilarity(nfcEmbedding, selfieEmbedding)
    }

    fun close() {
        detector.close()
        recognizer.close()
    }
}