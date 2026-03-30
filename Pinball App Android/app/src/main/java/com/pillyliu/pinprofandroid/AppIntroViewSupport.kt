package com.pillyliu.pinprofandroid

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun AppIntroBackdrop() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.64f)),
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            AppIntroTheme.tint.copy(alpha = 0.82f),
                            Color.Black.copy(alpha = 0.94f),
                        ),
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AppIntroTheme.glow.copy(alpha = 0.18f),
                            Color.Transparent,
                        ),
                        radius = 700f,
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            PinballThemeTokens.colors.brandGold.copy(alpha = 0.14f),
                            Color.Transparent,
                        ),
                        center = androidx.compose.ui.geometry.Offset(1600f, 2800f),
                        radius = 900f,
                    ),
                ),
        )
    }
}

@Composable
internal fun AppIntroDeckPage(
    card: AppIntroCard,
    isLandscape: Boolean,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(
        modifier = modifier.fillMaxHeight(),
    ) {
        val minimumHeight = (maxHeight - 4.dp).coerceAtLeast(0.dp)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = minimumHeight),
            contentAlignment = Alignment.Center,
        ) {
            AppIntroCardView(
                card = card,
                isLandscape = isLandscape,
            )
        }
    }
}

@Composable
internal fun AppIntroCardView(
    card: AppIntroCard,
    isLandscape: Boolean,
) {
    val shape = RoundedCornerShape(28.dp)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 24.dp,
                shape = shape,
                ambientColor = AppIntroTheme.tint.copy(alpha = 0.32f),
                spotColor = AppIntroTheme.tint.copy(alpha = 0.32f),
            ),
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .clip(shape)
                .background(Color.Black.copy(alpha = 0.76f))
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            AppIntroTheme.tint.copy(alpha = 0.30f),
                            PinballThemeTokens.colors.atmosphereBottom.copy(alpha = 0.12f),
                            PinballThemeTokens.colors.brandGold.copy(alpha = 0.11f),
                        ),
                    ),
                )
                .border(1.1.dp, Color.White.copy(alpha = 0.18f), shape),
        )

        if (isLandscape) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalAlignment = Alignment.Top,
            ) {
                AppIntroArtworkFrame(
                    card = card,
                    modifier = Modifier.width(322.dp),
                )
                AppIntroCopyColumn(
                    card = card,
                    isLandscape = true,
                    modifier = Modifier.weight(1f),
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                AppIntroArtworkFrame(card = card)
                AppIntroCopyColumn(card = card, isLandscape = false)
            }
        }
    }
}

