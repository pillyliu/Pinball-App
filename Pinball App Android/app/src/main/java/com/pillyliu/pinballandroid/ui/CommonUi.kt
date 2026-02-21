package com.pillyliu.pinballandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val LocalBottomBarVisible = compositionLocalOf<MutableState<Boolean>> {
    error("LocalBottomBarVisible not provided")
}

@Composable
fun AppScreen(
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = 14.dp,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .then(modifier)
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(contentPadding)
            .padding(horizontal = horizontalPadding, vertical = 8.dp),
    ) {
        content()
    }
}

@Composable
fun Modifier.iosEdgeSwipeBack(
    enabled: Boolean,
    onBack: () -> Unit,
): Modifier {
    if (!enabled) return this
    val edgeWidthPx = with(LocalDensity.current) { 28.dp.toPx() }
    val triggerDistancePx = with(LocalDensity.current) { 84.dp.toPx() }
    return this.pointerInput(enabled) {
        var tracking = false
        var triggered = false
        var distance = 0f
        detectHorizontalDragGestures(
            onDragStart = { offset ->
                tracking = offset.x <= edgeWidthPx
                triggered = false
                distance = 0f
            },
            onHorizontalDrag = { change, dragAmount ->
                if (!tracking || triggered) return@detectHorizontalDragGestures
                if (dragAmount > 0f) {
                    distance += dragAmount
                    change.consume()
                    if (distance >= triggerDistancePx) {
                        triggered = true
                        onBack()
                    }
                } else if (distance > 0f) {
                    distance = (distance + dragAmount).coerceAtLeast(0f)
                }
            },
            onDragEnd = {
                tracking = false
                triggered = false
                distance = 0f
            },
            onDragCancel = {
                tracking = false
                triggered = false
                distance = 0f
            },
        )
    }
}

@Composable
fun CardContainer(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(12.dp))
            .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.38f), RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        content()
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text = text, color = MaterialTheme.colorScheme.onSurface, fontWeight = FontWeight.SemiBold)
}

@Composable
fun EmptyLabel(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun InsetFilterHeader(
    summaryText: String,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(34.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack, modifier = Modifier.size(32.dp)) {
                Icon(
                    imageVector = Icons.Outlined.ChevronLeft,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        } else {
            Spacer(modifier = Modifier.width(32.dp))
        }

        Text(
            text = summaryText,
            modifier = Modifier.weight(1f).padding(horizontal = 10.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            fontSize = 12.sp,
            maxLines = 1,
            textAlign = TextAlign.Center,
            overflow = TextOverflow.Ellipsis,
        )

        IconButton(onClick = onFilterClick, modifier = Modifier.size(32.dp)) {
            Icon(
                imageVector = Icons.Outlined.FilterList,
                contentDescription = "Filters",
                tint = MaterialTheme.colorScheme.onSurface,
            )
        }
    }
}
