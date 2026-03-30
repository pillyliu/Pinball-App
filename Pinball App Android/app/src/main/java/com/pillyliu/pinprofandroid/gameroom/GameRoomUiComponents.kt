package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.library.rememberCachedImageModel
import com.pillyliu.pinprofandroid.ui.AppMediaPreviewPlaceholder
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AppVariantPill
import com.pillyliu.pinprofandroid.ui.AppVariantPillStyle
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.DropdownOptionGroup
import com.pillyliu.pinprofandroid.ui.GroupedAnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

@Composable
internal fun MiniMachineCard(
    machine: OwnedMachine,
    imageUrl: String?,
    attentionState: GameRoomAttentionState,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val outerShape = RoundedCornerShape(12.dp)
    val innerShape = RoundedCornerShape(10.dp)
    val imageModel = rememberCachedImageModel(imageUrl)
    var imageLoaded by remember(imageUrl) { mutableStateOf(false) }
    var showMissingImage by remember(imageUrl) { mutableStateOf(imageUrl.isNullOrBlank()) }
    val selectionHighlightColor = colors.brandGold.copy(alpha = 0.9f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(64.dp)
            .clickable(onClick = onClick)
            .border(width = 2.dp, color = if (selected) selectionHighlightColor else Color.Transparent, shape = outerShape)
            .padding(2.dp)
            .background(MaterialTheme.colorScheme.surfaceContainerHighest, innerShape)
            .border(width = 1.dp, color = colors.brandChalk.copy(alpha = 0.22f), shape = innerShape)
            .graphicsLayer {
                clip = true
                shape = innerShape
            },
    ) {
        if (!imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = imageModel,
                contentDescription = machine.displayTitle,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                onLoading = {
                    imageLoaded = false
                    showMissingImage = false
                },
                onSuccess = {
                    imageLoaded = true
                    showMissingImage = false
                },
                onError = {
                    imageLoaded = false
                    showMissingImage = true
                },
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            0.18f to Color.Transparent,
                            0.4f to Color.Black.copy(alpha = 0.50f),
                            1f to Color.Black.copy(alpha = 0.78f),
                        ),
                    ),
            )
        } else {
            AppMediaPreviewPlaceholder(message = "No image")
        }

        if (!imageUrl.isNullOrBlank()) {
            when {
                !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
                showMissingImage -> AppMediaPreviewPlaceholder()
            }
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 8.dp, vertical = 6.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Spacer(modifier = Modifier.weight(1f))
                Box(
                    modifier = Modifier
                        .padding(start = 6.dp)
                        .size(10.dp)
                        .background(attentionColor(attentionState), RoundedCornerShape(999.dp))
                        .border(1.dp, colors.brandInk.copy(alpha = 0.24f), RoundedCornerShape(999.dp)),
                )
            }
            Column {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = machine.displayTitle,
                        style = MaterialTheme.typography.bodyMedium.withGameRoomMiniCardOverlayShadow(),
                        color = if (imageUrl.isNullOrBlank()) MaterialTheme.colorScheme.onSurface else Color.White,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    val variantLabel = gameRoomVariantBadgeLabel(machine.displayVariant, machine.displayTitle)
                    if (variantLabel != null) {
                        GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.Mini, modifier = Modifier.padding(start = 6.dp))
                    }
                }
            }
        }
    }
}

@Composable
internal fun MachineListRow(
    machine: OwnedMachine,
    imageUrl: String?,
    areaName: String,
    attentionState: GameRoomAttentionState,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val cardShape = RoundedCornerShape(10.dp)
    val imageModel = rememberCachedImageModel(imageUrl)
    var imageLoaded by remember(imageUrl) { mutableStateOf(false) }
    var showMissingImage by remember(imageUrl) { mutableStateOf(imageUrl.isNullOrBlank()) }
    val selectionHighlightColor = colors.brandGold.copy(alpha = 0.9f)
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .clickable(onClick = onClick)
            .background(MaterialTheme.colorScheme.surfaceContainerHighest, cardShape)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) selectionHighlightColor else colors.brandChalk.copy(alpha = 0.22f),
                shape = cardShape,
            )
            .graphicsLayer {
                clip = true
                shape = cardShape
            },
    ) {
        if (!imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = imageModel,
                contentDescription = machine.displayTitle,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                onLoading = {
                    imageLoaded = false
                    showMissingImage = false
                },
                onSuccess = {
                    imageLoaded = true
                    showMissingImage = false
                },
                onError = {
                    imageLoaded = false
                    showMissingImage = true
                },
            )
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            0f to Color.Transparent,
                            0.18f to Color.Transparent,
                            0.4f to Color.Black.copy(alpha = 0.50f),
                            1f to Color.Black.copy(alpha = 0.78f),
                        ),
                    ),
            )
        } else {
            AppMediaPreviewPlaceholder(message = "No image")
        }

        if (!imageUrl.isNullOrBlank()) {
            when {
                !imageLoaded && !showMissingImage -> AppMediaPreviewPlaceholder(showsProgress = true)
                showMissingImage -> AppMediaPreviewPlaceholder()
            }
        }

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(9.dp)
                    .background(attentionColor(attentionState), RoundedCornerShape(999.dp))
                    .border(1.dp, colors.brandInk.copy(alpha = 0.24f), RoundedCornerShape(999.dp)),
            )
            Spacer(modifier = Modifier.width(8.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = machine.displayTitle,
                        style = MaterialTheme.typography.bodyMedium.withGameRoomMiniCardOverlayShadow(),
                        color = if (imageUrl.isNullOrBlank()) MaterialTheme.colorScheme.onSurface else Color.White,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    val variantLabel = gameRoomVariantBadgeLabel(machine.displayVariant, machine.displayTitle)
                    if (variantLabel != null) {
                        GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.Standard, modifier = Modifier.padding(start = 8.dp))
                    }
                }
                Text(
                    text = gameRoomLocationText(
                        areaName = areaName,
                        groupNumber = machine.groupNumber,
                        position = machine.position,
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (imageUrl.isNullOrBlank()) MaterialTheme.colorScheme.onSurfaceVariant else Color.White.copy(alpha = 0.86f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
internal fun SectionHeader(
    title: String,
    expanded: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Icon(
            imageVector = if (expanded) Icons.Outlined.ChevronLeft else Icons.Outlined.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
internal fun TwoColumnButtons(items: List<Pair<String, () -> Unit>>) {
    val rows = items.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { rowItems ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowItems.forEach { (title, action) ->
                    AppSecondaryButton(
                        onClick = action,
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = 44.dp),
                    ) {
                        Text(
                            text = title,
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
