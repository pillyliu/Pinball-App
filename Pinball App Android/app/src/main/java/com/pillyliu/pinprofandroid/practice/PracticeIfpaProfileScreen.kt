package com.pillyliu.pinprofandroid.practice

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppExternalLinkButton
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitle
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
internal fun PracticeIfpaProfileScreen(
    playerName: String,
    ifpaPlayerID: String,
) {
    val trimmedIfpaPlayerID = ifpaPlayerID.trim()
    val context = LocalContext.current
    var profile by remember(trimmedIfpaPlayerID) { mutableStateOf<IfpaPlayerProfile?>(null) }
    var isLoading by remember(trimmedIfpaPlayerID) { mutableStateOf(false) }
    var errorMessage by remember(trimmedIfpaPlayerID) { mutableStateOf<String?>(null) }
    var cachedProfileUpdatedAtMs by remember(trimmedIfpaPlayerID) { mutableStateOf<Long?>(null) }
    var staleSnapshotFailureMessage by remember(trimmedIfpaPlayerID) { mutableStateOf<String?>(null) }
    val uriHandler = LocalUriHandler.current
    val coroutineScope = rememberCoroutineScope()
    val staleSnapshotNotice = remember(cachedProfileUpdatedAtMs, staleSnapshotFailureMessage) {
        val cachedAt = cachedProfileUpdatedAtMs ?: return@remember null
        val failureMessage = staleSnapshotFailureMessage ?: return@remember null
        "Showing your last saved IFPA snapshot from ${formatIfpaCachedAt(cachedAt)}. It may be outdated because the latest refresh failed. $failureMessage"
    }

    suspend fun loadProfile(cachedSnapshot: IfpaCachedProfileSnapshot? = null) {
        if (trimmedIfpaPlayerID.isBlank()) return
        val resolvedCachedSnapshot = cachedSnapshot ?: withContext(Dispatchers.IO) {
            IfpaProfileCacheStore.load(context, trimmedIfpaPlayerID)
        }
        isLoading = true
        errorMessage = null
        runCatching {
            IfpaPublicProfileService.fetchProfile(trimmedIfpaPlayerID)
        }.onSuccess {
            profile = it
            cachedProfileUpdatedAtMs = null
            staleSnapshotFailureMessage = null
            withContext(Dispatchers.IO) {
                IfpaProfileCacheStore.save(context, it)
            }
        }.onFailure {
            if (resolvedCachedSnapshot != null) {
                profile = resolvedCachedSnapshot.profile
                cachedProfileUpdatedAtMs = resolvedCachedSnapshot.cachedAtEpochMs
                staleSnapshotFailureMessage = it.message ?: "Could not load IFPA profile."
                errorMessage = null
            } else {
                profile = null
                cachedProfileUpdatedAtMs = null
                staleSnapshotFailureMessage = null
                errorMessage = it.message ?: "Could not load IFPA profile."
            }
        }
        isLoading = false
    }

    LaunchedEffect(trimmedIfpaPlayerID) {
        profile = null
        errorMessage = null
        cachedProfileUpdatedAtMs = null
        staleSnapshotFailureMessage = null
        if (trimmedIfpaPlayerID.isNotBlank()) {
            val cachedSnapshot = withContext(Dispatchers.IO) {
                IfpaProfileCacheStore.load(context, trimmedIfpaPlayerID)
            }
            profile = cachedSnapshot?.profile
            loadProfile(cachedSnapshot)
        }
    }

    when {
        trimmedIfpaPlayerID.isBlank() -> {
            AppPanelEmptyCard(text = "Add your IFPA ID in Practice Settings to load your public ranking snapshot here.")
        }

        isLoading && profile == null -> {
            AppPanelStatusCard(
                text = "Loading IFPA profile…",
                showsProgress = true,
            )
        }

        profile != null -> {
            val loadedProfile = profile!!
            if (staleSnapshotNotice != null) {
                CardContainer {
                    AppInlineTaskStatus(text = staleSnapshotNotice, isError = true)
                    AppPrimaryButton(
                        onClick = { coroutineScope.launch { loadProfile() } },
                    ) {
                        Text("Try Again")
                    }
                }
            }

            CardContainer {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        AppCardTitle(text = playerName.trim().ifBlank { loadedProfile.displayName })
                        AppCardSubheading(text = "IFPA #${loadedProfile.playerID}")
                        loadedProfile.location?.let {
                            AppCardSubheading(text = it)
                        }
                    }

                    if (!loadedProfile.profilePhotoUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = loadedProfile.profilePhotoUrl,
                            contentDescription = "IFPA profile picture",
                            modifier = Modifier
                                .size(92.dp)
                                .clip(RoundedCornerShape(14.dp)),
                            contentScale = ContentScale.Crop,
                        )
                    }
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                IfpaStatCard(title = "Rank", value = loadedProfile.currentRank, modifier = Modifier.weight(1f))
                IfpaStatCard(title = "WPPR", value = loadedProfile.currentWpprPoints, modifier = Modifier.weight(1f))
                IfpaStatCard(title = "Rating", value = loadedProfile.rating, modifier = Modifier.weight(1f))
            }

            if (loadedProfile.lastEventDate != null || loadedProfile.seriesRank != null) {
                CardContainer {
                    SectionTitle("At a Glance")
                    loadedProfile.lastEventDate?.let {
                        IfpaInfoRow(label = "Last event", value = it)
                    }
                    if (!loadedProfile.seriesLabel.isNullOrBlank() && !loadedProfile.seriesRank.isNullOrBlank()) {
                        IfpaInfoRow(label = loadedProfile.seriesLabel, value = loadedProfile.seriesRank)
                    }
                }
            }

            CardContainer {
                SectionTitle("Recent Tournaments")
                if (loadedProfile.recentTournaments.isEmpty()) {
                    AppPanelEmptyCard(text = "No recent tournament results were found on the public IFPA profile.")
                } else {
                    loadedProfile.recentTournaments.forEachIndexed { index, tournament ->
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            AppCardSubheading(text = tournament.name)
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                IfpaInfoColumn(label = "Date", value = tournament.dateLabel)
                                IfpaInfoColumn(label = "Finish", value = tournament.finish)
                                IfpaInfoColumn(label = "Points", value = tournament.pointsGained)
                            }
                        }
                        if (index != loadedProfile.recentTournaments.lastIndex) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
                            )
                        }
                    }
                }
            }

            AppExternalLinkButton(
                text = "Open full IFPA profile",
                onClick = {
                uriHandler.openUri("https://www.ifpapinball.com/players/view.php?p=${loadedProfile.playerID}")
            })
        }

        errorMessage != null -> {
            CardContainer {
                SectionTitle("Could not load IFPA profile")
                AppInlineTaskStatus(text = errorMessage!!, isError = true)
                AppPrimaryButton(onClick = {
                    coroutineScope.launch {
                        profile = null
                        errorMessage = null
                        loadProfile()
                    }
                }) {
                    Text("Try Again")
                }
            }
        }
    }
}

@Composable
private fun IfpaStatCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    CardContainer(modifier = modifier) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        AppCardTitle(text = value)
    }
}

@Composable
private fun IfpaInfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}

@Composable
private fun IfpaInfoColumn(label: String, value: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}
