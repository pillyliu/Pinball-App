package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton

@Composable
internal fun PracticeInputButton(label: String, onClick: () -> Unit) {
    AppSecondaryButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(label)
            Spacer(Modifier.weight(1f))
            androidx.compose.material3.Icon(Icons.Outlined.Add, contentDescription = null)
        }
    }
}

@Composable
internal fun PracticeInputGridButton(
    label: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    AppSecondaryButton(
        onClick = onClick,
        modifier = modifier.heightIn(min = 58.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(icon, contentDescription = null)
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
            )
        }
    }
}

@Composable
internal fun NextActionBlock(store: PracticeStore, gameSlug: String) {
    val scoreCount = store.scoreValuesFor(gameSlug).size
    val summary = store.scoreSummaryFor(gameSlug)
    val line = when {
        scoreCount == 0 -> "Start with a logged score for this game."
        scoreCount < 3 -> "Log at least 3 scores to establish baseline consistency."
        summary != null && summary.stdev > summary.mean * 0.35 -> "High variance: focus on repeatable safe scoring paths."
        else -> "Add a fresh score and one practice note to keep trend data current."
    }
    androidx.compose.foundation.layout.Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        AppCardSubheading("Next Action")
        Text(line, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
internal fun AlertsBlock(store: PracticeStore, gameSlug: String) {
    val alerts = store.dashboardAlertsFor(gameSlug)
    if (alerts.isEmpty()) return
    androidx.compose.foundation.layout.Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        AppCardSubheading("Alerts")
        alerts.forEach { alert ->
            val color = when (alert.severity) {
                PracticeDashboardAlert.Severity.INFO -> MaterialTheme.colorScheme.onSurfaceVariant
                PracticeDashboardAlert.Severity.WARNING -> MaterialTheme.colorScheme.tertiary
                PracticeDashboardAlert.Severity.CAUTION -> MaterialTheme.colorScheme.error
            }
            Text("• ${alert.message}", style = MaterialTheme.typography.bodySmall, color = color)
        }
    }
}

@Composable
internal fun ConsistencyBlock(store: PracticeStore, gameSlug: String) {
    val summary = store.scoreSummaryFor(gameSlug)
    val text = if (summary == null || summary.median <= 0.0) {
        "Log more scores to unlock floor/variance guidance."
    } else {
        val spreadRatio = (summary.targetHigh - summary.targetFloor) / summary.median
        if (spreadRatio >= 0.6) {
            "High variance: raise your floor through repeatable safe paths."
        } else {
            "Stable spread: keep pressure on median improvements."
        }
    }
    androidx.compose.foundation.layout.Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        AppCardSubheading("Consistency")
        Text(text, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
internal fun StatRow(label: String, value: String, tint: Color? = null) {
    val rowColor = tint ?: MaterialTheme.colorScheme.onSurface
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(label, color = rowColor)
        Spacer(Modifier.weight(1f))
        Text(value, fontWeight = FontWeight.SemiBold, color = rowColor)
    }
}
