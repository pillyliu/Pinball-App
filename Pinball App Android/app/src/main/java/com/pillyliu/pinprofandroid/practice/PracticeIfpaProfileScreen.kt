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
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class RankingProfileSource(val label: String) {
    IFPA("IFPA"),
    PRPA("PRPA"),
}

@Composable
internal fun PracticeIfpaProfileScreen(
    playerName: String,
    ifpaPlayerID: String,
    prpaPlayerID: String,
) {
    val trimmedIfpaPlayerID = ifpaPlayerID.trim()
    val trimmedPrpaPlayerID = prpaPlayerID.trim()
    val availableSources = remember(trimmedIfpaPlayerID, trimmedPrpaPlayerID) {
        buildList {
            if (trimmedIfpaPlayerID.isNotBlank()) add(RankingProfileSource.IFPA)
            if (trimmedPrpaPlayerID.isNotBlank()) add(RankingProfileSource.PRPA)
        }
    }
    var selectedSource by remember(trimmedIfpaPlayerID, trimmedPrpaPlayerID) {
        mutableStateOf(
            if (trimmedIfpaPlayerID.isNotBlank()) RankingProfileSource.IFPA else RankingProfileSource.PRPA,
        )
    }
    val resolvedSelectedSource = if (selectedSource in availableSources) {
        selectedSource
    } else {
        availableSources.firstOrNull() ?: RankingProfileSource.IFPA
    }

    LaunchedEffect(trimmedIfpaPlayerID, trimmedPrpaPlayerID) {
        if (availableSources.isNotEmpty() && selectedSource !in availableSources) {
            selectedSource = availableSources.first()
        }
    }

    when {
        availableSources.isEmpty() -> {
            AppPanelEmptyCard(text = "Add your IFPA or PRPA ID in Practice Settings to load your public ranking snapshot here.")
        }

        else -> {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                if (availableSources.size > 1) {
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                        availableSources.forEachIndexed { index, source ->
                            SegmentedButton(
                                selected = resolvedSelectedSource == source,
                                onClick = { selectedSource = source },
                                label = { Text(source.label) },
                                colors = pinballSegmentedButtonColors(),
                                shape = SegmentedButtonDefaults.itemShape(index = index, count = availableSources.size),
                            )
                        }
                    }
                }

                when (resolvedSelectedSource) {
                    RankingProfileSource.IFPA -> PracticeIfpaPublicProfileContent(
                        playerName = playerName,
                        ifpaPlayerID = trimmedIfpaPlayerID,
                    )

                    RankingProfileSource.PRPA -> PracticePrpaPublicProfileContent(
                        playerName = playerName,
                        prpaPlayerID = trimmedPrpaPlayerID,
                    )
                }
            }
        }
    }
}

