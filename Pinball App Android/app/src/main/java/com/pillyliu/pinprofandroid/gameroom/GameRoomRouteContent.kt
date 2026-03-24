package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppCardTitle
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppMetricGrid
import com.pillyliu.pinprofandroid.ui.AppMetricItem
import com.pillyliu.pinprofandroid.ui.AppSelectionPill
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppHeaderIconButton
import com.pillyliu.pinprofandroid.ui.AppSuccessBanner
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Settings
import kotlinx.coroutines.delay

internal data class GameRoomHomeRouteContext(
    val store: GameRoomStore,
    val catalogLoader: GameRoomCatalogLoader,
    val selectedMachine: OwnedMachine?,
    val selectedMachineID: String?,
    val collectionLayout: GameRoomCollectionLayout,
    val onCollectionLayoutChange: (GameRoomCollectionLayout) -> Unit,
    val onSelectMachine: (String) -> Unit,
    val onOpenMachineView: () -> Unit,
    val onOpenSettings: () -> Unit,
)

@Composable
internal fun GameRoomHomeRoute(
    context: GameRoomHomeRouteContext,
) {
    val store = context.store
    val activeMachines = store.activeMachines
    val selectedMachine = context.selectedMachine

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp, bottom = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = store.venueName,
                color = PinballThemeTokens.colors.brandInk,
                fontWeight = FontWeight.SemiBold,
                fontSize = 20.sp,
                maxLines = 1,
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 8.dp),
                overflow = TextOverflow.Ellipsis,
            )
            AppHeaderIconButton(
                icon = Icons.Outlined.Settings,
                contentDescription = "GameRoom Settings",
                onClick = context.onOpenSettings,
            )
        }

        CardContainer {
            AppCardTitle("Selected Machine")
            if (selectedMachine == null) {
                AppPanelEmptyCard(text = "Select a machine from the collection below.")
            } else {
                val snapshot = store.snapshot(selectedMachine.id)
                val areaName = store.area(selectedMachine.gameRoomAreaID)?.name ?: "No area"
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AppCardTitle(
                        text = selectedMachine.displayTitle,
                        maxLines = 1,
                        modifier = Modifier.weight(1f),
                    )
                    val variantLabel = gameRoomVariantBadgeLabel(selectedMachine.displayVariant, selectedMachine.displayTitle)
                    if (variantLabel != null) {
                        GameRoomVariantPill(label = variantLabel, style = VariantPillStyle.Standard)
                    }
                }
                Text(
                    text = "Location: $areaName • Group ${selectedMachine.groupNumber ?: "—"} • Position ${selectedMachine.position ?: "—"}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                )
                AppCardSubheading(
                    text = "Current Snapshot",
                    modifier = Modifier.padding(top = 2.dp),
                )
                AppMetricGrid(
                    items = listOf(
                        AppMetricItem("Open Issues", snapshot.openIssueCount.toString()),
                        AppMetricItem("Current Plays", snapshot.currentPlayCount.toString()),
                        AppMetricItem("Due Tasks", snapshot.dueTaskCount.toString()),
                        AppMetricItem("Last Service", formatDate(snapshot.lastServiceAtMs, "None")),
                        AppMetricItem("Pitch", snapshot.currentPitchValue?.let { String.format("%.1f", it) } ?: "—"),
                        AppMetricItem("Last Level", formatDate(snapshot.lastLeveledAtMs, "None")),
                        AppMetricItem("Last Inspection", formatDate(snapshot.lastGeneralInspectionAtMs, "None")),
                        AppMetricItem("Purchase Date", formatDate(selectedMachine.purchaseDateMs, "—")),
                    ),
                )
            }
        }

        CardContainer {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AppCardTitle(
                    text = "Collection",
                    modifier = Modifier.weight(1f),
                )
                SingleChoiceSegmentedButtonRow {
                    GameRoomCollectionLayout.entries.forEachIndexed { index, mode ->
                        SegmentedButton(
                            selected = mode == context.collectionLayout,
                            onClick = { context.onCollectionLayoutChange(mode) },
                            colors = pinballSegmentedButtonColors(),
                            icon = {},
                            shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
                                index = index,
                                count = GameRoomCollectionLayout.entries.size,
                            ),
                            label = { Text(mode.label, maxLines = 1) },
                        )
                    }
                }
            }
            Text(
                text = "Tracked active machines: ${activeMachines.size}",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (activeMachines.isEmpty()) {
                AppPanelEmptyCard(text = "No active machines yet. Add one in GameRoom Settings > Edit.")
            } else if (context.collectionLayout == GameRoomCollectionLayout.Tiles) {
                val leftColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 0 }
                val rightColumn = activeMachines.filterIndexed { index, _ -> index % 2 == 1 }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        leftColumn.forEach { machine ->
                            val snapshot = store.snapshot(machine.id)
                            val imageUrl = context.catalogLoader.imageCandidates(machine).firstOrNull()
                            MiniMachineCard(
                                machine = machine,
                                imageUrl = imageUrl,
                                attentionState = snapshot.attentionState,
                                selected = context.selectedMachineID == machine.id,
                                onClick = {
                                    if (context.selectedMachineID == machine.id) {
                                        context.onOpenMachineView()
                                    } else {
                                        context.onSelectMachine(machine.id)
                                    }
                                },
                            )
                        }
                    }
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        rightColumn.forEach { machine ->
                            val snapshot = store.snapshot(machine.id)
                            val imageUrl = context.catalogLoader.imageCandidates(machine).firstOrNull()
                            MiniMachineCard(
                                machine = machine,
                                imageUrl = imageUrl,
                                attentionState = snapshot.attentionState,
                                selected = context.selectedMachineID == machine.id,
                                onClick = {
                                    if (context.selectedMachineID == machine.id) {
                                        context.onOpenMachineView()
                                    } else {
                                        context.onSelectMachine(machine.id)
                                    }
                                },
                            )
                        }
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    activeMachines.forEach { machine ->
                        val snapshot = store.snapshot(machine.id)
                        val imageUrl = context.catalogLoader.imageCandidates(machine).firstOrNull()
                        MachineListRow(
                            machine = machine,
                            imageUrl = imageUrl,
                            areaName = store.area(machine.gameRoomAreaID)?.name ?: "No area",
                            attentionState = snapshot.attentionState,
                            selected = context.selectedMachineID == machine.id,
                            onClick = {
                                if (context.selectedMachineID == machine.id) {
                                    context.onOpenMachineView()
                                } else {
                                    context.onSelectMachine(machine.id)
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
internal fun GameRoomSettingsRoute(
    selectedSettingsSection: GameRoomSettingsSection,
    onSelectedSettingsSectionChange: (GameRoomSettingsSection) -> Unit,
    onBack: () -> Unit,
    overlayContent: @Composable BoxScope.() -> Unit = {},
    importContent: @Composable () -> Unit,
    editContent: @Composable () -> Unit,
    archiveContent: @Composable () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AppScreenHeader(
                title = "GameRoom Settings",
                onBack = onBack,
                titleColor = MaterialTheme.colorScheme.onSurface,
            )

            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                GameRoomSettingsSection.entries.forEachIndexed { index, section ->
                    SegmentedButton(
                        selected = section == selectedSettingsSection,
                        onClick = { onSelectedSettingsSectionChange(section) },
                        colors = pinballSegmentedButtonColors(),
                        icon = {},
                        shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = GameRoomSettingsSection.entries.size,
                        ),
                        label = { Text(section.label, maxLines = 1) },
                    )
                }
            }

            if (selectedSettingsSection == GameRoomSettingsSection.Import) {
                CardContainer {
                    SectionTitle("Import from Pinside")
                    importContent()
                }
            }

            if (selectedSettingsSection == GameRoomSettingsSection.Edit) {
                CardContainer {
                    SectionTitle("Edit GameRoom")
                    editContent()
                }
            }

            if (selectedSettingsSection == GameRoomSettingsSection.Archive) {
                archiveContent()
            }
        }

        overlayContent()
    }
}

