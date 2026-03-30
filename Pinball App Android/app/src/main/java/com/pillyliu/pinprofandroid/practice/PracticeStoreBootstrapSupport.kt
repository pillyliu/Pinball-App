package com.pillyliu.pinprofandroid.practice

import android.content.Context
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticeHomeBootstrapRestorePayload(
    val canonicalState: CanonicalPracticePersistedState,
    val runtimeState: PracticePersistedState,
    val visibleGames: List<PinballGame>,
    val lookupGames: List<PinballGame>,
    val librarySources: List<LibrarySource>,
    val selectedLibrarySourceId: String?,
    val hasUsableSnapshot: Boolean,
)

internal fun loadPracticeHomeBootstrapRestorePayload(
    context: Context,
): PracticeHomeBootstrapRestorePayload? {
    val snapshot = PracticeHomeBootstrapSnapshotStore.load(context) ?: return null
    return PracticeHomeBootstrapRestorePayload(
        canonicalState = emptyCanonicalPracticePersistedState().copy(
            customGroups = snapshot.groups.map { group ->
                CanonicalCustomGroup(
                    id = group.id,
                    name = group.name,
                    gameIDs = group.gameSlugs,
                    type = group.type,
                    isActive = group.isActive,
                    isArchived = group.isArchived,
                    isPriority = group.isPriority,
                    startDateMs = group.startDateMs,
                    endDateMs = group.endDateMs,
                    createdAtMs = snapshot.capturedAtMs,
                )
            },
            practiceSettings = CanonicalPracticeSettings(
                playerName = snapshot.playerName,
                ifpaPlayerID = "",
                comparisonPlayerName = "",
                selectedGroupID = snapshot.selectedGroupID,
            ),
        ),
        runtimeState = practicePersistedStateFromValues(
            playerName = snapshot.playerName,
            ifpaPlayerID = "",
            comparisonPlayerName = "",
            leaguePlayerName = "",
            cloudSyncEnabled = false,
            selectedGroupID = snapshot.selectedGroupID,
            groups = snapshot.groups,
            scores = emptyList(),
            notes = emptyList(),
            journal = emptyList(),
            rulesheetProgress = emptyMap(),
            gameSummaryNotes = emptyMap(),
        ),
        visibleGames = snapshot.visibleGames.map(PracticeHomeBootstrapGameSnapshot::toPinballGame),
        lookupGames = snapshot.lookupGames.map(PracticeHomeBootstrapGameSnapshot::toPinballGame),
        librarySources = snapshot.librarySources.map(PracticeHomeBootstrapSourceSnapshot::toLibrarySource),
        selectedLibrarySourceId = snapshot.selectedLibrarySourceId,
        hasUsableSnapshot = snapshot.isUsable(),
    )
}

internal fun savePracticeHomeBootstrapSnapshot(
    context: Context,
    snapshot: PracticeHomeBootstrapSnapshot?,
) {
    snapshot ?: return
    PracticeHomeBootstrapSnapshotStore.save(context, snapshot)
}

internal fun buildPracticeHomeBootstrapSnapshot(
    playerName: String,
    selectedGroupID: String?,
    groups: List<PracticeGroup>,
    selectedLibrarySourceId: String?,
    librarySources: List<LibrarySource>,
    visibleGames: List<PinballGame>,
    lookupGames: List<PinballGame>,
    capturedAtMs: Long = System.currentTimeMillis(),
): PracticeHomeBootstrapSnapshot? {
    val snapshot = PracticeHomeBootstrapSnapshot(
        schemaVersion = 1,
        capturedAtMs = capturedAtMs,
        playerName = playerName.trim(),
        selectedGroupID = selectedGroupID,
        groups = groups,
        selectedLibrarySourceId = selectedLibrarySourceId,
        librarySources = librarySources.map { source ->
            PracticeHomeBootstrapSourceSnapshot(
                id = source.id,
                name = source.name,
                typeRaw = source.type.rawValue,
            )
        },
        visibleGames = visibleGames.map(::practiceHomeBootstrapSnapshotGame),
        lookupGames = lookupGames.map(::practiceHomeBootstrapSnapshotGame),
    )
    return snapshot.takeIf { it.isUsable() }
}

