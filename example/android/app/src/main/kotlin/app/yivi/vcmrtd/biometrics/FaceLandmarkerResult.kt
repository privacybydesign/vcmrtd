package foundation.privacybydesign.vcmrtd.biometrics

import java.util.Optional

class FaceLandmarkerResult(
    private val landmarks: List<List<NormalizedLandmark>>,
    private val blendshapes: List<List<Category>>?,
    private val transformMatrices: List<FloatArray>?
) {
    fun faceLandmarks(): List<List<NormalizedLandmark>> = landmarks

    fun faceBlendshapes(): Optional<List<List<Category>>> =
        if (blendshapes != null) Optional.of(blendshapes) else Optional.empty()

    fun facialTransformationMatrixes(): Optional<List<FloatArray>> =
        if (transformMatrices != null) Optional.of(transformMatrices) else Optional.empty()
}

class NormalizedLandmark(private val _x: Float, private val _y: Float, private val _z: Float) {
    fun x() = _x
    fun y() = _y
    fun z() = _z
}

class Category(private val _categoryName: String, private val _score: Float) {
    fun categoryName() = _categoryName
    fun score() = _score
}
