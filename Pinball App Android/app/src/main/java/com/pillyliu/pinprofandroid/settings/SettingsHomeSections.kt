package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard

@Composable
internal fun SettingsHomeContent(
    manufacturers: List<CatalogManufacturerOption>,
    importedSources: List<ImportedSourceRecord>,
    sourceState: LibrarySourceState,
    loading: Boolean,
    error: String?,
    refreshingHostedData: Boolean,
    hostedDataStatusMessage: String?,
    hostedDataStatusIsError: Boolean,
    clearingCache: Boolean,
    cacheStatusMessage: String?,
    cacheStatusIsError: Boolean,
    onOpenAddManufacturer: () -> Unit,
    onOpenAddVenue: () -> Unit,
    onOpenAddTournament: () -> Unit,
    onToggleEnabled: (String, Boolean) -> Unit,
    onTogglePinned: (String, Boolean) -> Unit,
    onRefreshSource: (ImportedSourceRecord) -> Unit,
    onDeleteSource: (String) -> Unit,
    onRefreshHostedData: () -> Unit,
    onClearCache: () -> Unit,
    onToggleIntroOverlayForNextLaunch: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (loading) {
            item {
                AppPanelStatusCard(
                    text = "Loading settings…",
                    showsProgress = true,
                )
            }
        }

        item {
            SettingsAppearanceSection()
        }

        item {
            SettingsLibrarySection(
                manufacturers = manufacturers,
                importedSources = importedSources,
                sourceState = sourceState,
                onOpenAddManufacturer = onOpenAddManufacturer,
                onOpenAddVenue = onOpenAddVenue,
                onOpenAddTournament = onOpenAddTournament,
                onToggleEnabled = onToggleEnabled,
                onTogglePinned = onTogglePinned,
                onRefreshSource = onRefreshSource,
                onDeleteSource = onDeleteSource,
            )
        }

        item {
            SettingsHostedRefreshSection(
                refreshingHostedData = refreshingHostedData,
                hostedDataStatusMessage = hostedDataStatusMessage,
                hostedDataStatusIsError = hostedDataStatusIsError,
                clearingCache = clearingCache,
                cacheStatusMessage = cacheStatusMessage,
                cacheStatusIsError = cacheStatusIsError,
                onRefreshHostedData = onRefreshHostedData,
                onClearCache = onClearCache,
            )
        }

        item {
            SettingsPrivacySection()
        }

        item {
            SettingsAboutSection(
                onToggleIntroOverlayForNextLaunch = onToggleIntroOverlayForNextLaunch,
            )
        }

        error?.let { message ->
            item {
                AppPanelStatusCard(
                    text = message,
                    isError = true,
                )
            }
        }
    }
}
