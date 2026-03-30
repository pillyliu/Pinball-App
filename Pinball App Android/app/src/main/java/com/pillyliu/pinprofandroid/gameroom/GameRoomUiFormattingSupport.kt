package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

internal fun gameRoomLocationText(
    areaName: String?,
    groupNumber: Int?,
    position: Int?,
): String {
    val group = groupNumber?.toString() ?: "—"
    val pos = position?.toString() ?: "—"
    val normalizedArea = areaName
        ?.trim()
        ?.takeUnless {
            it.isBlank() ||
                it.equals("null", ignoreCase = true) ||
                it.equals("no area", ignoreCase = true)
        }
    return if (normalizedArea != null) {
        "📍 $normalizedArea:$group:$pos"
    } else {
        "📍 $group:$pos"
    }
}

internal fun machineLocationLine(machine: OwnedMachine, store: GameRoomStore): String {
    return gameRoomLocationText(
        areaName = store.area(machine.gameRoomAreaID)?.name,
        groupNumber = machine.groupNumber,
        position = machine.position,
    )
}

internal fun gameRoomMachineMetaLine(machine: OwnedMachine, store: GameRoomStore): String {
    val parts = mutableListOf<String>()
    machine.manufacturer?.trim()?.takeUnless { it.isBlank() || it.equals("null", ignoreCase = true) }?.let { parts += it }
    machine.year?.let { parts += it.toString() }
    parts += machineLocationLine(machine, store)
    return parts.joinToString(" • ")
}

internal fun gameRoomStatusLabel(status: OwnedMachineStatus): String {
    return status.name.replaceFirstChar { it.uppercase() }
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