@Composable
internal fun GameRoomFloatingSaveFeedbackOverlay(
    message: String?,
    token: Int,
    modifier: Modifier = Modifier,
) {
    val fadeInMillis = 140
    val fadeOutMillis = 180
    val totalDisplayMillis = 1200L
    var isVisible by remember { mutableStateOf(false) }

    LaunchedEffect(token) {
        if (token <= 0 || message.isNullOrBlank()) return@LaunchedEffect
        isVisible = true
        delay(totalDisplayMillis - fadeOutMillis)
        isVisible = false
    }

    AnimatedVisibility(
        visible = isVisible && !message.isNullOrBlank(),
        modifier = modifier,
        enter = fadeIn(
            animationSpec = tween(durationMillis = fadeInMillis, easing = FastOutSlowInEasing),
        ) + scaleIn(
            initialScale = 0.985f,
            animationSpec = tween(durationMillis = fadeInMillis, easing = FastOutSlowInEasing),
        ) + slideInVertically(
            initialOffsetY = { it / 5 },
            animationSpec = tween(durationMillis = fadeInMillis, easing = FastOutSlowInEasing),
        ),
        exit = fadeOut(
            animationSpec = tween(durationMillis = fadeOutMillis, easing = FastOutSlowInEasing),
        ) + scaleOut(
            targetScale = 0.985f,
            animationSpec = tween(durationMillis = fadeOutMillis, easing = FastOutSlowInEasing),
        ) + slideOutVertically(
            targetOffsetY = { it / 8 },
            animationSpec = tween(durationMillis = fadeOutMillis, easing = FastOutSlowInEasing),
        ),
    ) {
        AppSuccessBanner(
            text = message.orEmpty(),
            modifier = Modifier.padding(horizontal = 28.dp),
            compact = false,
            prominent = true,
        )
    }
}
