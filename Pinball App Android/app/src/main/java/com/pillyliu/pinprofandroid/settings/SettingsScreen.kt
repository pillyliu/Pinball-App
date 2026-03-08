package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.Image
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Button
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.data.setShowFullLplLastName
import com.pillyliu.pinprofandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.ImportedSourcesStore
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.EmptyLabel
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private sealed interface SettingsRoute {
    data object Home : SettingsRoute
    data object AddManufacturer : SettingsRoute
    data object AddVenue : SettingsRoute
    data object AddTournament : SettingsRoute
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val builtinSources = remember {
        listOf(
            LibrarySource(id = "venue--rlm-amusements", name = "RLM Amusements", type = LibrarySourceType.VENUE),
            LibrarySource(id = "venue--the-avenue-cafe", name = "The Avenue Cafe", type = LibrarySourceType.VENUE),
        )
    }
    var route by remember { mutableStateOf<SettingsRoute>(SettingsRoute.Home) }
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var manufacturers by remember { mutableStateOf<List<CatalogManufacturerOption>>(emptyList()) }
    var importedSources by remember { mutableStateOf<List<ImportedSourceRecord>>(emptyList()) }
    var sourceState by remember { mutableStateOf(LibrarySourceState()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshingHostedData by remember { mutableStateOf(false) }
    var hostedDataStatusMessage by remember { mutableStateOf<String?>(null) }
    var hostedDataStatusIsError by remember { mutableStateOf(false) }

    fun applySnapshot(snapshot: SettingsDataSnapshot) {
        manufacturers = snapshot.manufacturers
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    fun applySourceSnapshot(snapshot: SettingsSourceSnapshot) {
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    suspend fun reload() {
        loading = true
        error = null
        runCatching { loadSettingsDataSnapshot(context) }
            .onSuccess(::applySnapshot)
            .onFailure { error = it.message ?: "Failed to load settings." }
        loading = false
    }

    fun afterSourceMutation() {
        applySourceSnapshot(
            SettingsSourceSnapshot(
                importedSources = ImportedSourcesStore.load(context),
                sourceState = LibrarySourceStateStore.load(context),
            ),
        )
        LibrarySourceEvents.notifyChanged()
    }

    fun refreshHostedLibraryData() {
        if (refreshingHostedData) return
        scope.launch {
            refreshingHostedData = true
            hostedDataStatusMessage = null
            hostedDataStatusIsError = false
            runCatching { forceRefreshHostedSettingsData(context) }
                .onSuccess { snapshot ->
                applySnapshot(snapshot)
                hostedDataStatusMessage = "Pinball data refreshed from pillyliu.com."
                hostedDataStatusIsError = false
            }.onFailure {
                hostedDataStatusMessage = "Hosted data refresh failed: ${it.message ?: "Unknown error"}"
                hostedDataStatusIsError = true
            }
            refreshingHostedData = false
        }
    }

    LaunchedEffect(Unit) {
        reload()
    }
    LaunchedEffect(sourceVersion) {
        if (sourceVersion != 0L) {
            reload()
        }
    }

    when (route) {
        SettingsRoute.AddManufacturer -> {
            AddManufacturerScreen(
                contentPadding = contentPadding,
                manufacturers = manufacturers,
                onBack = { route = SettingsRoute.Home },
                onAdd = { manufacturer ->
                    applySourceSnapshot(addManufacturerSource(context, manufacturer))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddVenue -> {
            AddVenueScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result, machineIds, query, radiusMiles ->
                    applySourceSnapshot(addVenueSource(context, result, machineIds, query, radiusMiles))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddTournament -> {
            AddTournamentScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result ->
                    applySourceSnapshot(addTournamentSource(context, result))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.Home -> Unit
    }

    AppScreen(contentPadding) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
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
                CardContainer {
                    SectionTitle("Library")
                    Text(
                        "Add:",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Button(
                            onClick = { route = SettingsRoute.AddManufacturer },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Manufacturer", maxLines = 1, overflow = TextOverflow.Clip) }
                        Button(
                            onClick = { route = SettingsRoute.AddVenue },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Venue", maxLines = 1, overflow = TextOverflow.Clip) }
                        Button(
                            onClick = { route = SettingsRoute.AddTournament },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Tournament", maxLines = 1, overflow = TextOverflow.Clip) }
                    }
                    Text(
                        "Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to ${LibrarySourceStateStore.MAX_PINNED_SOURCES} sources can appear in Library at once.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    builtinSources.forEach { source ->
                        ManagedSourceRow(
                            title = source.name,
                            subtitle = "Built-in venue",
                            enabled = true,
                            pinned = sourceState.pinnedSourceIds.contains(source.id),
                            canDisable = false,
                            onEnabledChange = {},
                            onPinnedChange = { isPinned ->
                                if (LibrarySourceStateStore.setPinned(context, source.id, isPinned)) {
                                    afterSourceMutation()
                                } else {
                                    error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
                                }
                            },
                            onRefresh = null,
                            onDelete = null,
                        )
                    }
                    importedSources.forEach { source ->
                        ManagedSourceRow(
                            title = source.name,
                            subtitle = when (source.type) {
                                LibrarySourceType.MANUFACTURER -> {
                                    val count = manufacturers.firstOrNull { it.id == source.providerSourceId }?.gameCount ?: 0
                                    "Manufacturer • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.VENUE -> {
                                    val count = source.machineIds.size
                                    "Imported venue • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.TOURNAMENT -> {
                                    val count = source.machineIds.size
                                    "Match Play tournament • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.CATEGORY -> "Category"
                            },
                            enabled = sourceState.enabledSourceIds.contains(source.id),
                            pinned = sourceState.pinnedSourceIds.contains(source.id),
                            canDisable = true,
                            onEnabledChange = {
                                LibrarySourceStateStore.setEnabled(context, source.id, it)
                                afterSourceMutation()
                            },
                            onPinnedChange = { isPinned ->
                                if (LibrarySourceStateStore.setPinned(context, source.id, isPinned)) {
                                    afterSourceMutation()
                                } else {
                                    error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
                                }
                            },
                            onRefresh = if (source.type == LibrarySourceType.VENUE) {
                                {
                                    scope.launch {
                                        runCatching { refreshVenueSource(context, source) }
                                            .onSuccess(::applySourceSnapshot)
                                            .onFailure {
                                            error = "Venue refresh failed: ${it.message ?: "Unknown error"}"
                                        }
                                    }
                                }
                            } else if (source.type == LibrarySourceType.TOURNAMENT) {
                                {
                                    scope.launch {
                                        runCatching { refreshTournamentSource(context, source) }
                                            .onSuccess(::applySourceSnapshot)
                                            .onFailure {
                                            error = "Tournament refresh failed: ${it.message ?: "Unknown error"}"
                                        }
                                    }
                                }
                            } else null,
                            onDelete = {
                                applySourceSnapshot(removeSettingsSource(context, source.id))
                            },
                        )
                    }
                    if (importedSources.isEmpty()) {
                        AppPanelEmptyCard(text = "No additional sources added yet.")
                    }
                }
            }

            item {
                CardContainer {
                    SectionTitle("Pinball Data")
                    Text(
                        "Force-refresh the hosted Library and OPDB catalog from pillyliu.com.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Button(
                        onClick = ::refreshHostedLibraryData,
                        enabled = !refreshingHostedData,
                    ) {
                        Text(if (refreshingHostedData) "Refreshing Pinball Data..." else "Refresh Pinball Data")
                    }
                    when {
                        hostedDataStatusMessage != null -> {
                            AppInlineTaskStatus(
                                text = hostedDataStatusMessage.orEmpty(),
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
                }
            }

            item {
                PrivacySection()
            }

            item {
                CardContainer {
                    SectionTitle("About")
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Image(
                            painter = painterResource(id = R.drawable.splash_logo),
                            contentDescription = "PinProf logo",
                            modifier = Modifier
                                .fillMaxWidth(0.42f)
                                .heightIn(max = 140.dp),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    LinkedHtmlText(
                        html = """
                            PinProf is built on <a href="https://opdb.org/">OPDB</a> (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by <a href="https://www.pinballmap.com">Pinball Map</a>. Rulesheets are sourced from <a href="https://tiltforums.com/">Tiltforums</a>, <a href="https://rules.silverballmania.com/">Bob's Guide</a>, <a href="https://pinballprimer.github.io/">Pinball Primer</a>, and <a href="https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/">PAPA</a>. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from <a href="https://matchplay.events/">Matchplay</a>.
                        """.trimIndent(),
                    )
                }
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
}

@Composable
private fun ManagedSourceRow(
    title: String,
    subtitle: String,
    enabled: Boolean,
    pinned: Boolean,
    canDisable: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    onPinnedChange: (Boolean) -> Unit,
    onRefresh: (() -> Unit)?,
    onDelete: (() -> Unit)?,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                onRefresh?.let { AppInlineActionChip(text = "Refresh", onClick = it) }
                onDelete?.let { AppInlineActionChip(text = "Delete", onClick = it, destructive = true) }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Enabled", style = MaterialTheme.typography.labelSmall)
            Switch(
                checked = enabled,
                onCheckedChange = onEnabledChange,
                enabled = canDisable,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Pinned", style = MaterialTheme.typography.labelSmall)
            Switch(
                checked = pinned,
                onCheckedChange = onPinnedChange,
            )
        }
    }
}

@Composable
private fun PrivacySection() {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val unlocked = rememberLplFullNameAccessUnlocked()
    val showFullLastName = rememberShowFullLplLastName()

    CardContainer {
        SectionTitle("Privacy")
        Text(
            "Lansing Pinball League names are shown as first name plus last initial by default.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (unlocked) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show full last names for LPL data")
                Switch(
                    checked = showFullLastName,
                    onCheckedChange = { setShowFullLplLastName(context, it) },
                )
            }
        } else {
            var password by remember { mutableStateOf("") }
            var error by remember { mutableStateOf<String?>(null) }
            OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    error = null
                },
                label = { Text("LPL full-name password") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (unlockLplFullNameAccess(context, password)) {
                            password = ""
                            error = null
                        } else {
                            error = "Incorrect password."
                        }
                    },
                ),
            )
            Button(
                onClick = {
                    if (unlockLplFullNameAccess(context, password)) {
                        password = ""
                        error = null
                    } else {
                        error = "Incorrect password."
                    }
                },
                enabled = password.isNotBlank(),
            ) {
                Text("Unlock Full Names")
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}
