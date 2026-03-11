package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticePersistenceMigrationResult(
    val runtimeState: PracticePersistedState,
    val canonicalState: CanonicalPracticePersistedState,
)

internal class PracticePersistenceIntegration(
    private val prefs: SharedPreferences,
    private val gameNameForSlug: (String) -> String,
    private val quickGamePrefKeys: List<String>,
) {
    fun loadState(): LoadedPracticeStatePayload? {
        return loadPracticeStatePayload(prefs, gameNameForSlug)
    }

    fun saveState(
        runtimeState: PracticePersistedState,
        shadowState: CanonicalPracticePersistedState,
    ): CanonicalPracticePersistedState {
        val canonicalState = canonicalPracticeStateFromRuntimeAndShadow(
            runtime = runtimeState,
            shadow = shadowState,
        )
        val serialized = buildCanonicalPracticeStateJson(canonicalState)
        savePracticeState(prefs, PRACTICE_STATE_KEY, serialized)
        return canonicalState
    }

    fun clearPrimaryState() {
        clearPracticeState(prefs, PRACTICE_STATE_KEY)
    }

    fun clearLegacyState() {
        clearPracticeState(prefs, LEGACY_PRACTICE_STATE_KEY)
    }

    fun markViewedGame(canonicalGameID: String, timestampMs: Long) {
        markPracticeLastViewedGame(prefs, canonicalGameID, timestampMs)
    }

    fun resumeSlug(lookupGames: List<PinballGame>): String? {
        val raw = resumeSlugFromLibraryOrPractice(prefs)?.trim().orEmpty()
        if (raw.isEmpty()) return null
        if (lookupGames.any { it.slug == raw }) {
            return raw
        }
        return canonicalPracticeKey(raw, lookupGames)
    }

    fun migrateLoadedState(
        lookupGames: List<PinballGame>,
        runtimeState: PracticePersistedState,
        canonicalState: CanonicalPracticePersistedState,
    ): PracticePersistenceMigrationResult? {
        if (lookupGames.isEmpty()) return null
        val migratedRuntime = migratePracticeStateKeys(runtimeState, lookupGames)
        val migratedCanonical = migrateCanonicalPracticeStateKeys(canonicalState, lookupGames)
        if (migratedRuntime == runtimeState && migratedCanonical == canonicalState) {
            return null
        }
        return PracticePersistenceMigrationResult(
            runtimeState = migratedRuntime,
            canonicalState = migratedCanonical,
        )
    }

    fun migratePreferenceGameKeys(lookupGames: List<PinballGame>): Boolean {
        if (lookupGames.isEmpty()) return false
        val gamePrefKeys = listOf(
            KEY_PRACTICE_LAST_VIEWED_SLUG,
        ) + quickGamePrefKeys

        var changed = false
        prefs.edit {
            gamePrefKeys.forEach { key ->
                val raw = prefs.getString(key, null)?.trim().orEmpty()
                if (raw.isEmpty()) return@forEach
                val canonical = canonicalPracticeKey(raw, lookupGames)
                if (canonical != raw) {
                    putString(key, canonical)
                    changed = true
                }
            }
        }
        return changed
    }
}
