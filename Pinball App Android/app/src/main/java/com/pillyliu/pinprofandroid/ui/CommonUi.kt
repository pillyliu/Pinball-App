package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp

@Composable
fun CardContainer(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val spacing = PinballThemeTokens.spacing
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.panel, RoundedCornerShape(shapes.panelCorner))
            .border(1.dp, colors.brandChalk.copy(alpha = 0.22f), RoundedCornerShape(shapes.panelCorner))
            .padding(spacing.panelPadding),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        CompositionLocalProvider(LocalContentColor provides colors.brandInk) {
            content()
        }
    }
}

data class AppSwipeActionSpec(
    val tint: Color,
    val icon: ImageVector,
    val contentDescription: String,
    val onTrigger: () -> Unit,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppSwipeActionRow(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(8.dp),
    startAction: AppSwipeActionSpec? = null,
    endAction: AppSwipeActionSpec? = null,
    containerColor: Color = MaterialTheme.colorScheme.surfaceContainerLow,
    borderColor: Color = MaterialTheme.colorScheme.outline.copy(alpha = 0.72f),
    content: @Composable () -> Unit,
) {
    val currentStartAction = rememberUpdatedState(startAction)
    val currentEndAction = rememberUpdatedState(endAction)
    val swipeState = rememberSwipeToDismissBoxState(
        confirmValueChange = { targetValue ->
            when (targetValue) {
                SwipeToDismissBoxValue.StartToEnd -> {
                    currentStartAction.value?.onTrigger?.invoke()
                    false
                }

                SwipeToDismissBoxValue.EndToStart -> {
                    currentEndAction.value?.onTrigger?.invoke()
                    false
                }

                SwipeToDismissBoxValue.Settled -> true
            }
        },
    )

    SwipeToDismissBox(
        state = swipeState,
        enableDismissFromStartToEnd = startAction != null,
        enableDismissFromEndToStart = endAction != null,
        modifier = modifier
            .clip(shape)
            .background(containerColor, shape)
            .border(1.dp, borderColor, shape),
        backgroundContent = {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 1.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                startAction?.let { action ->
                    SwipeActionBackgroundButton(
                        modifier = Modifier
                            .width(76.dp)
                            .fillMaxHeight(),
                        tint = action.tint,
                        icon = action.icon,
                        contentDescription = action.contentDescription,
                    )
                } ?: Spacer(modifier = Modifier.width(0.dp))

                Spacer(modifier = Modifier.weight(1f))

                endAction?.let { action ->
                    SwipeActionBackgroundButton(
                        modifier = Modifier
                            .width(76.dp)
                            .fillMaxHeight(),
                        tint = action.tint,
                        icon = action.icon,
                        contentDescription = action.contentDescription,
                    )
                } ?: Spacer(modifier = Modifier.width(0.dp))
            }
        },
        content = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(shape)
                    .background(containerColor, shape),
            ) {
                content()
            }
        },
    )
}

@Composable
private fun SwipeActionBackgroundButton(
    modifier: Modifier,
    tint: Color,
    icon: ImageVector,
    contentDescription: String,
) {
    Box(
        modifier = modifier.background(tint, shape = RoundedCornerShape(6.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Color.White)
    }
}

@Composable
fun AppControlCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.controlBackground, RoundedCornerShape(shapes.controlCorner))
            .border(1.dp, colors.brandGold.copy(alpha = 0.28f), RoundedCornerShape(shapes.controlCorner))
            .padding(contentPadding),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

@Composable
fun InsetFilterHeader(
    summaryText: String,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
) {
    val colors = PinballThemeTokens.colors
    val typography = PinballThemeTokens.typography
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(34.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            AppBackButton(onClick = onBack, size = 32.dp, iconSize = 18.dp)
        } else {
            Spacer(modifier = Modifier.width(32.dp))
        }

        Text(
            text = summaryText,
            modifier = Modifier.weight(1f).padding(horizontal = 10.dp),
            color = colors.brandChalk,
            style = typography.filterSummary,
            maxLines = 1,
            textAlign = TextAlign.Center,
            overflow = TextOverflow.Ellipsis,
        )

        IconButton(onClick = onFilterClick, modifier = Modifier.size(32.dp)) {
            Icon(
                imageVector = Icons.Outlined.FilterList,
                contentDescription = "Filters",
                tint = colors.brandGold,
            )
        }
    }
}
