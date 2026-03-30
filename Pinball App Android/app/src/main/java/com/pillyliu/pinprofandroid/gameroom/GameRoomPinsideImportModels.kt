package com.pillyliu.pinprofandroid.gameroom

internal data class PinsideImportedMachine(
    val id: String,
    val slug: String,
    val rawTitle: String,
    val rawVariant: String?,
    val manufacturerLabel: String? = null,
    val manufactureYear: Int? = null,
    val rawPurchaseDateText: String? = null,
    val normalizedPurchaseDateMs: Long? = null,
) {
    val fingerprint: String
        get() = "pinside:${slug.lowercase()}"
}

internal data class PinsideImportResult(
    val sourceURL: String,
    val machines: List<PinsideImportedMachine>,
)

internal enum class GameRoomPinsideImportError {
    invalidInput,
    invalidURL,
    httpError,
    userNotFound,
    privateOrUnavailableCollection,
    parseFailed,
    noMachinesFound,
    networkUnavailable,
}

internal class GameRoomPinsideImportException(
    val error: GameRoomPinsideImportError,
    val userMessage: String,
) : Exception(userMessage)

internal fun pinsideImportException(
    error: GameRoomPinsideImportError,
    detail: String? = null,
): GameRoomPinsideImportException {
    val message = when (error) {
        GameRoomPinsideImportError.invalidInput -> "Enter a Pinside username or public collection URL."
        GameRoomPinsideImportError.invalidURL -> "Could not build a valid Pinside collection URL."
        GameRoomPinsideImportError.httpError -> "Pinside request failed (${detail ?: "unknown"})."
        GameRoomPinsideImportError.userNotFound -> "Could not find that Pinside user/profile."
        GameRoomPinsideImportError.privateOrUnavailableCollection -> "This Pinside collection appears private or unavailable publicly."
        GameRoomPinsideImportError.parseFailed -> "Could not parse that collection page. Try a different public collection URL."
        GameRoomPinsideImportError.noMachinesFound -> "No machine entries were found on that public collection page."
        GameRoomPinsideImportError.networkUnavailable -> "Could not load Pinside collection right now."
    }
    return GameRoomPinsideImportException(error = error, userMessage = message)
}
