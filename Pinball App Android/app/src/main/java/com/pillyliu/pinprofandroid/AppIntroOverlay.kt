package com.pillyliu.pinprofandroid

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
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
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import kotlinx.coroutines.delay

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
