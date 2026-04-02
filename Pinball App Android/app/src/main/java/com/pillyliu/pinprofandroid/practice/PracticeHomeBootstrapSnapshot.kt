package com.pillyliu.pinprofandroid.practice

import android.content.Context
import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.normalizeLibraryPlayfieldLocalPath
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

private const val PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_SCHEMA_VERSION = 1
private const val PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_DIRECTORY = "practice-cache"
private const val PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_FILE_NAME = "practice-home-bootstrap.json"

internal data class PracticeHomeBootstrapSourceSnapshot(
    val id: String,
    val name: String,
    val typeRaw: String,
) {
    fun toLibrarySource(): LibrarySource {
        return LibrarySource(
            id = id,
            name = name,
            type = LibrarySourceType.fromRaw(typeRaw) ?: LibrarySourceType.VENUE,
        )
    }
}

internal data class PracticeHomeBootstrapGameSnapshot(
    val libraryEntryId: String?,
    val practiceIdentity: String?,
    val opdbId: String?,
    val opdbGroupId: String?,
    val opdbMachineId: String?,
    val variant: String?,
    val sourceId: String,
    val sourceName: String,
    val sourceTypeRaw: String,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
    val name: String,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val alternatePlayfieldImageUrl: String?,
    val playfieldLocalOriginal: String?,
    val playfieldLocal: String?,
) {
    fun toPinballGame(): PinballGame {
        val normalizedPlayfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocal ?: playfieldLocalOriginal)
        return PinballGame(
            libraryEntryId = libraryEntryId,
            practiceIdentity = practiceIdentity,
            opdbId = opdbId,
            opdbGroupId = opdbGroupId,
            opdbMachineId = opdbMachineId,
            variant = variant,
            sourceId = sourceId,
            sourceName = sourceName,
            sourceType = LibrarySourceType.fromRaw(sourceTypeRaw) ?: LibrarySourceType.VENUE,
            area = area,
            areaOrder = areaOrder,
            group = group,
            position = position,
            bank = bank,
            name = name,
            manufacturer = manufacturer,
            year = year,
            slug = slug,
            opdbName = null,
            opdbCommonName = null,
            opdbShortname = null,
            opdbDescription = null,
            opdbType = null,
            opdbDisplay = null,
            opdbPlayerCount = null,
            opdbManufactureDate = null,
            opdbIpdbId = null,
            opdbGroupShortname = null,
            opdbGroupDescription = null,
            primaryImageUrl = primaryImageUrl,
            primaryImageLargeUrl = primaryImageLargeUrl,
            playfieldImageUrl = playfieldImageUrl,
            alternatePlayfieldImageUrl = alternatePlayfieldImageUrl,
            playfieldLocalOriginal = normalizedPlayfieldLocal,
            playfieldLocal = normalizedPlayfieldLocal,
            playfieldSourceLabel = null,
            gameinfoLocal = null,
            rulesheetLocal = null,
            rulesheetUrl = null,
            rulesheetLinks = emptyList(),
            videos = emptyList(),
        )
    }
}

internal data class PracticeHomeBootstrapSnapshot(
    val schemaVersion: Int,
    val capturedAtMs: Long,
    val playerName: String,
    val selectedGroupID: String?,
    val groups: List<PracticeGroup>,
    val selectedLibrarySourceId: String?,
    val librarySources: List<PracticeHomeBootstrapSourceSnapshot>,
    val visibleGames: List<PracticeHomeBootstrapGameSnapshot>,
    val lookupGames: List<PracticeHomeBootstrapGameSnapshot>,
) {
    fun isUsable(): Boolean {
        return playerName.isNotBlank() ||
            groups.isNotEmpty() ||
            librarySources.isNotEmpty() ||
            visibleGames.isNotEmpty() ||
            lookupGames.isNotEmpty()
    }
}

