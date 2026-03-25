package com.pillyliu.pinprofandroid

import androidx.activity.compose.BackHandler
import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import kotlinx.coroutines.delay

private enum class AppIntroProfessorSide {
    Left,
    Right,
}

private enum class AppIntroCard(
    val title: String?,
    val subtitle: String?,
    val quote: String,
    val highlightedQuotePhrase: String?,
    val accent: Color,
    @get:DrawableRes val artworkResId: Int,
    val artworkAspectRatio: Float,
    val showsProfessorSpotlight: Boolean,
    val professorSide: AppIntroProfessorSide,
) {
    Welcome(
        title = null,
        subtitle = null,
        quote = "Welcome to PinProf, a pinball study app. Go from pinball novice to pinball wizard in no time!",
        highlightedQuotePhrase = "PinProf",
        accent = AppIntroTheme.glow,
        artworkResId = R.drawable.intro_launch_logo,
        artworkAspectRatio = 1f,
        showsProfessorSpotlight = false,
        professorSide = AppIntroProfessorSide.Left,
    ),
    League(
        title = "League",
        subtitle = "Lansing Pinball League stats",
        quote = "Among peers, statistics reveal true standing.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFC3C978),
        artworkResId = R.drawable.intro_league_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
    Library(
        title = "Library",
        subtitle = "Rulesheets, playfields, tutorials",
        quote = "Attend closely; mastery follows diligence.",
        highlightedQuotePhrase = null,
        accent = Color(0xFF8FDBC7),
        artworkResId = R.drawable.intro_library_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Right,
    ),
    Practice(
        title = "Practice",
        subtitle = "Track practice, trends, progress",
        quote = "A careful record reveals true progress.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFFFDB66),
        artworkResId = R.drawable.intro_practice_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
    GameRoom(
        title = "GameRoom",
        subtitle = "Organize machines and upkeep",
        quote = "Order and care are marks of excellence.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFF5C75C),
        artworkResId = R.drawable.intro_gameroom_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Right,
    ),
    Settings(
        title = "Settings",
        subtitle = "Sources, venues, tournaments, data",
        quote = "A well-curated library reflects discernment.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFB8E5C2),
        artworkResId = R.drawable.intro_settings_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
}

private object AppIntroTheme {
    val tint = Color(0xFF1F5742)
    val glow = Color(0xFFA3E0BD)
    val text = Color.White.copy(alpha = 0.96f)
    val secondaryText = Color.White.copy(alpha = 0.84f)
}

private object AppIntroTypography {
    val title = FontFamily(
        Font(R.font.bodoni_moda_variable, weight = FontWeight.Bold),
    )
    val subtitle = FontFamily(
        Font(R.font.cormorant_garamond_variable, weight = FontWeight.SemiBold),
    )
    val quote = FontFamily(
        Font(
            R.font.libre_baskerville_italic_variable,
            weight = FontWeight.SemiBold,
            style = FontStyle.Italic,
        ),
        Font(
            R.font.libre_baskerville_italic_variable,
            weight = FontWeight.Bold,
            style = FontStyle.Italic,
        ),
    )
}

@Composable
private fun AppIntroCard.resolvedAccent(): Color {
    return when (this) {
        AppIntroCard.League -> PinballThemeTokens.colors.statsMeanMedian
        else -> accent
    }
}

@Composable
internal fun AppIntroOverlayHost(
    onDismissed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var visible by rememberSaveable { mutableStateOf(true) }
    val dismissDurationMillis = 260

    BackHandler(enabled = visible) {
        // Keep the modal onboarding flow explicit, matching the iOS-style presentation.
    }

    AnimatedVisibility(
        visible = visible,
        modifier = modifier,
        enter = fadeIn(animationSpec = tween(durationMillis = 220)),
        exit = fadeOut(animationSpec = tween(durationMillis = dismissDurationMillis)),
    ) {
        AppIntroOverlay(
            onDismissRequested = {
                visible = false
            },
        )
    }

    LaunchedEffect(visible) {
        if (!visible) {
            delay(dismissDurationMillis.toLong())
            onDismissed()
        }
    }
}

@Composable
private fun AppIntroOverlay(
    onDismissRequested: () -> Unit,
) {
    val cards = remember { AppIntroCard.entries.toList() }
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { cards.size })

    BoxWithConstraints(
        modifier = Modifier.fillMaxSize(),
    ) {
        val isLandscape = maxWidth > maxHeight
        val horizontalPadding = if (isLandscape) 28.dp else 22.dp
        val verticalPadding = if (isLandscape) 18.dp else 20.dp
        val cardMaxWidth = minOf(
            maxWidth - (horizontalPadding * 2),
            if (isLandscape) 960.dp else 460.dp,
        )
        val showsDismissButton = pagerState.currentPage == cards.lastIndex

        AppIntroBackdrop()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = horizontalPadding)
                .padding(vertical = verticalPadding),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                beyondViewportPageCount = 1,
            ) { page ->
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    AppIntroDeckPage(
                        card = cards[page],
                        isLandscape = isLandscape,
                        modifier = Modifier
                            .fillMaxWidth()
                            .widthIn(max = cardMaxWidth),
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .widthIn(max = cardMaxWidth)
                    .padding(top = 8.dp)
                    .padding(bottom = if (isLandscape) 2.dp else 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                AppIntroPageIndicators(
                    count = cards.size,
                    selectedIndex = pagerState.currentPage,
                )

                if (showsDismissButton) {
                    AppPrimaryButton(
                        onClick = onDismissRequested,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Start Exploring")
                    }
                }
            }
        }
    }
}

@Composable
private fun AppIntroBackdrop() {
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
private fun AppIntroDeckPage(
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
private fun AppIntroCardView(
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
private fun AppIntroArtworkFrame(
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
private fun AppIntroArtworkBox(
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
private fun AppIntroCopyColumn(
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
private fun AppIntroQuoteRow(
    card: AppIntroCard,
    centerAligned: Boolean,
    quoteSize: androidx.compose.ui.unit.TextUnit,
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
    quoteSize: androidx.compose.ui.unit.TextUnit,
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
    quoteSize: androidx.compose.ui.unit.TextUnit,
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
private fun AppIntroProfessorSpotlight(
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

@Composable
private fun AppIntroPageIndicators(
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
