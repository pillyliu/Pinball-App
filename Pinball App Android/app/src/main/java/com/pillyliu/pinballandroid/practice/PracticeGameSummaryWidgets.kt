package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
internal fun PracticeInputButton(label: String, onClick: () -> Unit) {
    OutlinedButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Text(label)
            Spacer(Modifier.weight(1f))
            androidx.compose.material3.Icon(Icons.Outlined.Add, contentDescription = null)
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
        Text("Next Action", fontWeight = FontWeight.SemiBold)
        Text(line, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
internal fun AlertsBlock(store: PracticeStore, gameSlug: String) {
    val rows = store.journalItems(JournalFilter.All).filter { it.gameSlug == gameSlug }
    val latestStudy = rows.firstOrNull { it.action == "study" }?.timestampMs
    val latestPractice = rows.firstOrNull { it.action == "practice" }?.timestampMs
    val now = System.currentTimeMillis()
    val dayMs = 24L * 60L * 60L * 1000L
    val alerts = buildList {
        if (latestStudy == null) add("No rulesheet/study activity logged yet.")
        else {
            val days = ((now - latestStudy) / dayMs).toInt()
            if (days >= 7) add("Rulesheet/study activity is stale ($days days).")
        }
        if (latestPractice == null) add("No practice sessions logged yet.")
    }
    if (alerts.isEmpty()) return
    androidx.compose.foundation.layout.Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text("Alerts", fontWeight = FontWeight.SemiBold)
        alerts.forEach { line ->
            Text("• $line", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.tertiary)
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
        Text("Consistency", fontWeight = FontWeight.SemiBold)
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