@Composable
internal fun AppIntroCopyColumn(
    card: AppIntroCard,
    isLandscape: Boolean,
    modifier: Modifier = Modifier,
) {
    val alignment = if (isLandscape) TextAlign.Start else TextAlign.Center

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = if (isLandscape) Alignment.Start else Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        card.title?.let { title ->
            Text(
                text = title,
                color = PinballThemeTokens.colors.brandGold,
                textAlign = alignment,
                style = TextStyle(
                    fontFamily = AppIntroTypography.title,
                    fontWeight = FontWeight.Bold,
                    fontSize = if (isLandscape) 24.sp else 26.sp,
                    lineHeight = if (isLandscape) 28.sp else 30.sp,
                    letterSpacing = 0.2.sp,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(modifier = Modifier.height(2.dp))
        }

        card.subtitle?.let { subtitle ->
            Text(
                text = subtitle,
                color = PinballThemeTokens.colors.brandChalk,
                textAlign = alignment,
                style = TextStyle(
                    fontFamily = AppIntroTypography.subtitle,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = if (isLandscape) 16.sp else 17.sp,
                    lineHeight = if (isLandscape) 20.sp else 21.sp,
                    letterSpacing = 0.15.sp,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        AppIntroQuoteRow(
            card = card,
            centerAligned = !isLandscape,
            quoteSize = if (card == AppIntroCard.Welcome) 22.sp else 19.sp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = if (card == AppIntroCard.Welcome) 6.dp else 1.dp),
        )
    }
}

@Composable
internal fun AppIntroQuoteRow(
    card: AppIntroCard,
    centerAligned: Boolean,
    quoteSize: TextUnit,
    modifier: Modifier = Modifier,
) {
    val brandGold = PinballThemeTokens.colors.brandGold

    if (!card.showsProfessorSpotlight) {
        Box(
            modifier = modifier.fillMaxWidth(),
            contentAlignment = if (centerAligned) Alignment.Center else Alignment.CenterStart,
        ) {
            AppIntroQuoteText(
                card = card,
                quoteSize = quoteSize,
                centerAligned = centerAligned,
                brandGold = brandGold,
            )
        }
        return
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (centerAligned) Arrangement.Center else Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (card.professorSide == AppIntroProfessorSide.Left) {
            AppIntroProfessorSpotlight(side = card.professorSide)
            Spacer(modifier = Modifier.width(12.dp))
            Box(modifier = Modifier.weight(1f)) {
                AppIntroQuoteText(
                    card = card,
                    quoteSize = quoteSize,
                    centerAligned = centerAligned,
                    brandGold = brandGold,
                )
            }
        } else {
            Box(modifier = Modifier.weight(1f)) {
                AppIntroQuoteText(
                    card = card,
                    quoteSize = quoteSize,
                    centerAligned = centerAligned,
                    brandGold = brandGold,
                )
            }
            Spacer(modifier = Modifier.width(12.dp))
            AppIntroProfessorSpotlight(side = card.professorSide)
        }
    }
}

@Composable
private fun AppIntroQuoteText(
    card: AppIntroCard,
    quoteSize: TextUnit,
    centerAligned: Boolean,
    brandGold: Color,
) {
    Text(
        text = appIntroQuoteText(
            card = card,
            quoteSize = quoteSize,
            brandGold = brandGold,
        ),
        color = AppIntroTheme.secondaryText,
        textAlign = if (centerAligned) TextAlign.Center else TextAlign.Start,
        lineHeight = (quoteSize.value + 3f).sp,
    )
}

private fun appIntroQuoteText(
    card: AppIntroCard,
    quoteSize: TextUnit,
    brandGold: Color,
) = buildAnnotatedString {
    val baseStyle = SpanStyle(
        color = AppIntroTheme.secondaryText,
        fontFamily = AppIntroTypography.quote,
        fontStyle = FontStyle.Italic,
        fontWeight = FontWeight.SemiBold,
        fontSize = quoteSize,
    )
    val highlightedStyle = baseStyle.copy(fontWeight = FontWeight.Bold)
    val goldHighlightStyle = highlightedStyle.copy(color = brandGold)
    val highlight = card.highlightedQuotePhrase
    val quote = card.quote

    append("“")
    if (highlight != null) {
        val start = quote.indexOf(highlight)
        if (start >= 0) {
            withStyle(baseStyle) {
                append(quote.substring(0, start))
            }
            if (highlight == "PinProf") {
                withStyle(highlightedStyle) {
                    append("Pin")
                }
                withStyle(goldHighlightStyle) {
                    append("Prof")
                }
            } else {
                withStyle(highlightedStyle) {
                    append(highlight)
                }
            }
            withStyle(baseStyle) {
                append(quote.substring(start + highlight.length))
            }
            append("”")
            return@buildAnnotatedString
        }
    }
    withStyle(baseStyle) {
        append(quote)
    }
    append("”")
}

@Composable
internal fun AppIntroPageIndicators(
    count: Int,
    selectedIndex: Int,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { index ->
            val width by animateDpAsState(
                targetValue = if (index == selectedIndex) 34.dp else 18.dp,
                animationSpec = tween(durationMillis = 180),
                label = "appIntroIndicatorWidth",
            )
            val color by animateColorAsState(
                targetValue = if (index == selectedIndex) {
                    PinballThemeTokens.colors.brandGold
                } else {
                    Color.White.copy(alpha = 0.18f)
                },
                animationSpec = tween(durationMillis = 180),
                label = "appIntroIndicatorColor",
            )

            Box(
                modifier = Modifier
                    .width(width)
                    .height(8.dp)
                    .clip(CircleShape)
                    .background(color),
            )
        }
    }
}
