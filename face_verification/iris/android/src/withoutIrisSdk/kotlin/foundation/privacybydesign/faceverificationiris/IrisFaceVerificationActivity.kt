package foundation.privacybydesign.faceverificationiris

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Stand-in for the real activity used when the vendor `iris.aar` isn't
 * present (see `android/build.gradle`) — keeps this module buildable
 * without the proprietary SDK, e.g. in CI, by finishing every verification
 * attempt as [OUTCOME_FAILED] instead of importing anything from `iris.*`.
 *
 * Must mirror the public shape of the `withIrisSdk` variant exactly, since
 * [FaceVerificationIrisPlugin] is compiled against whichever one is active.
 */
class IrisFaceVerificationActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        finishWith(OUTCOME_FAILED, null)
    }

    private fun finishWith(outcome: String, face: ByteArray?) {
        val data = Intent()
        data.putExtra(EXTRA_OUTCOME, outcome)
        if (face != null) {
            data.putExtra(EXTRA_FACE, face)
        }
        setResult(RESULT_OK, data)
        finish()
    }

    companion object {
        const val EXTRA_PORTRAIT = "portrait"
        const val EXTRA_OUTCOME = "outcome"
        const val EXTRA_FACE = "face"
        const val OUTCOME_MATCHED = "matched"
        const val OUTCOME_FAILED = "failed"
        const val OUTCOME_CANCELLED = "cancelled"

        fun buildIntent(context: Context, portrait: ByteArray): Intent =
            Intent(context, IrisFaceVerificationActivity::class.java).apply {
                putExtra(EXTRA_PORTRAIT, portrait)
            }

        fun sdkVersion(activity: Activity): String = "unavailable"
    }
}
