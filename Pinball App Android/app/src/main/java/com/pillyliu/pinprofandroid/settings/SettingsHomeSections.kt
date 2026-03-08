package com.pillyliu.pinprofandroid.settings

import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.compose.foundation.Image
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.data.setShowFullLplLastName
import com.pillyliu.pinprofandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun SettingsHomeContent(
    builtinSources: List<LibrarySource>,
    manufacturers: List<CatalogManufacturerOption>,
    importedSources: List<ImportedSourceRecord>,
    sourceState: LibrarySourceState,
    loading: Boolean,
    error: String?,
    refreshingHostedData: Boolean,
    hostedDataStatusMessage: String?,
    hostedDataStatusIsError: Boolean,
    onOpenAddManufacturer: () -> Unit,
    onOpenAddVenue: () -> Unit,
    onOpenAddTournament: () -> Unit,
    onToggleEnabled: (String, Boolean) -> Unit,
    onTogglePinned: (String, Boolean) -> Unit,
    onRefreshSource: (ImportedSourceRecord) -> Unit,
    onDeleteSource: (String) -> Unit,
    onRefreshHostedData: () -> Unit,
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
            SettingsLibrarySection(
                builtinSources = builtinSources,
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
                onRefreshHostedData = onRefreshHostedData,
            )
        }

        item {
            SettingsPrivacySection()
        }

        item {
            SettingsAboutSection()
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

@Composable
private fun SettingsLibrarySection(
    builtinSources: List<LibrarySource>,
    manufacturers: List<CatalogManufacturerOption>,
    importedSources: List<ImportedSourceRecord>,
    sourceState: LibrarySourceState,
    onOpenAddManufacturer: () -> Unit,
    onOpenAddVenue: () -> Unit,
    onOpenAddTournament: () -> Unit,
    onToggleEnabled: (String, Boolean) -> Unit,
    onTogglePinned: (String, Boolean) -> Unit,
    onRefreshSource: (ImportedSourceRecord) -> Unit,
    onDeleteSource: (String) -> Unit,
) {
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
            AppPrimaryButton(
                onClick = onOpenAddManufacturer,
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
            ) { Text("Manufacturer", maxLines = 1, overflow = TextOverflow.Clip) }
            AppPrimaryButton(
                onClick = onOpenAddVenue,
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
            ) { Text("Venue", maxLines = 1, overflow = TextOverflow.Clip) }
            AppPrimaryButton(
                onClick = onOpenAddTournament,
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
                onPinnedChange = { isPinned -> onTogglePinned(source.id, isPinned) },
                onRefresh = null,
                onDelete = null,
            )
        }
        importedSources.forEach { source ->
            ManagedSourceRow(
                title = source.name,
                subtitle = importedSourceSubtitle(source, manufacturers),
                enabled = sourceState.enabledSourceIds.contains(source.id),
                pinned = sourceState.pinnedSourceIds.contains(source.id),
                canDisable = true,
                onEnabledChange = { isEnabled -> onToggleEnabled(source.id, isEnabled) },
                onPinnedChange = { isPinned -> onTogglePinned(source.id, isPinned) },
                onRefresh = if (source.type == LibrarySourceType.VENUE || source.type == LibrarySourceType.TOURNAMENT) {
                    { onRefreshSource(source) }
                } else {
                    null
                },
                onDelete = { onDeleteSource(source.id) },
            )
        }
        if (importedSources.isEmpty()) {
            AppPanelEmptyCard(text = "No additional sources added yet.")
        }
    }
}

@Composable
private fun SettingsHostedRefreshSection(
    refreshingHostedData: Boolean,
    hostedDataStatusMessage: String?,
    hostedDataStatusIsError: Boolean,
    onRefreshHostedData: () -> Unit,
) {
    CardContainer {
        SectionTitle("Pinball Data")
        Text(
            "Force-refresh the hosted Library and OPDB catalog from pillyliu.com.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        AppPrimaryButton(
            onClick = onRefreshHostedData,
            enabled = !refreshingHostedData,
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
private fun SettingsPrivacySection() {
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
            androidx.compose.material3.OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    error = null
                },
                label = { Text("LPL full-name password") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = androidx.compose.foundation.text.KeyboardActions(
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
            AppPrimaryButton(
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

@Composable
private fun SettingsAboutSection() {
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
                contentScale = androidx.compose.ui.layout.ContentScale.Fit,
            )
        }
        LinkedHtmlText(
            html = """
                PinProf is built on <a href="https://opdb.org/">OPDB</a> (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by <a href="https://www.pinballmap.com">Pinball Map</a>. Rulesheets are sourced from <a href="https://tiltforums.com/">Tiltforums</a>, <a href="https://rules.silverballmania.com/">Bob's Guide</a>, <a href="https://pinballprimer.github.io/">Pinball Primer</a>, and <a href="https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/">PAPA</a>. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from <a href="https://matchplay.events/">Matchplay</a>.
            """.trimIndent(),
        )
    }
}

@Composable
internal fun LinkedHtmlText(html: String) {
    val bodyColor = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    val linkColor = MaterialTheme.colorScheme.primary.toArgb()
    AndroidView(
        factory = { context ->
            TextView(context).apply {
                movementMethod = LinkMovementMethod.getInstance()
                setBackgroundColor(Color.Transparent.toArgb())
            }
        },
        update = { textView ->
            textView.text = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY)
            textView.setTextColor(bodyColor)
            textView.setLinkTextColor(linkColor)
        },
    )
}

private fun importedSourceSubtitle(
    source: ImportedSourceRecord,
    manufacturers: List<CatalogManufacturerOption>,
): String =
    when (source.type) {
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
    }
