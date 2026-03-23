package Utilities;

import android.animation.ArgbEvaluator;
import android.animation.ValueAnimator;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.MotionEvent;

import androidx.appcompat.widget.AppCompatButton;
import androidx.core.content.ContextCompat;

import com.facetec.sampleapp.R;
import com.facetec.sampleapp.SampleAppActivity;

public class SampleAppActionButton extends AppCompatButton {
    int enabledBackgroundColor = Color.parseColor("#417FB2");
    int disabledBackgroundColor = Color.parseColor("#66417FB2");
    int highlightedBackgroundColor = Color.parseColor("#396E99");
    int titleTextColor = Color.WHITE;
    float titleLetterSpacing = 0.05f;
    Typeface titleTypeface = Typeface.create("sans-serif-medium", Typeface.NORMAL);

    Drawable mBackgroundDrawable;
    int mTextColor;
    int mBackgroundColor;
    int mBorderColor;
    int mBorderWidth;
    int mCornerRadius;
    int mTextSize;
    Typeface mTypeface;

    int mStateTransitionTime = 200;

    boolean isHighlighted = false;
    boolean isSetup = false;

    public SampleAppActionButton(Context context) {
        super(context);
    }

    public SampleAppActionButton(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public SampleAppActionButton(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @SuppressLint("ClickableViewAccessibility")
    public void setupButton(final SampleAppActivity activity) {
        if (isSetup) {
            return;
        }
        isSetup = true;

        mBackgroundColor = this.isEnabled() ? enabledBackgroundColor : disabledBackgroundColor;
        mTextColor = titleTextColor;
        mBorderColor = Color.TRANSPARENT;
        mBorderWidth = 0;
        mCornerRadius = 8;
        mTextSize = 20;
        mTypeface = titleTypeface;

        mBackgroundDrawable = ContextCompat.getDrawable(activity, R.drawable.sample_button_bg);
        if (mBackgroundDrawable != null && mBackgroundDrawable instanceof GradientDrawable) {
            mBackgroundDrawable = mBackgroundDrawable.mutate();
            ((GradientDrawable)mBackgroundDrawable).setColor(mBackgroundColor);
            ((GradientDrawable)mBackgroundDrawable).setStroke(mBorderWidth, mBorderColor);
            ((GradientDrawable)mBackgroundDrawable).setCornerRadius(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, mCornerRadius, Resources.getSystem().getDisplayMetrics()));
        }
        setBackground(mBackgroundDrawable);

        this.setTypeface(mTypeface);
        this.setLetterSpacing(titleLetterSpacing);

        this.setOnClickListener(view -> {
            // Set button background and text to normal color
            setHighlighted(false, true);

            switch (getTag().toString()) {
                case "livenessCheckButton":
                    activity.onLivenessCheckPressed(this);
                    break;
                case "enrollUserButton":
                    activity.onEnrollUserPressed(this);
                    break;
                case "verifyUserButton":
                    activity.onVerifyUserPressed(this);
                    break;
                case "photoIDMatchButton":
                    activity.onPhotoIDMatchPressed(this);
                    break;
                case "photoIDScanOnlyButton":
                    activity.onPhotoIDScanOnlyPressed(this);
                    break;
                case "designShowcaseButton":
                    activity.onThemeSelectionPressed(this);
                    break;
                case "officialIDPhotoButton":
                    activity.onOfficialIDPhotoPressed(this);
                    break;
                default:
            }
        });

        this.setOnTouchListener((v, event) -> {
            if (!isEnabled()) {
                return true;
            }
            // If finger is pressed down within the button's bounds
            if (event.getAction() == MotionEvent.ACTION_DOWN) {
                // Set button background and text to highlight color
                setHighlighted(true, false);
            }
            // If finger is pressed down and moves off of the button or action is aborted
            else if (event.getAction() == MotionEvent.ACTION_CANCEL || event.getX() < 0 || event.getX() > getWidth() || event.getY() < 0 || event.getY() > getHeight()) {
                // Set button background and text to normal color
                setHighlighted(false, true);
                // No further action
            }
            // If finger is released from pressing the button
            else if (event.getAction() == MotionEvent.ACTION_UP) {
                performClick();
            }

            return true;
        });

        updateButtonStyle(false);
    }

    void updateButtonStyle(boolean animated) {
        if (!isSetup) {
            return;
        }
        
        int transitionTime = animated ? mStateTransitionTime : 0;

        int backgroundColorFrom = mBackgroundColor;
        int backgroundColorTo;
        if (!this.isEnabled()) {
            // Setup disabled config
            backgroundColorTo = disabledBackgroundColor;
        }
        else if (isHighlighted) {
            // Setup highlighted config
            backgroundColorTo = highlightedBackgroundColor;
        }
        else {
            // Setup normal/enabled config
            backgroundColorTo = enabledBackgroundColor;
        }

        // Animate background color change
        ValueAnimator buttonBackgroundColorAnim = ValueAnimator.ofObject(new ArgbEvaluator(), backgroundColorFrom, backgroundColorTo);
        buttonBackgroundColorAnim.setDuration(transitionTime);
        buttonBackgroundColorAnim.addUpdateListener(animator -> {
            if (mBackgroundDrawable == null) {
                return;
            }
            mBackgroundColor = (int)animator.getAnimatedValue();
            ((GradientDrawable)mBackgroundDrawable).setColor(mBackgroundColor);
            this.setBackground(mBackgroundDrawable);
            this.postInvalidate();
        });
        buttonBackgroundColorAnim.start();
    }

    public void setEnabled(boolean enabled, boolean animated) {
        if (this.isEnabled() == enabled) {
            return;
        }
        super.setEnabled(enabled);

        updateButtonStyle(animated);
    }

    public void setHighlighted(boolean highlighted, boolean animated) {
        if (isHighlighted == highlighted || !this.isEnabled()) {
            return;
        }
        isHighlighted = highlighted;

        updateButtonStyle(animated);
    }
}
