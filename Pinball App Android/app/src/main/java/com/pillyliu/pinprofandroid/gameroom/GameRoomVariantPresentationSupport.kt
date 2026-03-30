package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppVariantPill
import com.pillyliu.pinprofandroid.ui.AppVariantPillStyle
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.DropdownOptionGroup
import com.pillyliu.pinprofandroid.ui.GroupedAnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

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
            color = Color.White,
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
                .padding(horizontal = if (style == VariantPillStyle.Mini) 6.dp else 8.dp, vertical = 3.dp)
                .offset(y = (-1).dp),
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
    if (explicit.isNotBlank() &&
        !explicit.equals("null", ignoreCase = true) &&
        !explicit.equals("none", ignoreCase = true) &&
        !explicit.equals("premium/le", ignoreCase = true) &&
        !explicit.equals("premium le", ignoreCase = true) &&
        !explicit.equals("premium-le", ignoreCase = true)
    ) {
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