@Composable
private fun PracticeIfpaPublicProfileContent(
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
                },
            )
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
private fun PracticePrpaPublicProfileContent(
    playerName: String,
    prpaPlayerID: String,
) {
    val trimmedPrpaPlayerID = prpaPlayerID.trim()
    val context = LocalContext.current
    var profile by remember(trimmedPrpaPlayerID) { mutableStateOf<PrpaPlayerProfile?>(null) }
    var isLoading by remember(trimmedPrpaPlayerID) { mutableStateOf(false) }
    var errorMessage by remember(trimmedPrpaPlayerID) { mutableStateOf<String?>(null) }
    var cachedProfileUpdatedAtMs by remember(trimmedPrpaPlayerID) { mutableStateOf<Long?>(null) }
    var staleSnapshotFailureMessage by remember(trimmedPrpaPlayerID) { mutableStateOf<String?>(null) }
    val uriHandler = LocalUriHandler.current
    val coroutineScope = rememberCoroutineScope()
    val staleSnapshotNotice = remember(cachedProfileUpdatedAtMs, staleSnapshotFailureMessage) {
        val cachedAt = cachedProfileUpdatedAtMs ?: return@remember null
        val failureMessage = staleSnapshotFailureMessage ?: return@remember null
        "Showing your last saved PRPA snapshot from ${formatPrpaCachedAt(cachedAt)}. It may be outdated because the latest refresh failed. $failureMessage"
    }

    suspend fun loadProfile(cachedSnapshot: PrpaCachedProfileSnapshot? = null) {
        if (trimmedPrpaPlayerID.isBlank()) return
        val resolvedCachedSnapshot = cachedSnapshot ?: withContext(Dispatchers.IO) {
            PrpaProfileCacheStore.load(context, trimmedPrpaPlayerID)
        }
        isLoading = true
        errorMessage = null
        runCatching {
            PrpaPublicProfileService.fetchProfile(trimmedPrpaPlayerID)
        }.onSuccess {
            profile = it
            cachedProfileUpdatedAtMs = null
            staleSnapshotFailureMessage = null
            withContext(Dispatchers.IO) {
                PrpaProfileCacheStore.save(context, it)
            }
        }.onFailure {
            if (resolvedCachedSnapshot != null) {
                profile = resolvedCachedSnapshot.profile
                cachedProfileUpdatedAtMs = resolvedCachedSnapshot.cachedAtEpochMs
                staleSnapshotFailureMessage = it.message ?: "Could not load PRPA profile."
                errorMessage = null
            } else {
                profile = null
                cachedProfileUpdatedAtMs = null
                staleSnapshotFailureMessage = null
                errorMessage = it.message ?: "Could not load PRPA profile."
            }
        }
        isLoading = false
    }

    LaunchedEffect(trimmedPrpaPlayerID) {
        profile = null
        errorMessage = null
        cachedProfileUpdatedAtMs = null
        staleSnapshotFailureMessage = null
        if (trimmedPrpaPlayerID.isNotBlank()) {
            val cachedSnapshot = withContext(Dispatchers.IO) {
                PrpaProfileCacheStore.load(context, trimmedPrpaPlayerID)
            }
            profile = cachedSnapshot?.profile
            loadProfile(cachedSnapshot)
        }
    }

    when {
        trimmedPrpaPlayerID.isBlank() -> {
            AppPanelEmptyCard(text = "Add your PRPA ID in Practice Settings to load your public ranking snapshot here.")
        }

        isLoading && profile == null -> {
            AppPanelStatusCard(
                text = "Loading PRPA profile…",
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
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AppCardTitle(text = playerName.trim().ifBlank { loadedProfile.displayName })
                    AppCardSubheading(text = "PRPA #${loadedProfile.playerID}")
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                PrpaStatCard(title = "Rank", value = loadedProfile.openRanking, modifier = Modifier.weight(1f))
                PrpaStatCard(title = "Points", value = loadedProfile.openPoints, modifier = Modifier.weight(1f))
                PrpaStatCard(title = "Events", value = loadedProfile.eventsPlayed, modifier = Modifier.weight(1f))
            }

            if (hasPrpaMeaningfulValue(loadedProfile.lastEventDate)
                || hasPrpaMeaningfulValue(loadedProfile.averagePointsPerEvent)
                || hasPrpaMeaningfulValue(loadedProfile.bestFinish)
                || hasPrpaMeaningfulValue(loadedProfile.worstFinish)
                || loadedProfile.ifpaPlayerID != null
            ) {
                CardContainer {
                    SectionTitle("At a Glance")
                    loadedProfile.lastEventDate?.let {
                        PrpaInfoRow(label = "Last event", value = it)
                    }
                    if (hasPrpaMeaningfulValue(loadedProfile.averagePointsPerEvent)) {
                        PrpaInfoRow(label = "Avg / event", value = loadedProfile.averagePointsPerEvent)
                    }
                    if (hasPrpaMeaningfulValue(loadedProfile.bestFinish)) {
                        PrpaInfoRow(label = "Best finish", value = loadedProfile.bestFinish)
                    }
                    if (hasPrpaMeaningfulValue(loadedProfile.worstFinish)) {
                        PrpaInfoRow(label = "Worst finish", value = loadedProfile.worstFinish)
                    }
                }
            }

            if (loadedProfile.scenes.isNotEmpty()) {
                CardContainer {
                    SectionTitle("Scenes")
                    loadedProfile.scenes.forEachIndexed { index, scene ->
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            AppCardSubheading(text = scene.name)
                            Text(scene.rank, fontWeight = FontWeight.SemiBold)
                        }
                        if (index != loadedProfile.scenes.lastIndex) {
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

            CardContainer {
                SectionTitle("Recent Tournaments")
                if (loadedProfile.recentTournaments.isEmpty()) {
                    AppPanelEmptyCard(text = "No recent tournament results were found on the public PRPA profile.")
                } else {
                    loadedProfile.recentTournaments.forEachIndexed { index, tournament ->
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            AppCardSubheading(text = tournament.name)
                            tournament.eventType?.takeIf { it.isNotBlank() }?.let { eventType ->
                                Text(
                                    text = eventType,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                PrpaInfoColumn(label = "Date", value = tournament.dateLabel)
                                PrpaInfoColumn(label = "Place", value = tournament.placement)
                                PrpaInfoColumn(label = "Points", value = tournament.pointsGained)
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
                text = "Open full PRPA profile",
                onClick = {
                    uriHandler.openUri("https://punkrockpinball.com/player/?prp_id=${loadedProfile.playerID}")
                },
            )
        }

        errorMessage != null -> {
            CardContainer {
                SectionTitle("Could not load PRPA profile")
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
private fun PrpaStatCard(
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
private fun PrpaInfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}

@Composable
private fun PrpaInfoColumn(label: String, value: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}

private fun hasPrpaMeaningfulValue(value: String?): Boolean {
    val trimmed = value?.trim().orEmpty()
    return trimmed.isNotEmpty() && trimmed != "-"
}

@Composable
private fun IfpaInfoColumn(label: String, value: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}
