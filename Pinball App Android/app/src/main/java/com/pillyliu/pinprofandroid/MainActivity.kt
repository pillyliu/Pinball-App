package com.pillyliu.pinprofandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.pillyliu.pinprofandroid.data.getAppDisplayMode
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.refreshRedactedPlayersFromCsv
import com.pillyliu.pinprofandroid.library.migrateLegacyPinnedVenueImportsIfNeeded
import com.pillyliu.pinprofandroid.library.warmHostedCAFData
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        PinballDataCache.initialize(applicationContext)
        applyPinballEdgeToEdge(
            activity = this,
            darkTheme = appUsesDarkTheme(getAppDisplayMode(this), this),
        )
        lifecycleScope.launch {
            migrateLegacyPinnedVenueImportsIfNeeded(applicationContext)
        }
        lifecycleScope.launch {
            refreshRedactedPlayersFromCsv()
        }
        lifecycleScope.launch {
            warmHostedCAFData()
        }
        setContent { PinballApp() }
    }

    override fun onResume() {
        super.onResume()
        PinballDataCache.requestMetadataRefresh(force = true)
        lifecycleScope.launch {
            migrateLegacyPinnedVenueImportsIfNeeded(applicationContext)
        }
        lifecycleScope.launch {
            refreshRedactedPlayersFromCsv()
        }
    }
}
