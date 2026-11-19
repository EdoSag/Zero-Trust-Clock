package dev.sagron.zerotrustclock.engine

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import android.view.accessibility.AccessibilityNodeInfo
import dev.sagron.zerotrustclock.R

/**
 * "Slide to dismiss" on the ring screen: the thumb has to be dragged most
 * of the way across, so a half-asleep tap does not silence the alarm.
 * Starts at the reading start (left, or right in Hebrew). For TalkBack it
 * is a plain button: a double tap dismisses.
 */
class SlideToDismiss @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {
    var onDismiss: (() -> Unit)? = null

    private val density = resources.displayMetrics.density
    private val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.ring_text); alpha = 70 }
    private val thumb = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.getColor(R.color.ring_text) }
    private val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = context.getColor(R.color.ring_text)
        textSize = 20 * resources.displayMetrics.scaledDensity
        textAlign = Paint.Align.CENTER
    }
    private val arrow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = context.getColor(R.color.ring_background)
        strokeWidth = 3 * density
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val text = context.getString(R.string.ring_slide_dismiss)

    /** How far the thumb is across, 0..1. */
    private var progress = 0f
    private var downX = 0f
    private var dragging = false
    private var animator: ValueAnimator? = null

    init {
        contentDescription = context.getString(R.string.ring_dismiss)
        isClickable = true
        isFocusable = true
    }

    private val rtl get() = layoutDirection == LAYOUT_DIRECTION_RTL
    private val thumbSize get() = height.toFloat()
    private val travel get() = (width - thumbSize).coerceAtLeast(1f)

    override fun onDraw(canvas: Canvas) {
        val h = height.toFloat()
        val r = h / 2
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), h), r, r, track)
        label.alpha = (255 * (1f - progress * 1.5f)).toInt().coerceIn(0, 255)
        canvas.drawText(text, width / 2f, h / 2 - (label.descent() + label.ascent()) / 2, label)
        val offset = progress * travel
        val cx = if (rtl) width - r - offset else r + offset
        canvas.drawCircle(cx, r, r - 4 * density, thumb)
        // A chevron pointing the way to slide.
        val s = r * 0.28f
        val dir = if (rtl) -1 else 1
        canvas.drawLine(cx - dir * s / 2, r - s, cx + dir * s / 2, r, arrow)
        canvas.drawLine(cx + dir * s / 2, r, cx - dir * s / 2, r + s, arrow)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                animator?.cancel()
                downX = event.x
                dragging = true
                parent?.requestDisallowInterceptTouchEvent(true)
                return true
            }
            MotionEvent.ACTION_MOVE -> if (dragging) {
                val dx = (event.x - downX) * (if (rtl) -1 else 1)
                progress = (dx / travel).coerceIn(0f, 1f)
                invalidate()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> if (dragging) {
                dragging = false
                if (event.actionMasked == MotionEvent.ACTION_UP && progress >= DONE_AT) {
                    progress = 1f
                    invalidate()
                    onDismiss?.invoke()
                } else {
                    // A tap, or let go too early: a small nudge shows the way, then back.
                    val from = if (progress < 0.02f) 0.15f else progress
                    animateTo(from, then = 0f)
                }
            }
        }
        return true
    }

    private fun animateTo(target: Float, then: Float? = null) {
        animator?.cancel()
        animator = ValueAnimator.ofFloat(progress, target, then ?: target).apply {
            duration = 350
            addUpdateListener {
                progress = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    /** TalkBack's double tap. */
    override fun performClick(): Boolean {
        super.performClick()
        onDismiss?.invoke()
        return true
    }

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = android.widget.Button::class.java.name
    }

    private companion object {
        const val DONE_AT = 0.75f
    }
}
