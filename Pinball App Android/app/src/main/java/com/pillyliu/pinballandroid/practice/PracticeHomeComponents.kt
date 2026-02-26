package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinballandroid.library.miniCardPlayfieldCandidate

@Composable
internal fun QuickEntryHomeButton(
    label: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    OutlinedButton(
        modifier = modifier.heightIn(min = 46.dp),
        onClick = onClick,
        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.height(14.dp),
            )
            Text(
                label,
                style = MaterialTheme.typography.labelSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
internal fun HomeSectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
internal fun HomeMiniCard(
    label: String,
    subtitle: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Card(
        modifier = modifier,
        onClick = onClick,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh),
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 10.dp, vertical = 8.dp)
                .heightIn(min = 72.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.height(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    label,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
internal fun SelectedGameMiniCard(
    game: PinballGame,
    modifier: Modifier = Modifier,
    cardWidth: Dp = 122.dp,
    imageHeight: Dp? = 36.dp,
    titleTextStyle: TextStyle = MaterialTheme.typography.labelSmall,
    bottomPadding: Dp = 12.dp,
    titleVerticalPadding: Dp = 4.dp,
) {
    val imageUrl = game.miniCardPlayfieldCandidate()
    val cardShape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp)
    val imageShape = androidx.compose.foundation.shape.RoundedCornerShape(topStart = 10.dp, topEnd = 10.dp)
    Column(
        modifier = modifier
            .width(cardWidth)
            .clip(cardShape)
            .background(
                MaterialTheme.colorScheme.surfaceContainerHighest,
                shape = cardShape,
            )
            .padding(top = 0.dp, bottom = bottomPadding),
    ) {
        if (imageUrl.isNullOrBlank()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .let { base ->
                        if (imageHeight != null) base.height(imageHeight) else base.weight(1f, fill = true)
                    }
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = imageShape,
                    )
                    .clip(imageShape),
            )
        } else {
            AsyncImage(
                model = imageUrl,
                contentDescription = game.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .let { base ->
                        if (imageHeight != null) base.height(imageHeight) else base.weight(1f, fill = true)
                    }
                    .background(
                        MaterialTheme.colorScheme.surfaceVariant,
                        shape = imageShape,
                    )
                    .clip(imageShape),
            )
        }
        Text(
            game.name,
            style = titleTextStyle,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = titleVerticalPadding),
        )
    }
}
