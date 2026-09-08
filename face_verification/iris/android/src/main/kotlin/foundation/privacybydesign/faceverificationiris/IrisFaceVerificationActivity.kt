package foundation.privacybydesign.faceverificationiris

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import iris.Iris

/**
 * Hosts the Iris SDK's `startFaceVerification` flow.
 *
 * The Iris SDK mounts its own camera preview and overlay into a [ViewGroup]
 * it's handed rather than exposing a headless per-frame API, so it needs a
 * real Activity to live in. This activity exists solely to give it one and
 * to translate its callback into an activity result the plugin can relay
 * back to Dart.
 *
 * The SDK's own UI is bare — just the camera preview and a small hint label
 * — so this activity adds a thin header (a way back out, which the SDK
 * itself doesn't offer) and a footer with plainer instructions around the
 * [container] it hands the SDK, rather than replacing anything the SDK
 * draws.
 */
class IrisFaceVerificationActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val portrait = intent.getByteArrayExtra(EXTRA_PORTRAIT)
        if (portrait == null) {
            finishWith(OUTCOME_FAILED, null)
            return
        }

        val container = FrameLayout(this)
        val root = FrameLayout(this)
        root.addView(container, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        root.addView(
            buildHeader(),
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.TOP
            },
        )
        root.addView(
            buildFooter(),
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT).apply {
                gravity = Gravity.BOTTOM
            },
        )
        setContentView(root)

        Iris(this).startFaceVerification(
            container,
            portrait,
            object : Iris.StartFaceVerificationHandler {
                override fun onCompletion(face: ByteArray?) {
                    finishWith(OUTCOME_MATCHED, face)
                }

                override fun onFailure() {
                    finishWith(OUTCOME_FAILED, null)
                }

                override fun onCancellation() {
                    finishWith(OUTCOME_CANCELLED, null)
                }
            },
        )
    }

    // The SDK has no back-out affordance of its own; without this override the
    // system back gesture just finishes the activity with no result, which the
    // plugin would otherwise mistake for OUTCOME_FAILED rather than a cancellation.
    @Suppress("OVERRIDE_DEPRECATION", "MissingSuperCall")
    override fun onBackPressed() {
        finishWith(OUTCOME_CANCELLED, null)
    }

    private fun buildHeader(): View {
        val bar = LinearLayout(this)
        bar.orientation = LinearLayout.HORIZONTAL
        bar.gravity = Gravity.CENTER_VERTICAL
        bar.setBackgroundColor(Color.argb(140, 0, 0, 0))
        bar.setPadding(dp(12), dp(12), dp(16), dp(12))

        val back = TextView(this)
        back.text = "←"
        back.setTextColor(Color.WHITE)
        back.textSize = 20f
        back.setPadding(dp(8), dp(8), dp(16), dp(8))
        back.setOnClickListener { finishWith(OUTCOME_CANCELLED, null) }

        val title = TextView(this)
        title.text = "Verify your identity"
        title.setTextColor(Color.WHITE)
        title.textSize = 16f
        title.typeface = Typeface.DEFAULT_BOLD

        bar.addView(back)
        bar.addView(title)
        return bar
    }

    private fun buildFooter(): View {
        val hint = TextView(this)
        hint.text = "Look directly at the camera and hold still until verification completes."
        hint.setTextColor(Color.WHITE)
        hint.textSize = 14f
        hint.gravity = Gravity.CENTER
        hint.setBackgroundColor(Color.argb(140, 0, 0, 0))
        hint.setPadding(dp(24), dp(16), dp(24), dp(16))
        return hint
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

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
    }
}
