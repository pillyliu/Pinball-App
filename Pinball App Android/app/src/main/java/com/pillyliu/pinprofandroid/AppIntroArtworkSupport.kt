package com.pillyliu.pinprofandroid

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun AppIntroArtworkFrame(
    card: AppIntroCard,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(card.artworkAspectRatio),
    ) {
        AppIntroArtworkBox(
            card = card,
            modifier = Modifier.matchParentSize(),
        )
    }
}

@Composable
internal fun AppIntroArtworkBox(
    card: AppIntroCard,
    modifier: Modifier = Modifier,
) {
    val accent = card.resolvedAccent()
    val shape = RoundedCornerShape(24.dp)

    Box(
        modifier = modifier
            .shadow(
                elevation = 16.dp,
                shape = shape,
                ambientColor = AppIntroTheme.tint.copy(alpha = 0.22f),
                spotColor = AppIntroTheme.tint.copy(alpha = 0.22f),
            )
            .clip(shape)
            .background(PinballThemeTokens.colors.atmosphereBottom.copy(alpha = 0.99f))
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        AppIntroTheme.tint.copy(alpha = 0.26f),
                        Color.Black.copy(alpha = 0.14f),
                        PinballThemeTokens.colors.brandGold.copy(alpha = 0.10f),
                    ),
                ),
            )
            .border(1.15.dp, accent.copy(alpha = 0.72f), shape),
    ) {
        if (card == AppIntroCard.Welcome) {
            Image(
                painter = painterResource(id = card.artworkResId),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    accent.copy(alpha = 0.18f),
                                    Color.Transparent,
                                ),
                                radius = 480f,
                            ),
                        ),
                )
                Image(
                    painter = painterResource(id = card.artworkResId),
                    contentDescription = null,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(1.dp)
                        .shadow(
                            elevation = 16.dp,
                            spotColor = accent.copy(alpha = 0.16f),
                            ambientColor = accent.copy(alpha = 0.16f),
                        ),
                    contentScale = ContentScale.Fit,
                )
            }
        }
    }
}

@Composable
internal fun AppIntroProfessorSpotlight(
    side: AppIntroProfessorSide,
) {
    Box(
        modifier = Modifier.size(82.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AppIntroTheme.glow.copy(alpha = 0.34f),
                            AppIntroTheme.tint.copy(alpha = 0.20f),
                            Color.Transparent,
                        ),
                        radius = 120f,
                    ),
                    CircleShape,
                ),
        )
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(Color.White.copy(alpha = 0.04f), CircleShape)
                .border(1.dp, Color.White.copy(alpha = 0.10f), CircleShape),
        )
        Image(
            painter = painterResource(id = R.drawable.intro_professor_headshot),
            contentDescription = null,
            modifier = Modifier
                .size(80.dp)
                .offset(y = (-2).dp)
                .clip(CircleShape)
                .graphicsLayer {
                    scaleX = if (side == AppIntroProfessorSide.Left) -1f else 1f
                },
            contentScale = ContentScale.Crop,
        )
    }
}
