package com.pillyliu.pinprofandroid.library

import android.content.SharedPreferences
import androidx.compose.animation.core.animateFloat
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.ui.AppReadingProgressPill
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppTextAction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.Locale
import kotlin.math.roundToInt

internal data class RulesheetLoadResult(
    val status: String,
    val content: RulesheetRenderContent?,
    val webFallbackUrl: String? = null,
)

internal suspend fun loadRulesheetRenderContent(
    gameId: String,
    pathCandidates: List<String>?,
    externalSource: RulesheetRemoteSource?,
): RulesheetLoadResult {
    externalSource?.let { source ->
        return runCatching {
            withContext(Dispatchers.IO) {
                loadRemoteRulesheetWithTimeout(source)
            }
        }
            .fold(
                onSuccess = { RulesheetLoadResult(status = "loaded", content = it) },
                onFailure = {
                    val fallbackUrl = source.url.takeIf { candidate -> candidate.isNotBlank() }
                    if (fallbackUrl != null) {
                        RulesheetLoadResult(status = "loaded", content = null, webFallbackUrl = fallbackUrl)
                    } else {
                        RulesheetLoadResult(status = "error", content = null)
                    }
                },
            )
    }

    val candidates = (pathCandidates?.filter { it.isNotBlank() } ?: emptyList())
        .ifEmpty { listOf("/pinball/rulesheets/$gameId.md") }
    var sawMissing = false
    for (candidate in candidates) {
        val cached = PinballDataCache.loadText(candidate, allowMissing = true)
        if (cached.isMissing) {
            sawMissing = true
            continue
        }
        val text = cached.text
        if (!text.isNullOrBlank()) {
            return RulesheetLoadResult(
                status = "loaded",
                content = RulesheetRenderContent(
                    kind = RulesheetRenderKind.MARKDOWN,
                    body = normalizeRulesheet(text) + RULESHEET_BOTTOM_MARKDOWN_FILLER,
                    baseUrl = "https://pillyliu.com",
                ),
            )
        }
    }
    return RulesheetLoadResult(
        status = if (sawMissing) "missing" else "error",
        content = null,
    )
}

private fun loadRemoteRulesheetWithTimeout(
    source: RulesheetRemoteSource,
    timeoutMs: Long = 8_000,
): RulesheetRenderContent {
    val executor = Executors.newSingleThreadExecutor()
    val future = executor.submit<RulesheetRenderContent> { RemoteRulesheetLoader.load(source) }
    return try {
        future.get(timeoutMs, TimeUnit.MILLISECONDS)
    } finally {
        future.cancel(true)
        executor.shutdownNow()
    }
}

@Composable
internal fun RulesheetProgressPill(
    gameId: String,
    progressRatio: Float,
    savedRatio: Float,
    prefs: SharedPreferences,
    onSavePracticeRatio: ((Float) -> Unit)?,
) {
    val percentText = "${(progressRatio.coerceIn(0f, 1f) * 100f).roundToInt()}%"
    val savedPercent = (savedRatio.coerceIn(0f, 1f) * 100f).roundToInt()
    val needsSave = savedPercent != (progressRatio.coerceIn(0f, 1f) * 100f).roundToInt()
    val pulse = androidx.compose.animation.core.rememberInfiniteTransition(label = "rulesheetPercentPulse")
    val pulseAlpha by pulse.animateFloat(
        initialValue = 1f,
        targetValue = 0.5f,
        animationSpec = androidx.compose.animation.core.infiniteRepeatable(
            animation = androidx.compose.animation.core.tween(durationMillis = 1050),
            repeatMode = androidx.compose.animation.core.RepeatMode.Reverse,
        ),
        label = "pulseAlpha",
    )
    Box(
        modifier = Modifier
            .padding(top = 12.dp, end = 12.dp)
            .clickable {
                val clamped = progressRatio.coerceIn(0f, 1f)
                prefs.edit().putFloat("rulesheet-last-progress-$gameId", clamped).apply()
                onSavePracticeRatio?.invoke(clamped)
            },
    ) {
        AppReadingProgressPill(
            text = percentText,
            saved = !needsSave && savedRatio > 0f,
            alpha = if (needsSave) pulseAlpha else 1f,
        )
    }
}

@Composable
internal fun RulesheetChromeOverlay(
    title: String?,
    gameId: String,
    onBack: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 14.dp, end = 14.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.52f),
                            Color.Black.copy(alpha = 0.22f),
                            Color.Transparent,
                        ),
                    ),
                    RoundedCornerShape(16.dp),
                )
                .border(
                    1.dp,
                    MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.28f),
                    RoundedCornerShape(16.dp),
                )
                .padding(horizontal = 6.dp, vertical = 4.dp),
        ) {
            AppScreenHeader(
                title = title ?: gameId.replace('-', ' ').replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() },
                onBack = onBack,
                titleColor = Color.White,
            )
        }
    }
}

@Composable
internal fun RulesheetResumePrompt(
    savedRatio: Float,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Return to last saved position?") },
        text = { Text("Return to ${(savedRatio * 100f).roundToInt()}%?") },
        confirmButton = {
            AppTextAction(text = "Yes", onClick = onConfirm)
        },
        dismissButton = {
            AppTextAction(text = "No", onClick = onDismiss)
        },
    )
}
