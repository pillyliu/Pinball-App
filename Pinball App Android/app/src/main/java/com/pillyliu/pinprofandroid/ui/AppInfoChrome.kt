package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun SectionTitle(text: String) {
    val colors = PinballThemeTokens.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(width = 6.dp, height = 18.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(colors.brandGold, colors.brandChalk),
                    ),
                    RoundedCornerShape(999.dp),
                ),
        )
        androidx.compose.material3.Text(
            text = text,
            color = colors.brandInk,
            style = PinballThemeTokens.typography.sectionTitle,
        )
    }
}

@Composable
fun AppCardSubheading(text: String, modifier: Modifier = Modifier) {
    androidx.compose.material3.Text(
        text = text,
        color = PinballThemeTokens.colors.brandInk,
        style = MaterialTheme.typography.bodySmall,
        fontWeight = FontWeight.SemiBold,
        modifier = modifier,
    )
}

@Composable
fun AppCardTitle(
    text: String,
    modifier: Modifier = Modifier,
    maxLines: Int = Int.MAX_VALUE,
) {
    androidx.compose.material3.Text(
        text = text,
        color = PinballThemeTokens.colors.brandInk,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}

@Composable
fun AppCardTitleWithVariant(
    text: String,
    variant: String?,
    modifier: Modifier = Modifier,
    maxLines: Int = 2,
) {
    val resolvedVariant = variant?.trim()?.takeIf { it.isNotEmpty() }
    if (resolvedVariant == null) {
        AppCardTitle(text = text, modifier = modifier, maxLines = maxLines)
        return
    }

    AppInlineTextWithPill(
        text = text,
        pillLabel = resolvedVariant,
        maxLines = maxLines,
        textColor = PinballThemeTokens.colors.brandInk,
        textStyle = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
        pillTextStyle = MaterialTheme.typography.labelMedium,
        pillHorizontalPadding = 8.dp,
        pillVerticalPadding = 3.dp,
        modifier = modifier,
    ) { label ->
        AppVariantPill(
            label = label,
            style = AppVariantPillStyle.MachineTitle,
        )
    }
}

data class AppMetricItem(
    val label: String,
    val value: String,
)

@Composable
fun AppMetricGrid(
    items: List<AppMetricItem>,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val rows = items.chunked(2)
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowItems.forEach { item ->
                    Column(modifier = Modifier.weight(1f)) {
                        androidx.compose.material3.Text(
                            text = item.label,
                            style = MaterialTheme.typography.bodySmall,
                            color = colors.brandChalk,
                            fontWeight = FontWeight.SemiBold,
                        )
                        androidx.compose.material3.Text(
                            text = item.value,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.brandInk,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                if (rowItems.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
fun EmptyLabel(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.material3.Text(
            text = text,
            color = PinballThemeTokens.colors.brandChalk,
            style = PinballThemeTokens.typography.emptyState,
        )
    }
}
