package com.pillyliu.pinprofandroid.practice

import java.nio.charset.StandardCharsets
import java.util.UUID

internal fun validUuidOrStable(prefix: String, raw: String?): String {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isNotBlank()) {
        runCatching { UUID.fromString(trimmed) }.getOrNull()?.let { return it.toString() }
    }
    return stableUuidForLegacy(prefix, trimmed.ifBlank { "$prefix-empty" })
}

internal fun stableUuidForLegacy(prefix: String, raw: String): String {
    return UUID.nameUUIDFromBytes("$prefix:$raw".toByteArray(StandardCharsets.UTF_8)).toString()
}
