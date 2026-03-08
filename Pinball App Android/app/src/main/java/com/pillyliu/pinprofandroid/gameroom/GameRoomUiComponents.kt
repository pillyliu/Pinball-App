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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
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
            .height(78.dp)
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
                    text = "$areaName • G${machine.groupNumber ?: "—"} • P${machine.position ?: "—"}",
                    style = MaterialTheme.typography.labelSmall,
                    color = if (imageUrl.isNullOrBlank()) MaterialTheme.colorScheme.onSurfaceVariant else Color.White.copy(alpha = 0.86f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

internal enum class VariantPillStyle {
    Mini,
    Standard,
    MachineTitle,
    EditSelector,
}

@Composable
internal fun ManufacturerFilterDropdown(
    selectedText: String,
    modernOptions: List<GameRoomCatalogManufacturerOption>,
    classicPopularOptions: List<GameRoomCatalogManufacturerOption>,
    otherOptions: List<GameRoomCatalogManufacturerOption>,
    onSelect: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val groups = buildList {
        add(DropdownOptionGroup(options = listOf(DropdownOption("", "All Manufacturers"))))
        if (modernOptions.isNotEmpty()) {
            add(DropdownOptionGroup("Modern", modernOptions.map { DropdownOption(it.id, it.name) }))
        }
        if (classicPopularOptions.isNotEmpty()) {
            add(DropdownOptionGroup("Classic Popular", classicPopularOptions.map { DropdownOption(it.id, it.name) }))
        }
        if (otherOptions.isNotEmpty()) {
            add(DropdownOptionGroup("Other", otherOptions.map { DropdownOption(it.id, it.name) }))
        }
    }
    GroupedAnchoredDropdownFilter(
        selectedText = selectedText,
        groups = groups,
        onSelect = { selection -> onSelect(selection.ifEmpty { null }) },
        modifier = modifier,
    )
}

@Composable
internal fun VariantPillDropdown(
    selectedLabel: String,
    options: List<String>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier = modifier) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = true },
            contentAlignment = Alignment.CenterEnd,
        ) {
            GameRoomVariantPill(label = selectedLabel, style = VariantPillStyle.EditSelector)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    onClick = { onSelect(option); expanded = false },
                )
            }
        }
    }
}

@Composable
internal fun GameRoomVariantPill(
    label: String,
    style: VariantPillStyle,
    modifier: Modifier = Modifier,
) {
    val compactLabel = compactVariantLabel(label)
    val colors = PinballThemeTokens.colors
    if (style == VariantPillStyle.Mini || style == VariantPillStyle.Standard) {
        Text(
            text = compactLabel,
            color = Color.White.copy(alpha = 0.98f),
            style = if (style == VariantPillStyle.Mini) {
                MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
            } else {
                MaterialTheme.typography.labelSmall
            },
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = modifier
                .then(if (style == VariantPillStyle.Mini) Modifier else Modifier.widthIn(max = 84.dp))
                .background(
                    colors.brandGold.copy(alpha = 0.20f),
                    RoundedCornerShape(999.dp),
                )
                .border(1.dp, colors.brandGold.copy(alpha = 0.42f), RoundedCornerShape(999.dp))
                .padding(horizontal = if (style == VariantPillStyle.Mini) 6.dp else 8.dp, vertical = 3.dp),
        )
        return
    }

    AppVariantPill(
        label = compactLabel,
        style = when (style) {
            VariantPillStyle.Mini -> AppVariantPillStyle.Mini
            VariantPillStyle.Standard -> AppVariantPillStyle.Standard
            VariantPillStyle.MachineTitle -> AppVariantPillStyle.MachineTitle
            VariantPillStyle.EditSelector -> AppVariantPillStyle.EditSelector
        },
        modifier = modifier,
        maxWidth = 84.dp,
    )
}

internal fun gameRoomVariantBadgeLabel(variant: String?, title: String): String? {
    val explicit = variant?.trim().orEmpty()
    if (explicit.isNotBlank() && !explicit.equals("null", ignoreCase = true) && !explicit.equals("none", ignoreCase = true)) {
        return explicit
    }

    val source = "${variant.orEmpty().lowercase()} ${title.lowercase()}"
    return when {
        source.contains("limited edition") || source.contains("(le") || source.endsWith(" le") || source.contains(" le)") -> "LE"
        source.contains("premium") -> "Premium"
        source.contains("(pro") || source.endsWith(" pro") || source.contains(" pro)") || variant.equals("pro", ignoreCase = true) -> "Pro"
        else -> null
    }
}

private fun compactVariantLabel(label: String): String {
    val trimmed = label.trim()
    val maxAllowed = 7
    if (trimmed.length <= maxAllowed) return trimmed
    return "${trimmed.take((maxAllowed - 1).coerceAtLeast(0))}…"
}

internal fun machineLocationLine(machine: OwnedMachine, store: GameRoomStore): String {
    val areaName = store.area(machine.gameRoomAreaID)?.name ?: "No area"
    val statusLabel = machine.status.name.replaceFirstChar { it.uppercase() }
    return "Location: $areaName • Group ${machine.groupNumber ?: "—"} • Position ${machine.position ?: "—"} • $statusLabel"
}

internal fun displayMachineEventType(type: MachineEventType): String {
    return type.name
        .replace('_', ' ')
        .lowercase(Locale.US)
        .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() }
}

internal fun displayMachineEventCategory(category: MachineEventCategory): String {
    return category.name
        .replace('_', ' ')
        .lowercase(Locale.US)
        .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString() }
}

internal fun TextStyle.withGameRoomMiniCardOverlayShadow(): TextStyle = copy(
    color = Color.White,
    shadow = Shadow(color = Color.Black.copy(alpha = 1f), blurRadius = 8f, offset = Offset(0f, 3f)),
    lineHeight = when {
        lineHeight != TextUnit.Unspecified -> lineHeight
        fontSize != TextUnit.Unspecified -> (fontSize.value + 2f).sp
        else -> 14.sp
    },
)

internal fun formatDate(valueMs: Long?, fallback: String): String {
    if (valueMs == null || valueMs <= 0L) return fallback
    return java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.US).format(java.util.Date(valueMs))
}

internal fun todayIsoDate(): String = LocalDate.now().toString()

internal fun isoDateFromMillis(valueMs: Long): String {
    return runCatching {
        java.time.Instant.ofEpochMilli(valueMs).atZone(ZoneOffset.UTC).toLocalDate().toString()
    }.getOrElse { todayIsoDate() }
}

internal fun parseIsoDateMillis(raw: String): Long? {
    val parsed = runCatching { LocalDate.parse(raw.trim()) }.getOrNull() ?: return null
    return parsed.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
}

internal fun attentionColor(state: GameRoomAttentionState): Color {
    return when (state) {
        GameRoomAttentionState.red -> Color(0xFFE0524D)
        GameRoomAttentionState.yellow -> Color(0xFFF2C14E)
        GameRoomAttentionState.green -> Color(0xFF53A653)
        GameRoomAttentionState.gray -> Color(0xFF8C9098)
    }
}

@Composable
internal fun SnapshotMetricGrid(
    metrics: List<Pair<String, String>>,
) {
    val rows = metrics.chunked(2)
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { rowMetrics ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                rowMetrics.forEach { (label, value) ->
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            text = value,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                if (rowMetrics.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
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
                    Button(onClick = action, modifier = Modifier.weight(1f)) {
                        Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
                if (rowItems.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}
