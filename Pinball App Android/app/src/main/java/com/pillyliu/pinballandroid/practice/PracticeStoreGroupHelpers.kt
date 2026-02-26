package com.pillyliu.pinballandroid.practice

import java.util.UUID

internal data class GroupCreateResult(
    val groups: List<PracticeGroup>,
    val createdId: String,
    val selectedGroupID: String?,
)

internal data class GroupDeleteResult(
    val groups: List<PracticeGroup>,
    val selectedGroupID: String?,
)

internal fun selectCurrentGroup(
    groups: List<PracticeGroup>,
    selectedGroupID: String?,
): PracticeGroup? {
    val selected = selectedGroupID?.let { id -> groups.firstOrNull { it.id == id } }
    if (selected != null) return selected
    return groups.firstOrNull { !it.isArchived && it.isActive && it.isPriority }
        ?: groups.firstOrNull { !it.isArchived && it.isActive }
        ?: groups.firstOrNull { !it.isArchived }
        ?: groups.firstOrNull()
}

internal fun createGroupInList(
    existing: List<PracticeGroup>,
    selectedGroupID: String?,
    name: String,
    gameSlugs: List<String>,
    isActive: Boolean,
    isPriority: Boolean,
    type: String,
    startDateMs: Long?,
    endDateMs: Long?,
    isArchived: Boolean,
    insertAt: Int?,
    nowMs: Long,
): GroupCreateResult? {
    val trimmed = name.trim()
    if (trimmed.isEmpty()) return null
    val id = UUID.randomUUID().toString()
    val newGroup = PracticeGroup(
        id = id,
        name = trimmed,
        gameSlugs = gameSlugs.distinct(),
        type = type,
        isActive = isActive,
        isArchived = isArchived,
        isPriority = isPriority,
        startDateMs = startDateMs ?: nowMs,
        endDateMs = endDateMs,
    )
    val base = if (isPriority) {
        existing.map { it.copy(isPriority = false) }.toMutableList()
    } else {
        existing.toMutableList()
    }
    val targetIndex = (insertAt ?: base.size).coerceIn(0, base.size)
    base.add(targetIndex, newGroup)
    return GroupCreateResult(
        groups = base,
        createdId = id,
        selectedGroupID = selectedGroupID ?: id,
    )
}

internal fun updateGroupInList(
    existing: List<PracticeGroup>,
    updated: PracticeGroup,
): List<PracticeGroup> {
    return existing.map {
        if (it.id == updated.id) updated else if (updated.isPriority) it.copy(isPriority = false) else it
    }
}

internal fun removeGameFromGroupInList(
    existing: List<PracticeGroup>,
    groupID: String,
    gameSlug: String,
): List<PracticeGroup> {
    val group = existing.firstOrNull { it.id == groupID } ?: return existing
    return updateGroupInList(existing, group.copy(gameSlugs = group.gameSlugs.filterNot { it == gameSlug }))
}

internal fun moveGroupInList(
    existing: List<PracticeGroup>,
    groupID: String,
    up: Boolean,
): List<PracticeGroup> {
    val index = existing.indexOfFirst { it.id == groupID }
    if (index < 0) return existing
    val target = if (up) index - 1 else index + 1
    if (target !in existing.indices) return existing
    val mutable = existing.toMutableList()
    val moving = mutable.removeAt(index)
    mutable.add(target, moving)
    return mutable
}

internal fun deleteGroupFromList(
    existing: List<PracticeGroup>,
    selectedGroupID: String?,
    groupID: String,
): GroupDeleteResult {
    val nextGroups = existing.filterNot { it.id == groupID }
    val nextSelected = if (selectedGroupID == groupID) {
        nextGroups.firstOrNull()?.id
    } else {
        selectedGroupID
    }
    return GroupDeleteResult(groups = nextGroups, selectedGroupID = nextSelected)
}

internal fun autoArchiveExpiredGroups(
    groups: List<PracticeGroup>,
    nowMs: Long = System.currentTimeMillis(),
): List<PracticeGroup> {
    var changed = false
    val updated = groups.map { group ->
        val endMs = group.endDateMs
        if (group.isArchived || endMs == null) return@map group
        val archiveAt = startOfDayMillis(endMs) + DAY_MS
        if (nowMs >= archiveAt) {
            changed = true
            group.copy(isArchived = true, isActive = false, isPriority = false)
        } else {
            group
        }
    }
    return if (changed) updated else groups
}

internal fun activeGroupForGame(
    groups: List<PracticeGroup>,
    gameSlug: String,
): PracticeGroup? {
    val matches = groups.withIndex().filter { (_, group) ->
        !group.isArchived && group.isActive && group.gameSlugs.contains(gameSlug)
    }
    if (matches.isEmpty()) return null
    return matches.firstOrNull { it.value.isPriority }?.value ?: matches.first().value
}

private const val DAY_MS: Long = 24L * 60L * 60L * 1000L

private fun startOfDayMillis(timestampMs: Long): Long {
    val calendar = java.util.Calendar.getInstance().apply { timeInMillis = timestampMs }
    calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
    calendar.set(java.util.Calendar.MINUTE, 0)
    calendar.set(java.util.Calendar.SECOND, 0)
    calendar.set(java.util.Calendar.MILLISECOND, 0)
    return calendar.timeInMillis
}
