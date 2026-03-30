package com.pillyliu.pinprofandroid

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.libraryMissingArtworkPath
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
internal fun AppShakeWarningHost(
    overlayLevel: AppShakeWarningLevel?,
    modifier: Modifier = Modifier,
) {
    AnimatedVisibility(
        visible = overlayLevel != null,
        modifier = modifier,
        enter = fadeIn(animationSpec = tween(durationMillis = 180)),
        exit = fadeOut(animationSpec = tween(durationMillis = 300)),
    ) {
        overlayLevel?.let { level ->
            AppShakeWarningOverlay(
                level = level,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@Composable
private fun AppShakeWarningOverlay(
    level: AppShakeWarningLevel,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val isLandscape = maxWidth > maxHeight
        val outerHorizontalPadding = 28.dp
        val outerVerticalPadding = 24.dp
        val cardHorizontalPadding = if (isLandscape) 22.dp else 28.dp
        val cardVerticalPadding = if (isLandscape) 20.dp else 24.dp
        val landscapeSpacing = 20.dp
        val maxLandscapeCardWidth = (maxWidth - (outerHorizontalPadding * 2)).coerceAtMost(760.dp)
        val maxLandscapeCardHeight = (maxHeight - (outerVerticalPadding * 2)).coerceAtMost(340.dp)
        val landscapePaneWidth = minOf(
            (maxLandscapeCardWidth - (cardHorizontalPadding * 2) - landscapeSpacing) / 2,
            maxLandscapeCardHeight - (cardVerticalPadding * 2),
        )
        val landscapeCardWidth = (landscapePaneWidth * 2) + landscapeSpacing + (cardHorizontalPadding * 2)
        val landscapeCardHeight = landscapePaneWidth + (cardVerticalPadding * 2)
        val portraitCardWidth = (maxWidth - (outerHorizontalPadding * 2))
            .coerceAtLeast(280.dp)
            .coerceAtMost(420.dp)
        val portraitImageSide = minOf(portraitCardWidth - (cardHorizontalPadding * 2), 360.dp)
        val cardShape = RoundedCornerShape(28.dp)

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            level.tint.copy(alpha = if (level == AppShakeWarningLevel.Tilt) 0.32f else 0.20f),
                            Color.Black.copy(alpha = if (level == AppShakeWarningLevel.Tilt) 0.58f else 0.42f),
                        ),
                    ),
                ),
        )

        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .padding(horizontal = outerHorizontalPadding, vertical = outerVerticalPadding)
                    .then(
                        if (isLandscape) {
                            Modifier
                                .width(landscapeCardWidth)
                                .height(landscapeCardHeight)
                        } else {
                            Modifier.width(portraitCardWidth)
                        },
                    )
                    .shadow(28.dp, cardShape)
                    .clip(cardShape)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                colors.panel.copy(alpha = 0.94f),
                                colors.atmosphereBottom.copy(alpha = 0.96f),
                            ),
                        ),
                    )
                    .border(1.2.dp, level.glow.copy(alpha = 0.78f), cardShape),
            ) {
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(
                            Brush.linearGradient(
                                colors = listOf(
                                    level.glow.copy(alpha = 0.34f),
                                    Color.Transparent,
                                    level.tint.copy(alpha = 0.22f),
                                ),
                                start = Offset.Zero,
                                end = Offset(1600f, 1600f),
                            ),
                        ),
                )

                if (isLandscape) {
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = cardHorizontalPadding, vertical = cardVerticalPadding),
                        horizontalArrangement = Arrangement.spacedBy(landscapeSpacing, Alignment.CenterHorizontally),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AppShakeProfessorArt(
                            level = level,
                            boxSide = landscapePaneWidth,
                        )
                        AppShakeWarningCopy(
                            level = level,
                            isLandscape = true,
                            modifier = Modifier
                                .width(landscapePaneWidth)
                                .height(landscapePaneWidth),
                        )
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = cardHorizontalPadding, vertical = cardVerticalPadding),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(18.dp),
                    ) {
                        AppShakeProfessorArt(
                            level = level,
                            boxSide = portraitImageSide,
                        )
                        AppShakeWarningCopy(
                            level = level,
                            isLandscape = false,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AppShakeWarningCopy(
    level: AppShakeWarningLevel,
    isLandscape: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = if (isLandscape) Alignment.Start else Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            repeat(AppShakeWarningLevel.entries.size) { index ->
                Box(
                    modifier = Modifier
                        .width(if (isLandscape) 44.dp else 52.dp)
                        .height(8.dp)
                        .clip(RoundedCornerShape(999.dp))
                        .background(
                            if (index < level.ordinal + 1) {
                                level.glow
                            } else {
                                Color.White.copy(alpha = 0.14f)
                            },
                        ),
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = level.title,
            color = level.glow,
            style = TextStyle(
                fontSize = 34.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = 2.5.sp,
            ),
            textAlign = if (isLandscape) TextAlign.Start else TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = level.subtitle,
            color = Color.White.copy(alpha = 0.88f),
            style = appShakeProfessorSubtitleStyle(),
            textAlign = if (isLandscape) TextAlign.Start else TextAlign.Center,
            modifier = if (isLandscape) Modifier else Modifier.widthIn(max = 320.dp),
        )
    }
}

@Composable
private fun appShakeProfessorSubtitleStyle(): TextStyle {
    return MaterialTheme.typography.bodyMedium.copy(
        fontSize = 17.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = FontFamily.Serif,
        fontStyle = FontStyle.Italic,
        lineHeight = 22.sp,
    )
}

@Composable
private fun AppShakeProfessorArt(
    level: AppShakeWarningLevel,
    boxSide: Dp,
) {
    val colors = PinballThemeTokens.colors
    val shape = RoundedCornerShape(24.dp)
    val image = rememberAppShakeProfessorArt(level)

    Box(
        modifier = Modifier
            .size(boxSide)
            .shadow(18.dp, shape)
            .clip(shape)
            .background(colors.atmosphereBottom.copy(alpha = 0.96f))
            .border(1.2.dp, level.glow.copy(alpha = 0.72f), shape),
        contentAlignment = Alignment.Center,
    ) {
        if (image != null) {
            Image(
                bitmap = image,
                contentDescription = level.title,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop,
            )
        } else {
            AppShakeProfessorEmergencyPlaceholder(
                level = level,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(14.dp),
            )
        }
    }
}

@Composable
private fun rememberAppShakeProfessorArt(level: AppShakeWarningLevel): ImageBitmap? {
    val context = LocalContext.current.applicationContext
    val image by produceState<ImageBitmap?>(initialValue = null, key1 = context, key2 = level) {
        value = withContext(Dispatchers.IO) {
            decodeBundledAppAssetImage(context, level.bundledArtAssetPath)
                ?: decodeCachedPinballImage(libraryMissingArtworkPath)
        }
    }
    return image
}

private fun decodeBundledAppAssetImage(context: Context, assetPath: String): ImageBitmap? {
    val bytes = runCatching { context.assets.open(assetPath).use { it.readBytes() } }.getOrNull() ?: return null
    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
    return bitmap.asImageBitmap()
}

private suspend fun decodeCachedPinballImage(path: String): ImageBitmap? {
    val bytes = PinballDataCache.loadBytes(path, allowMissing = true).bytes ?: return null
    val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
    return bitmap.asImageBitmap()
}

@Composable
private fun AppShakeProfessorEmergencyPlaceholder(
    level: AppShakeWarningLevel,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.Black.copy(alpha = 0.76f),
                        level.tint.copy(alpha = 0.18f),
                        colors.brandInk.copy(alpha = 0.92f),
                    ),
                    start = Offset.Zero,
                    end = Offset(1200f, 1200f),
                ),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically),
        ) {
            Icon(
                imageVector = Icons.Outlined.Photo,
                contentDescription = null,
                tint = level.glow.copy(alpha = 0.94f),
                modifier = Modifier.size(56.dp),
            )
            Box(
                modifier = Modifier
                    .widthIn(max = 220.dp)
                    .heightIn(min = 92.dp),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(12.dp))
                        .background(colors.atmosphereBottom)
                        .border(1.dp, colors.brandChalk.copy(alpha = 0.2f), RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "Sorry, no image available",
                        color = colors.brandChalk,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 12.dp),
                    )
                }
            }
            Text(
                text = "Shared warning art failed to load.",
                color = Color.White.copy(alpha = 0.7f),
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
            )
        }
    }
}
