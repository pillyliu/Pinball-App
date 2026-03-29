package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppFullscreenStage
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.LocalBottomBarVisible

@Composable
internal fun PlayfieldScreen(
    contentPadding: PaddingValues,
    title: String,
    imageUrls: List<String>,
    onBack: () -> Unit,
) {
    val bottomBarVisible = LocalBottomBarVisible.current
    var chromeVisible by rememberSaveable(title) { mutableStateOf(false) }
    val adaptiveTitleColor = rememberPlayfieldTitleColor(imageUrls)

    LaunchedEffect(chromeVisible) {
        bottomBarVisible.value = chromeVisible
    }
    DisposableEffect(Unit) {
        onDispose { bottomBarVisible.value = true }
    }

    AppFullscreenStage(onBack = onBack) {
        ZoomablePlayfieldImage(
            imageUrls = imageUrls,
            title = title,
            modifier = Modifier.fillMaxSize(),
            onTap = { chromeVisible = !chromeVisible },
        )

        if (chromeVisible) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(contentPadding)
                    .padding(start = 14.dp, end = 14.dp, top = 8.dp),
            ) {
                AppScreenHeader(
                    title = title,
                    onBack = onBack,
                    modifier = Modifier.align(Alignment.Center),
                    titleColor = adaptiveTitleColor,
                )
            }
        }
    }
}
