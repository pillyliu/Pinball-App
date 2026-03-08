package com.pillyliu.pinprofandroid.settings

import android.content.Context
import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.compose.foundation.background
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppTintedStatusChip
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal enum class ManufacturerBucket(val label: String) {
    MODERN("Modern"),
    CLASSIC("Classic"),
    OTHER("Other"),
}

@Composable
internal fun AddManufacturerScreen(
    contentPadding: PaddingValues,
    manufacturers: List<CatalogManufacturerOption>,
    onBack: () -> Unit,
    onAdd: (CatalogManufacturerOption) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var selectedBucket by remember { mutableStateOf(ManufacturerBucket.MODERN) }
    val bucketedManufacturers = remember(manufacturers, selectedBucket) {
        manufacturers.filteredForBucket(selectedBucket)
    }
    val filtered = remember(bucketedManufacturers, query) {
        val normalized = query.trim().lowercase()
        if (normalized.isBlank()) {
            bucketedManufacturers
        } else {
            bucketedManufacturers.filter { it.name.lowercase().contains(normalized) }
        }
    }
    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Manufacturer", onBack = onBack)
            CardContainer {
                AnchoredDropdownFilter(
                    selectedText = selectedBucket.label,
                    options = ManufacturerBucket.entries.map { bucket ->
                        DropdownOption(value = bucket.name, label = bucket.label)
                    },
                    onSelect = { value ->
                        selectedBucket = ManufacturerBucket.valueOf(value)
                    },
                    label = "Bucket",
                )
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("Search manufacturers") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (filtered.isEmpty()) {
                AppPanelEmptyCard(text = "No manufacturers found for that search.")
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                    items(filtered) { manufacturer ->
                        CardContainer {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Row(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    AppCardSubheading(manufacturer.name)
                                    if (manufacturer.isModern) {
                                        AppTintedStatusChip(
                                            text = "Modern",
                                            color = MaterialTheme.colorScheme.primary,
                                            compact = true,
                                        )
                                    }
                                    Text(
                                        "${manufacturer.gameCount} games",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                AppCompactIconButton(
                                    icon = Icons.Filled.Add,
                                    contentDescription = "Add ${manufacturer.name}",
                                    onClick = { onAdd(manufacturer) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

internal fun List<CatalogManufacturerOption>.filteredForBucket(
    bucket: ManufacturerBucket,
): List<CatalogManufacturerOption> {
    val classicTopIds = filter { !it.isModern }
        .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        .take(20)
        .map { it.id }
        .toSet()
    return when (bucket) {
        ManufacturerBucket.MODERN -> filter { it.isModern }
        ManufacturerBucket.CLASSIC -> filter { it.id in classicTopIds }
            .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        ManufacturerBucket.OTHER -> filter { !it.isModern && it.id !in classicTopIds }
    }
}

internal fun extractTournamentId(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isBlank()) return null
    if (trimmed.all { it.isDigit() }) return trimmed
    return Regex("""tournaments/(\d+)""")
        .find(trimmed)
        ?.groupValues
        ?.getOrNull(1)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AddVenueScreen(
    contentPadding: PaddingValues,
    onBack: () -> Unit,
    onImport: (LibraryVenueSearchResult, List<String>, String, Int) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    val prefs = remember(context) { context.getSharedPreferences("settings-v1", Context.MODE_PRIVATE) }
    var query by remember { mutableStateOf("") }
    var radiusMiles by remember { mutableIntStateOf(50) }
    var minimumGameCount by remember { mutableIntStateOf(prefs.getInt("settings-add-venue-min-game-count", 5)) }
    var results by remember { mutableStateOf<List<LibraryVenueSearchResult>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var hasSearched by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val filteredResults = remember(results, minimumGameCount) {
        results.filter { it.machineCount >= minimumGameCount }
    }

    suspend fun runSearch() {
        searching = true
        error = null
        hasSearched = true
        runCatching {
            withContext(Dispatchers.IO) { PinballMapClient.searchVenues(query, radiusMiles) }
        }.onSuccess {
            results = it
        }.onFailure {
            error = it.message ?: "Venue search failed."
            results = emptyList()
        }
        searching = false
    }

    val emptyResultsMessage = remember(hasSearched, results, filteredResults, minimumGameCount) {
        when {
            !hasSearched -> null
            results.isEmpty() -> "No venues found for that search."
            filteredResults.isEmpty() -> {
                if (minimumGameCount == 1) "No venues found with at least 1 game."
                else "No venues found with at least $minimumGameCount games."
            }
            else -> null
        }
    }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Venue", onBack = onBack)
            CardContainer {
                LinkedHtmlText(
                    html = """Search powered by <a href="https://www.pinballmap.com">Pinball Map</a>""",
                )
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("City or ZIP code") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                        onSearch = {
                            focusManager.clearFocus()
                            if (!searching && query.isNotBlank()) {
                                scope.launch { runSearch() }
                            }
                        },
                    ),
                )
                AnchoredDropdownFilter(
                    selectedText = "$radiusMiles miles",
                    options = listOf(10, 25, 50, 100).map { miles ->
                        DropdownOption(value = miles.toString(), label = "$miles miles")
                    },
                    onSelect = { value -> radiusMiles = value.toInt() },
                    label = "Distance",
                )
                OutlinedTextField(
                    value = minimumGameCount.toString(),
                    onValueChange = { minimumGameCount = it.toIntOrNull()?.coerceAtLeast(0) ?: minimumGameCount },
                    label = { Text("Minimum games") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                )
                AppPrimaryButton(
                    onClick = { scope.launch { runSearch() } },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !searching && query.isNotBlank(),
                ) {
                    Text(if (searching) "Searching..." else "Search Pinball Map")
                }
                if (searching) {
                    AppInlineTaskStatus(text = "Searching Pinball Map…", showsProgress = true)
                } else if (error != null) {
                    AppInlineTaskStatus(text = error.orEmpty(), isError = true)
                }
            }
            LaunchedEffect(minimumGameCount) {
                prefs.edit().putInt("settings-add-venue-min-game-count", minimumGameCount).apply()
            }
            emptyResultsMessage?.let {
                AppPanelEmptyCard(text = it)
            }
            if (!hasSearched && results.isEmpty() && !searching) {
                AppPanelEmptyCard(text = "Search Pinball Map by city or ZIP, then import a venue as a Library source.")
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                items(filteredResults) { result ->
                    CardContainer {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            AppCardSubheading(result.name)
                            val locationLine = listOfNotNull(result.city, result.state, result.zip).joinToString(", ")
                            if (locationLine.isNotBlank()) {
                                Text(locationLine, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(
                                buildString {
                                    append("${result.machineCount} games")
                                    result.distanceMiles?.let { append(" • ${"%.1f".format(it)} miles") }
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            AppPrimaryButton(
                                onClick = {
                                    scope.launch {
                                        searching = true
                                        error = null
                                        runCatching {
                                            withContext(Dispatchers.IO) {
                                                PinballMapClient.fetchVenueMachineIds(result.id.removePrefix("venue--pm-"))
                                            }
                                        }.onSuccess { machineIds ->
                                            onImport(result, machineIds, query.trim(), radiusMiles)
                                        }.onFailure {
                                            error = it.message ?: "Venue import failed."
                                        }
                                        searching = false
                                    }
                                },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !searching,
                            ) {
                                Text("Import Venue")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun AddTournamentScreen(
    contentPadding: PaddingValues,
    onBack: () -> Unit,
    onImport: (MatchPlayTournamentImportResult) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    var rawTournamentId by remember { mutableStateOf("") }
    var importing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val tournamentId = remember(rawTournamentId) { extractTournamentId(rawTournamentId) }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Tournament", onBack = onBack)
            CardContainer {
                LinkedHtmlText(
                    html = """Import powered by <a href="https://matchplay.events">Match Play</a>""",
                )
                OutlinedTextField(
                    value = rawTournamentId,
                    onValueChange = { rawTournamentId = it },
                    label = { Text("Tournament ID or URL") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                    keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { focusManager.clearFocus() }),
                )
                Text(
                    "Enter a Match Play tournament ID or URL to import its arena list into Library and Practice.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                AppPrimaryButton(
                    onClick = {
                        scope.launch {
                            importing = true
                            error = null
                            val resolvedId = tournamentId
                            if (resolvedId == null) {
                                error = "Enter a valid tournament ID."
                                importing = false
                                return@launch
                            }
                            runCatching {
                                withContext(Dispatchers.IO) { MatchPlayClient.fetchTournament(resolvedId) }
                            }.onSuccess { result ->
                                if (result.machineIds.isEmpty()) {
                                    error = "No OPDB-linked arenas were found for that tournament."
                                } else {
                                    onImport(result)
                                }
                            }.onFailure {
                                error = it.message ?: "Tournament import failed."
                            }
                            importing = false
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !importing && tournamentId != null,
                ) {
                    Text(if (importing) "Importing..." else "Import Tournament")
                }
                if (importing) {
                    AppInlineTaskStatus(text = "Importing tournament…", showsProgress = true)
                } else if (error != null) {
                    AppInlineTaskStatus(text = error.orEmpty(), isError = true)
                }
            }
        }
    }
}

@Composable
internal fun LinkedHtmlText(
    html: String,
    modifier: Modifier = Modifier,
) {
    val bodyColor = MaterialTheme.colorScheme.onSurfaceVariant
    val linkColor = MaterialTheme.colorScheme.primary
    AndroidView(
        modifier = modifier.fillMaxWidth(),
        factory = { context ->
            TextView(context).apply {
                movementMethod = LinkMovementMethod.getInstance()
                linksClickable = true
                setBackgroundColor(Color.Transparent.toArgb())
            }
        },
        update = { view ->
            view.textSize = 12f
            view.setTextColor(bodyColor.toArgb())
            view.setLinkTextColor(linkColor.toArgb())
            view.text = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY)
        },
    )
}
