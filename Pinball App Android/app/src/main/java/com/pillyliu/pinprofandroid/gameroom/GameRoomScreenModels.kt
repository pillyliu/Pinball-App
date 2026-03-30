package com.pillyliu.pinprofandroid.gameroom

internal enum class GameRoomSettingsSection(val label: String) {
    Import("Import"),
    Edit("Edit"),
    Archive("Archive"),
}

internal enum class GameRoomArchiveFilter(val label: String) {
    All("All"),
    Sold("Sold"),
    Traded("Traded"),
    Archived("Archived"),
}

internal enum class GameRoomCollectionLayout(val label: String) {
    Tiles("Cards"),
    List("List"),
}

internal enum class GameRoomMachineSubview(val label: String) {
    Summary("Summary"),
    Input("Input"),
    Log("Log"),
}

internal enum class GameRoomInputSheet(val title: String) {
    CleanGlass("Clean Glass"),
    CleanPlayfield("Clean Playfield"),
    SwapBalls("Swap Balls"),
    CheckPitch("Check Pitch"),
    LevelMachine("Level Machine"),
    GeneralInspection("General Inspection"),
    LogIssue("Log Issue"),
    ResolveIssue("Resolve Issue"),
    OwnershipUpdate("Ownership Update"),
    InstallMod("Install Mod"),
    ReplacePart("Replace Part"),
    LogPlays("Log Plays"),
    AddMedia("Add Photo/Video"),
}

internal enum class ImportReviewFilter(val label: String) {
    All("All"),
    NeedsReview("Needs Review"),
}

internal data class ImportDraftRow(
    val id: String,
    val sourceItemKey: String,
    val rawTitle: String,
    val rawVariant: String?,
    val matchConfidence: MachineImportMatchConfidence,
    val suggestions: List<String>,
    val fingerprint: String,
    val selectedCatalogGameID: String?,
    val selectedVariant: String?,
    val rawPurchaseDateText: String?,
    val normalizedPurchaseDateMs: Long?,
)

internal data class IssueInputAttachmentDraft(
    val id: String,
    val kind: MachineAttachmentKind,
    val uri: String,
    val caption: String?,
)
