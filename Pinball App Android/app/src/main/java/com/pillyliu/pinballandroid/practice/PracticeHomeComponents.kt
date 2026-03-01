package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    val cardShape = RoundedCornerShape(10.dp)
    Box(
        modifier = modifier
            .width(cardWidth)
            .let { base ->
                if (imageHeight != null) {
                    base.height(imageHeight + bottomPadding + 22.dp)
                } else {
                    base
                }
            }
            .background(MaterialTheme.colorScheme.surfaceContainerHighest, shape = cardShape)
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.22f), cardShape)
            .clip(cardShape),
    ) {
        if (!imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = imageUrl,
                contentDescription = game.name,
                contentScale = ContentScale.Crop,
                alignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxSize(),
            )
        }
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
        Text(
            game.name,
            style = titleTextStyle.withMiniCardOverlayShadow(),
            color = Color.White,
            maxLines = if (imageHeight == null) 2 else 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Start,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(horizontal = 8.dp, vertical = titleVerticalPadding + 4.dp),
        )
    }
}

private fun TextStyle.withMiniCardOverlayShadow(): TextStyle = copy(
    color = Color.White,
    shadow = Shadow(
        color = Color.Black.copy(alpha = 1f),
        blurRadius = 8f,
        offset = androidx.compose.ui.geometry.Offset(0f, 3f),
    ),
    lineHeight = when {
        lineHeight != TextUnit.Unspecified -> lineHeight
        fontSize != TextUnit.Unspecified -> (fontSize.value + 2f).sp
        else -> 14.sp
    },
)
