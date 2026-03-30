package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.sp

private data class InlineTextWithPillLayout(
    val displayText: String,
    val displayPillLabel: String,
    val placeholderWidth: androidx.compose.ui.unit.TextUnit,
    val placeholderHeight: androidx.compose.ui.unit.TextUnit,
)

private data class InlinePillCandidate(
    val label: String,
    val visibleCharacters: Int,
)

@Composable
internal fun AppInlineTextWithPill(
    text: String,
    pillLabel: String,
    maxLines: Int,
    textColor: Color,
    textStyle: TextStyle,
    pillTextStyle: TextStyle,
    pillHorizontalPadding: Dp,
    pillVerticalPadding: Dp,
    modifier: Modifier = Modifier,
    pillContent: @Composable (String) -> Unit,
) {
    BoxWithConstraints(modifier = modifier) {
        val density = LocalDensity.current
        val textMeasurer = rememberTextMeasurer()
        val maxWidthPx = with(density) { maxWidth.roundToPx() }.coerceAtLeast(1)
        val resolvedLayout = resolveInlineTextWithPillLayout(
            text = text,
            pillLabel = pillLabel,
            maxWidthPx = maxWidthPx,
            maxLines = maxLines,
            textStyle = textStyle,
            pillTextStyle = pillTextStyle,
            density = density,
            pillHorizontalPadding = pillHorizontalPadding,
            pillVerticalPadding = pillVerticalPadding,
            textMeasurer = textMeasurer,
        )
        val inlineId = "inline-pill"

        androidx.compose.material3.Text(
            text = buildAnnotatedString {
                append(resolvedLayout.displayText)
                append(" ")
                appendInlineContent(inlineId, resolvedLayout.displayPillLabel)
            },
            inlineContent = mapOf(
                inlineId to InlineTextContent(
                    Placeholder(
                        width = resolvedLayout.placeholderWidth,
                        height = resolvedLayout.placeholderHeight,
                        placeholderVerticalAlign = PlaceholderVerticalAlign.TextCenter,
                    ),
                ) {
                    pillContent(resolvedLayout.displayPillLabel)
                },
            ),
            color = textColor,
            style = textStyle,
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

private fun resolveInlineTextWithPillLayout(
    text: String,
    pillLabel: String,
    maxWidthPx: Int,
    maxLines: Int,
    textStyle: TextStyle,
    pillTextStyle: TextStyle,
    density: androidx.compose.ui.unit.Density,
    pillHorizontalPadding: Dp,
    pillVerticalPadding: Dp,
    textMeasurer: androidx.compose.ui.text.TextMeasurer,
): InlineTextWithPillLayout {
    if (pillLabel.isBlank()) {
        return InlineTextWithPillLayout(
            displayText = text,
            displayPillLabel = pillLabel,
            placeholderWidth = 0.sp,
            placeholderHeight = 0.sp,
        )
    }

    var bestLayout: InlineTextWithPillLayout? = null
    var bestVisibleTitleChars = -1
    var bestVisiblePillChars = -1

    for (pillCandidate in inlinePillCandidates(pillLabel)) {
        val (placeholderWidth, placeholderHeight) = measureInlinePillPlaceholder(
            pillLabel = pillCandidate.label,
            pillTextStyle = pillTextStyle,
            density = density,
            pillHorizontalPadding = pillHorizontalPadding,
            pillVerticalPadding = pillVerticalPadding,
            textMeasurer = textMeasurer,
        )
        val visibleTitleChars = maxVisibleInlineTitleCharacters(
            text = text,
            maxWidthPx = maxWidthPx,
            maxLines = maxLines,
            textStyle = textStyle,
            placeholderWidth = placeholderWidth,
            placeholderHeight = placeholderHeight,
            textMeasurer = textMeasurer,
        )
        if (visibleTitleChars > bestVisibleTitleChars ||
            (visibleTitleChars == bestVisibleTitleChars && pillCandidate.visibleCharacters > bestVisiblePillChars)
        ) {
            bestVisibleTitleChars = visibleTitleChars
            bestVisiblePillChars = pillCandidate.visibleCharacters
            bestLayout = InlineTextWithPillLayout(
                displayText = truncatedInlinePillCandidate(text, visibleTitleChars),
                displayPillLabel = pillCandidate.label,
                placeholderWidth = placeholderWidth,
                placeholderHeight = placeholderHeight,
            )
        }

        if (visibleTitleChars >= text.length && pillCandidate.visibleCharacters >= pillLabel.length) {
            return bestLayout ?: InlineTextWithPillLayout(
                displayText = text,
                displayPillLabel = pillLabel,
                placeholderWidth = placeholderWidth,
                placeholderHeight = placeholderHeight,
            )
        }
    }

    return bestLayout ?: run {
        val (placeholderWidth, placeholderHeight) = measureInlinePillPlaceholder(
            pillLabel = pillLabel,
            pillTextStyle = pillTextStyle,
            density = density,
            pillHorizontalPadding = pillHorizontalPadding,
            pillVerticalPadding = pillVerticalPadding,
            textMeasurer = textMeasurer,
        )
        InlineTextWithPillLayout(
            displayText = truncatedInlinePillCandidate(text, 0),
            displayPillLabel = pillLabel,
            placeholderWidth = placeholderWidth,
            placeholderHeight = placeholderHeight,
        )
    }
}

private fun inlinePillCandidates(
    pillLabel: String,
): List<InlinePillCandidate> {
    val trimmed = pillLabel.trim()
    if (trimmed.isEmpty()) return emptyList()
    val candidates = mutableListOf<InlinePillCandidate>()
    for (visibleCharacters in trimmed.length downTo 1) {
        val label = if (visibleCharacters == trimmed.length) {
            trimmed
        } else {
            truncatedInlinePillCandidate(trimmed, visibleCharacters)
        }
        if (candidates.none { it.label == label }) {
            candidates += InlinePillCandidate(label = label, visibleCharacters = visibleCharacters)
        }
    }
    return candidates
}

private fun measureInlinePillPlaceholder(
    pillLabel: String,
    pillTextStyle: TextStyle,
    density: androidx.compose.ui.unit.Density,
    pillHorizontalPadding: Dp,
    pillVerticalPadding: Dp,
    textMeasurer: androidx.compose.ui.text.TextMeasurer,
): Pair<androidx.compose.ui.unit.TextUnit, androidx.compose.ui.unit.TextUnit> {
    val measuredPill = textMeasurer.measure(
        text = AnnotatedString(pillLabel),
        style = pillTextStyle,
        maxLines = 1,
    )
    val densityScale = density.density
    val fontScale = density.fontScale
    val placeholderWidth = with(density) {
        (
            measuredPill.size.width / densityScale +
                ((pillHorizontalPadding * 2).value / fontScale)
            ).sp
    }
    val placeholderHeight = with(density) {
        (
            measuredPill.size.height / densityScale +
                ((pillVerticalPadding * 2).value / fontScale)
            ).sp
    }
    return placeholderWidth to placeholderHeight
}

private fun maxVisibleInlineTitleCharacters(
    text: String,
    maxWidthPx: Int,
    maxLines: Int,
    textStyle: TextStyle,
    placeholderWidth: androidx.compose.ui.unit.TextUnit,
    placeholderHeight: androidx.compose.ui.unit.TextUnit,
    textMeasurer: androidx.compose.ui.text.TextMeasurer,
): Int {
    if (text.isBlank()) return text.length
    if (inlinePillTextFits(text, maxWidthPx, maxLines, textStyle, placeholderWidth, placeholderHeight, textMeasurer)) {
        return text.length
    }

    var low = 0
    var high = text.length
    while (low < high) {
        val mid = (low + high + 1) / 2
        val candidate = truncatedInlinePillCandidate(text, mid)
        if (inlinePillTextFits(candidate, maxWidthPx, maxLines, textStyle, placeholderWidth, placeholderHeight, textMeasurer)) {
            low = mid
        } else {
            high = mid - 1
        }
    }
    return low
}

private fun truncatedInlinePillCandidate(
    text: String,
    visibleCharacters: Int,
): String {
    if (visibleCharacters >= text.length) return text
    val base = text.take(visibleCharacters).trimEnd()
    return if (base.isEmpty()) "…" else "$base…"
}

private fun inlinePillTextFits(
    text: String,
    maxWidthPx: Int,
    maxLines: Int,
    textStyle: TextStyle,
    placeholderWidth: androidx.compose.ui.unit.TextUnit,
    placeholderHeight: androidx.compose.ui.unit.TextUnit,
    textMeasurer: androidx.compose.ui.text.TextMeasurer,
): Boolean {
    val annotatedText = buildAnnotatedString {
        append(text)
        append(" ")
        append('\uFFFC')
    }
    val placeholderStart = annotatedText.length - 1
    val layout = textMeasurer.measure(
        text = annotatedText,
        style = textStyle,
        overflow = TextOverflow.Ellipsis,
        maxLines = maxLines,
        constraints = Constraints(maxWidth = maxWidthPx),
        placeholders = listOf(
            AnnotatedString.Range(
                item = Placeholder(
                    width = placeholderWidth,
                    height = placeholderHeight,
                    placeholderVerticalAlign = PlaceholderVerticalAlign.TextCenter,
                ),
                start = placeholderStart,
                end = placeholderStart + 1,
            ),
        ),
    )
    return !layout.hasVisualOverflow
}
