package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.library.ReferenceLink
import com.pillyliu.pinprofandroid.library.shortRulesheetTitle
import java.util.Locale

internal enum class AppVariantPillStyle {
    Resource,
    Mini,
    Overlay,
    Standard,
    MachineTitle,
    EditSelector,
}

private val AppVariantPillStyle.verticalOffset: Dp
    get() = when (this) {
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.EditSelector -> 0.dp
        AppVariantPillStyle.Mini,
        AppVariantPillStyle.Overlay,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle -> (-1).dp
    }

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun AppResourceRow(
    label: String,
    content: @Composable () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = colors.brandChalk,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            content()
        }
    }
}

@Composable
internal fun AppResourceChip(
    label: String,
    onClick: () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = colors.controlBackground,
            contentColor = colors.brandInk,
        ),
        border = BorderStroke(1.dp, colors.brandGold.copy(alpha = 0.34f)),
        shape = RoundedCornerShape(999.dp),
    ) {
        Text(label, fontSize = 12.sp)
    }
}

@Composable
internal fun AppUnavailableResourceChip() {
    val colors = PinballThemeTokens.colors
    Text(
        "Unavailable",
        fontSize = 12.sp,
        color = colors.brandChalk,
        modifier = Modifier
            .background(
                colors.brandGold.copy(alpha = 0.08f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.22f), RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

@Composable
internal fun AppVariantBadge(label: String) {
    AppVariantPill(label = label, style = AppVariantPillStyle.Resource)
}

@Composable
internal fun AppVariantPill(
    label: String,
    style: AppVariantPillStyle = AppVariantPillStyle.Resource,
    modifier: Modifier = Modifier,
    maxWidth: Dp? = null,
) {
    val colors = PinballThemeTokens.colors
    val foreground = when (style) {
        AppVariantPillStyle.Overlay -> Color.White.copy(alpha = 0.96f)
        else -> colors.brandInk
    }
    val textStyle = when (style) {
        AppVariantPillStyle.Resource -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Mini -> MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
        AppVariantPillStyle.Overlay -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Standard -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.MachineTitle -> MaterialTheme.typography.labelMedium
        AppVariantPillStyle.EditSelector -> MaterialTheme.typography.bodyMedium
    }
    val horizontalPadding = when (style) {
        AppVariantPillStyle.Mini -> 6.dp
        AppVariantPillStyle.Overlay -> 7.dp
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle,
        AppVariantPillStyle.EditSelector -> 8.dp
    }
    Text(
        text = label,
        style = textStyle,
        color = foreground,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .then(if (maxWidth != null) Modifier.widthIn(max = maxWidth) else Modifier)
            .background(
                colors.brandGold.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.34f), RoundedCornerShape(999.dp))
            .padding(
                horizontal = horizontalPadding,
                vertical = when (style) {
                    AppVariantPillStyle.Resource -> 5.dp
                    AppVariantPillStyle.Overlay -> 2.dp
                    else -> 3.dp
                },
            )
            .offset(y = style.verticalOffset),
    )
}

@Composable
internal fun AppTintedPill(
    label: String,
    foreground: Color,
    style: AppVariantPillStyle = AppVariantPillStyle.Resource,
    modifier: Modifier = Modifier,
    maxWidth: Dp? = null,
) {
    val textStyle = when (style) {
        AppVariantPillStyle.Resource -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Mini -> MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
        AppVariantPillStyle.Overlay -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Standard -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.MachineTitle -> MaterialTheme.typography.labelMedium
        AppVariantPillStyle.EditSelector -> MaterialTheme.typography.bodyMedium
    }
    val horizontalPadding = when (style) {
        AppVariantPillStyle.Mini -> 6.dp
        AppVariantPillStyle.Overlay -> 7.dp
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle,
        AppVariantPillStyle.EditSelector -> 8.dp
    }
    Text(
        text = label,
        style = textStyle,
        color = foreground,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .then(if (maxWidth != null) Modifier.widthIn(max = maxWidth) else Modifier)
            .background(
                foreground.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, foreground.copy(alpha = 0.34f), RoundedCornerShape(999.dp))
            .padding(
                horizontal = horizontalPadding,
                vertical = when (style) {
                    AppVariantPillStyle.Resource -> 5.dp
                    AppVariantPillStyle.Overlay -> 2.dp
                    else -> 3.dp
                },
            )
            .offset(y = style.verticalOffset),
    )
}

@Composable
internal fun AppOverlayMetadataBadge(
    label: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    Text(
        text = label,
        fontSize = 9.sp,
        color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.96f),
        maxLines = 1,
        modifier = modifier
            .background(
                colors.brandInk.copy(alpha = 0.54f),
                RoundedCornerShape(999.dp),
            )
            .border(0.7.dp, colors.brandGold.copy(alpha = 0.38f), RoundedCornerShape(999.dp))
            .padding(horizontal = 5.dp, vertical = 1.dp),
    )
}

@Composable
internal fun AppOverlayTitle(
    text: String,
    modifier: Modifier = Modifier,
    lineHeight: androidx.compose.ui.unit.TextUnit = 17.sp,
) {
    Text(
        text = text,
        fontSize = 16.sp,
        lineHeight = lineHeight,
        color = Color.White,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        style = MaterialTheme.typography.titleSmall.copy(
            shadow = Shadow(
                color = Color.Black.copy(alpha = 1f),
                blurRadius = 4f,
            ),
        ),
        modifier = modifier,
    )
}

@Composable
internal fun AppOverlayTitleWithVariant(
    text: String,
    variant: String?,
    modifier: Modifier = Modifier,
    lineHeight: androidx.compose.ui.unit.TextUnit = 17.sp,
) {
    val resolvedVariant = variant?.trim()?.takeIf { it.isNotEmpty() }
    if (resolvedVariant == null) {
        AppOverlayTitle(text = text, modifier = modifier, lineHeight = lineHeight)
        return
    }

    AppInlineTextWithPill(
        text = text,
        pillLabel = resolvedVariant,
        maxLines = 2,
        textColor = Color.White,
        textStyle = MaterialTheme.typography.titleSmall.copy(
            fontSize = 16.sp,
            lineHeight = lineHeight,
            shadow = Shadow(
                color = Color.Black.copy(alpha = 1f),
                blurRadius = 4f,
            ),
        ),
        pillTextStyle = MaterialTheme.typography.labelSmall,
        pillHorizontalPadding = 7.dp,
        pillVerticalPadding = 2.dp,
        modifier = modifier,
    ) { label ->
        AppVariantPill(
            label = label,
            style = AppVariantPillStyle.Overlay,
        )
    }
}

@Composable
internal fun AppInlineTintedMetaWithPill(
    text: String,
    pillLabel: String,
    pillForeground: Color,
    modifier: Modifier = Modifier,
) {
    AppInlineTextWithPill(
        text = text,
        pillLabel = pillLabel,
        maxLines = 1,
        textColor = PinballThemeTokens.colors.brandInk,
        textStyle = MaterialTheme.typography.bodySmall.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold),
        pillTextStyle = MaterialTheme.typography.labelMedium,
        pillHorizontalPadding = 8.dp,
        pillVerticalPadding = 3.dp,
        modifier = modifier,
    ) { label ->
        AppTintedPill(
            label = label,
            foreground = pillForeground,
            style = AppVariantPillStyle.MachineTitle,
        )
    }
}

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

        Text(
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
) : InlineTextWithPillLayout {
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

@Composable
internal fun AppOverlaySubtitle(
    text: String,
    modifier: Modifier = Modifier,
    alpha: Float = 0.96f,
) {
    Text(
        text = text,
        fontSize = 12.sp,
        lineHeight = 14.sp,
        color = Color.White.copy(alpha = alpha),
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        style = MaterialTheme.typography.bodySmall.copy(
            shadow = Shadow(
                color = Color.Black.copy(alpha = 0.9f),
                blurRadius = 3f,
            ),
        ),
        modifier = modifier,
    )
}

@Composable
internal fun AppReadingProgressPill(
    text: String,
    saved: Boolean,
    modifier: Modifier = Modifier,
    alpha: Float = 1f,
) {
    val colors = PinballThemeTokens.colors
    val foreground = if (saved) colors.statsHigh else colors.brandInk
    val background = if (saved) {
        colors.statsHigh.copy(alpha = 0.18f)
    } else {
        colors.controlBackground.copy(alpha = 0.88f)
    }
    val border = if (saved) {
        colors.statsHigh.copy(alpha = 0.34f)
    } else {
        colors.brandChalk.copy(alpha = 0.24f)
    }
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = foreground,
        modifier = modifier
            .graphicsLayer { this.alpha = alpha }
            .background(background, RoundedCornerShape(999.dp))
            .border(0.8.dp, border, RoundedCornerShape(999.dp))
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}

internal fun appShortRulesheetTitle(link: ReferenceLink): String {
    return link.shortRulesheetTitle
}

@Composable
internal fun AppMediaPreviewPlaceholder(
    modifier: Modifier = Modifier,
    message: String? = null,
    showsProgress: Boolean = false,
) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.atmosphereBottom, RoundedCornerShape(12.dp))
            .border(1.dp, colors.brandChalk.copy(alpha = 0.2f), RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.layout.Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (showsProgress) {
                CircularProgressIndicator(
                    modifier = Modifier.defaultMinSize(minWidth = 18.dp, minHeight = 18.dp),
                    strokeWidth = 1.75.dp,
                    color = colors.brandGold,
                )
            } else {
                Icon(
                    imageVector = Icons.Outlined.Photo,
                    contentDescription = null,
                    tint = colors.brandGold,
                )
            }
            message?.let {
                Text(
                    text = it,
                    color = colors.brandChalk,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
internal fun appVideoTileContainerColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandGold.copy(alpha = 0.14f)
    } else {
        PinballThemeTokens.colors.controlBackground.copy(alpha = 0.88f)
    }

@Composable
internal fun appVideoTileBorderColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandGold.copy(alpha = 0.62f)
    } else {
        PinballThemeTokens.colors.brandChalk.copy(alpha = 0.26f)
    }

@Composable
internal fun appVideoTileLabelColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandInk
    } else {
        MaterialTheme.colorScheme.onSurface
    }
