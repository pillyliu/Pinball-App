package com.pillyliu.pinprofandroid.league

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.CardContainer

@Composable
internal fun LeagueCard(
    destination: LeagueDestination,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    titleSize: TextUnit,
    subtitleSize: TextUnit,
    preview: @Composable () -> Unit,
) {
    CardContainer(
        modifier = Modifier
            .then(modifier)
            .fillMaxWidth()
            .heightIn(min = 0.dp)
            .clickable { onClick() },
    ) {
        Column(verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(5.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = destination.icon,
                    contentDescription = destination.title,
                    tint = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = destination.title,
                    color = MaterialTheme.colorScheme.onSurface,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = titleSize,
                )
                Spacer(Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Outlined.ChevronRight,
                    contentDescription = "Open ${destination.title}",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Text(
                text = destination.subtitle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = subtitleSize,
                modifier = Modifier.padding(start = 28.dp),
            )

            Column(modifier = Modifier.padding(start = 28.dp)) {
                preview()
            }
        }
    }
}