internal object PracticeHomeBootstrapSnapshotStore {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun load(context: Context): PracticeHomeBootstrapSnapshot? {
        return PinballPerformanceTrace.measure("PracticeHomeSnapshotLoad") {
            val file = snapshotFile(context)
            if (!file.exists()) return@measure null
            val raw = runCatching { file.readText() }.getOrNull() ?: return@measure null
            val snapshot = parsePracticeHomeBootstrapSnapshot(raw) ?: return@measure null
            if (snapshot.schemaVersion != PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_SCHEMA_VERSION || !snapshot.isUsable()) {
                return@measure null
            }
            snapshot
        }
    }

    fun save(context: Context, snapshot: PracticeHomeBootstrapSnapshot) {
        if (!snapshot.isUsable()) return
        val serialized = buildPracticeHomeBootstrapSnapshotJson(snapshot)
        scope.launch {
            PinballPerformanceTrace.measure("PracticeHomeSnapshotSave") {
                val file = snapshotFile(context)
                file.parentFile?.mkdirs()
                runCatching { file.writeText(serialized) }
            }
        }
    }

    private fun snapshotFile(context: Context): File {
        return File(
            File(context.filesDir, PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_DIRECTORY),
            PRACTICE_HOME_BOOTSTRAP_SNAPSHOT_FILE_NAME,
        )
    }
}

private fun buildPracticeHomeBootstrapSnapshotJson(snapshot: PracticeHomeBootstrapSnapshot): String {
    return JSONObject().apply {
        put("schemaVersion", snapshot.schemaVersion)
        put("capturedAtMs", snapshot.capturedAtMs)
        put("playerName", snapshot.playerName)
        put("selectedGroupID", snapshot.selectedGroupID)
        put("groups", JSONArray().apply {
            snapshot.groups.forEach { group ->
                put(JSONObject().apply {
                    put("id", group.id)
                    put("name", group.name)
                    put("gameSlugs", JSONArray(group.gameSlugs))
                    put("type", group.type)
                    put("isActive", group.isActive)
                    put("isArchived", group.isArchived)
                    put("isPriority", group.isPriority)
                    put("startDateMs", group.startDateMs)
                    put("endDateMs", group.endDateMs)
                })
            }
        })
        put("selectedLibrarySourceId", snapshot.selectedLibrarySourceId)
        put("librarySources", JSONArray().apply {
            snapshot.librarySources.forEach { source ->
                put(JSONObject().apply {
                    put("id", source.id)
                    put("name", source.name)
                    put("type", source.typeRaw)
                })
            }
        })
        put("visibleGames", JSONArray().apply {
            snapshot.visibleGames.forEach { game ->
                put(game.toJson())
            }
        })
        put("lookupGames", JSONArray().apply {
            snapshot.lookupGames.forEach { game ->
                put(game.toJson())
            }
        })
    }.toString()
}

private fun PracticeHomeBootstrapGameSnapshot.toJson(): JSONObject {
    val normalizedPlayfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocal ?: playfieldLocalOriginal)
    return JSONObject().apply {
        put("libraryEntryId", libraryEntryId)
        put("practiceIdentity", practiceIdentity)
        put("opdbId", opdbId)
        put("opdbGroupId", opdbGroupId)
        put("opdbMachineId", opdbMachineId)
        put("variant", variant)
        put("sourceId", sourceId)
        put("sourceName", sourceName)
        put("sourceType", sourceTypeRaw)
        put("area", area)
        put("areaOrder", areaOrder)
        put("group", group)
        put("position", position)
        put("bank", bank)
        put("name", name)
        put("manufacturer", manufacturer)
        put("year", year)
        put("slug", slug)
        put("primaryImageUrl", primaryImageUrl)
        put("primaryImageLargeUrl", primaryImageLargeUrl)
        put("playfieldImageUrl", playfieldImageUrl)
        put("alternatePlayfieldImageUrl", alternatePlayfieldImageUrl)
        put("playfieldLocalOriginal", normalizedPlayfieldLocal)
        put("playfieldLocal", normalizedPlayfieldLocal)
    }
}

