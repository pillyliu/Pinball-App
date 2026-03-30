package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun SettingsHostedRefreshSection(
    refreshingHostedData: Boolean,
    hostedDataStatusMessage: String?,
    hostedDataStatusIsError: Boolean,
    clearingCache: Boolean,
    cacheStatusMessage: String?,
    cacheStatusIsError: Boolean,
    onRefreshHostedData: () -> Unit,
    onClearCache: () -> Unit,
) {
    CardContainer {
        SectionTitle("Pinball Data")
        Text(
            "Force-refresh the hosted OPDB export, CAF asset indexes, league files, and redacted players list from pillyliu.com.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = onRefreshHostedData,
            modifier = Modifier.fillMaxWidth(),
            enabled = !refreshingHostedData && !clearingCache,
        ) {
            Text(if (refreshingHostedData) "Refreshing Pinball Data..." else "Refresh Pinball Data")
        }
        when {
            hostedDataStatusMessage != null -> {
                AppInlineTaskStatus(
                    text = hostedDataStatusMessage,
                    showsProgress = refreshingHostedData,
                    isError = hostedDataStatusIsError,
                )
            }

            refreshingHostedData -> {
                AppInlineTaskStatus(
                    text = "Refreshing hosted pinball data…",
                    showsProgress = true,
                )
            }
        }

        Text(
            "Clear Cache removes downloaded pinball data, cached images, and cached web rulesheet data. It does not remove settings, practice history, or GameRoom data.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppSecondaryButton(
            onClick = onClearCache,
            modifier = Modifier.fillMaxWidth(),
            enabled = !refreshingHostedData && !clearingCache,
        ) {
            Text(if (clearingCache) "Clearing Cache..." else "Clear Cache")
        }
        when {
            cacheStatusMessage != null -> {
                AppInlineTaskStatus(
                    text = cacheStatusMessage,
                    showsProgress = clearingCache,
                    isError = cacheStatusIsError,
                )
            }

            clearingCache -> {
                AppInlineTaskStatus(
                    text = "Clearing cached data…",
                    showsProgress = true,
                )
            }
        }
    }
}
