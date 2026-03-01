package com.pillyliu.pinballandroid.library

import java.util.Locale

internal data class LibraryGameLookupEntry(
    val normalizedName: String,
    val area: String?,
    val bank: Int?,
    val group: Int?,
    val position: Int?,
    val order: Int,
)

internal object LibraryGameLookup {
    private val machineAliases = mapOf(
        "tmnt" to listOf("teenagemutantninjaturtles"),
        "thegetaway" to listOf("thegetawayhighspeedii"),
        "starwars2017" to listOf("starwars"),
        "jurassicparkstern2019" to listOf("jurassicpark", "jurassicpark2019"),
        "attackfrommars" to listOf("attackfrommarsremake"),
        "dungeonsanddragons" to listOf("dungeonsdragons"),
    )

    fun buildEntries(games: List<PinballGame>): List<LibraryGameLookupEntry> {
        return games.mapIndexedNotNull { index, game ->
            val normalizedName = normalizeMachineName(game.name)
            if (normalizedName.isBlank()) {
                null
            } else {
                LibraryGameLookupEntry(
                    normalizedName = normalizedName,
                    area = game.area?.trim()?.takeIf { it.isNotBlank() },
                    bank = game.bank,
                    group = game.group,
                    position = game.position,
                    order = weightedOrder(index, game.group, game.position),
                )
            }
        }
    }

    fun bestMatch(gameName: String, entries: List<LibraryGameLookupEntry>): LibraryGameLookupEntry? {
        val candidateKeys = candidateKeys(gameName)
        if (candidateKeys.isEmpty()) return null

        return entries.firstOrNull { it.normalizedName in candidateKeys }
            ?: entries.firstOrNull { entry ->
                candidateKeys.any { key -> entry.normalizedName.contains(key) || key.contains(entry.normalizedName) }
            }
    }

    fun bestMatch(gameName: String, games: List<PinballGame>): PinballGame? {
        val candidateKeys = candidateKeys(gameName)
        if (candidateKeys.isEmpty()) return null

        return games.firstOrNull { normalizeMachineName(it.name) in candidateKeys }
            ?: games.firstOrNull { game ->
                val normalizedName = normalizeMachineName(game.name)
                candidateKeys.any { key -> normalizedName.contains(key) || key.contains(normalizedName) }
            }
    }

    fun candidateKeys(gameName: String): List<String> {
        val normalizedTarget = normalizeMachineName(gameName)
        if (normalizedTarget.isBlank()) return emptyList()
        return listOf(normalizedTarget) + machineAliases[normalizedTarget].orEmpty()
    }

    fun normalizeMachineName(raw: String): String {
        return raw.lowercase(Locale.US)
            .replace("&", " and ")
            .filter { it.isLetterOrDigit() }
    }

    private fun weightedOrder(index: Int, group: Int?, position: Int?): Int {
        return if (group != null && position != null) {
            (group * 1000) + position
        } else {
            100_000 + index
        }
    }
}