private fun parsePracticeHomeBootstrapSnapshot(raw: String): PracticeHomeBootstrapSnapshot? {
    return runCatching {
        val root = JSONObject(raw)
        PracticeHomeBootstrapSnapshot(
            schemaVersion = root.optInt("schemaVersion", 0),
            capturedAtMs = root.optLong("capturedAtMs", 0L),
            playerName = root.optString("playerName", ""),
            selectedGroupID = root.optString("selectedGroupID").takeIf { it.isNotBlank() && it != "null" },
            groups = root.optJSONArray("groups")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        PracticeGroup(
                            id = obj.optString("id"),
                            name = obj.optString("name"),
                            gameSlugs = obj.optJSONArray("gameSlugs")?.toStringList() ?: emptyList(),
                            type = obj.optString("type", "custom"),
                            isActive = obj.optBoolean("isActive", true),
                            isArchived = obj.optBoolean("isArchived", false),
                            isPriority = obj.optBoolean("isPriority", false),
                            startDateMs = obj.optLong("startDateMs").takeIf { it > 0 },
                            endDateMs = obj.optLong("endDateMs").takeIf { it > 0 },
                        )
                    }
                }
            } ?: emptyList(),
            selectedLibrarySourceId = root.optString("selectedLibrarySourceId").takeIf { it.isNotBlank() && it != "null" },
            librarySources = root.optJSONArray("librarySources")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        PracticeHomeBootstrapSourceSnapshot(
                            id = obj.optString("id"),
                            name = obj.optString("name"),
                            typeRaw = obj.optString("type", "venue"),
                        )
                    }
                }
            } ?: emptyList(),
            visibleGames = root.optJSONArray("visibleGames")?.toGameSnapshots() ?: emptyList(),
            lookupGames = root.optJSONArray("lookupGames")?.toGameSnapshots() ?: emptyList(),
        )
    }.getOrNull()
}

private fun JSONArray.toGameSnapshots(): List<PracticeHomeBootstrapGameSnapshot> {
    return (0 until length()).mapNotNull { idx ->
        optJSONObject(idx)?.let { obj ->
            PracticeHomeBootstrapGameSnapshot(
                libraryEntryId = obj.optString("libraryEntryId").takeIf { it.isNotBlank() && it != "null" },
                practiceIdentity = obj.optString("practiceIdentity").takeIf { it.isNotBlank() && it != "null" },
                opdbId = obj.optString("opdbId").takeIf { it.isNotBlank() && it != "null" },
                opdbGroupId = obj.optString("opdbGroupId").takeIf { it.isNotBlank() && it != "null" },
                opdbMachineId = obj.optString("opdbMachineId").takeIf { it.isNotBlank() && it != "null" },
                variant = obj.optString("variant").takeIf { it.isNotBlank() && it != "null" },
                sourceId = obj.optString("sourceId"),
                sourceName = obj.optString("sourceName"),
                sourceTypeRaw = obj.optString("sourceType", "venue"),
                area = obj.optString("area").takeIf { it.isNotBlank() && it != "null" },
                areaOrder = obj.optInt("areaOrder").takeIf { !obj.isNull("areaOrder") },
                group = obj.optInt("group").takeIf { !obj.isNull("group") },
                position = obj.optInt("position").takeIf { !obj.isNull("position") },
                bank = obj.optInt("bank").takeIf { !obj.isNull("bank") },
                name = obj.optString("name"),
                manufacturer = obj.optString("manufacturer").takeIf { it.isNotBlank() && it != "null" },
                year = obj.optInt("year").takeIf { !obj.isNull("year") },
                slug = obj.optString("slug"),
                primaryImageUrl = obj.optString("primaryImageUrl").takeIf { it.isNotBlank() && it != "null" },
                primaryImageLargeUrl = obj.optString("primaryImageLargeUrl").takeIf { it.isNotBlank() && it != "null" },
                playfieldImageUrl = obj.optString("playfieldImageUrl").takeIf { it.isNotBlank() && it != "null" },
                alternatePlayfieldImageUrl = obj.optString("alternatePlayfieldImageUrl").takeIf { it.isNotBlank() && it != "null" },
                playfieldLocalOriginal = obj.optString("playfieldLocalOriginal").takeIf { it.isNotBlank() && it != "null" },
                playfieldLocal = obj.optString("playfieldLocal").takeIf { it.isNotBlank() && it != "null" },
            )
        }
    }
}