internal fun buildPracticeStoreHomeBootstrapSnapshot(
    playerName: String,
    selectedGroupID: String?,
    groups: List<PracticeGroup>,
    selectedLibrarySourceId: String?,
    librarySources: List<LibrarySource>,
    visibleGames: List<PinballGame>,
    combinedLookupGames: List<PinballGame>,
    resumeSlug: String?,
    gameResolver: (String) -> PinballGame?,
): PracticeHomeBootstrapSnapshot? {
    val lookupGames = practiceHomeBootstrapLookupGames(
        combinedGames = combinedLookupGames,
        resumeCandidate = resumeSlug?.let(gameResolver),
    )
    return buildPracticeHomeBootstrapSnapshot(
        playerName = playerName,
        selectedGroupID = selectedGroupID,
        groups = groups,
        selectedLibrarySourceId = selectedLibrarySourceId,
        librarySources = librarySources,
        visibleGames = visibleGames,
        lookupGames = lookupGames,
    )
}

internal fun savePracticeStoreHomeBootstrapSnapshot(
    context: Context,
    playerName: String,
    selectedGroupID: String?,
    groups: List<PracticeGroup>,
    selectedLibrarySourceId: String?,
    librarySources: List<LibrarySource>,
    visibleGames: List<PinballGame>,
    combinedLookupGames: List<PinballGame>,
    resumeSlug: String?,
    gameResolver: (String) -> PinballGame?,
) {
    savePracticeHomeBootstrapSnapshot(
        context,
        buildPracticeStoreHomeBootstrapSnapshot(
            playerName = playerName,
            selectedGroupID = selectedGroupID,
            groups = groups,
            selectedLibrarySourceId = selectedLibrarySourceId,
            librarySources = librarySources,
            visibleGames = visibleGames,
            combinedLookupGames = combinedLookupGames,
            resumeSlug = resumeSlug,
            gameResolver = gameResolver,
        ),
    )
}

internal fun practiceHomeBootstrapLookupGames(
    combinedGames: List<PinballGame>,
    resumeCandidate: PinballGame?,
): List<PinballGame> {
    val ordered = LinkedHashMap<String, PinballGame>()

    fun append(game: PinballGame?) {
        game ?: return
        val key = sourceScopedPracticeGameID(game.sourceId, game.practiceKey)
        ordered.putIfAbsent(key, game)
    }

    append(resumeCandidate)
    combinedGames.forEach(::append)
    return ordered.values.toList()
}

private fun practiceHomeBootstrapSnapshotGame(game: PinballGame): PracticeHomeBootstrapGameSnapshot {
    return PracticeHomeBootstrapGameSnapshot(
        libraryEntryId = game.libraryEntryId,
        practiceIdentity = game.practiceIdentity,
        opdbId = game.opdbId,
        opdbGroupId = game.opdbGroupId,
        opdbMachineId = game.opdbMachineId,
        variant = game.variant,
        sourceId = game.sourceId,
        sourceName = game.sourceName,
        sourceTypeRaw = game.sourceType.rawValue,
        area = game.area,
        areaOrder = game.areaOrder,
        group = game.group,
        position = game.position,
        bank = game.bank,
        name = game.name,
        manufacturer = game.manufacturer,
        year = game.year,
        slug = game.slug,
        primaryImageUrl = game.primaryImageUrl,
        primaryImageLargeUrl = game.primaryImageLargeUrl,
        playfieldImageUrl = game.playfieldImageUrl,
        alternatePlayfieldImageUrl = game.alternatePlayfieldImageUrl,
        playfieldLocalOriginal = game.playfieldLocalOriginal,
        playfieldLocal = game.playfieldLocal,
    )
}
