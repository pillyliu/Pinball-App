package com.pillyliu.pinprofandroid.library

import org.json.JSONObject

internal data class TiltForumsParsedDocument(
    val cooked: String,
    val canonicalUrl: String,
    val updatedAt: String?,
)

internal fun tiltForumsApiUrl(rawUrl: String): String {
    return if (rawUrl.contains("/posts/") && rawUrl.lowercase().endsWith(".json")) {
        rawUrl
    } else {
        rawUrl.substringBefore('?').let { if (it.lowercase().endsWith(".json")) it else "$it.json" }
    }
}

internal fun parseTiltForumsPayload(payload: String, fallbackUrl: String): TiltForumsParsedDocument {
    val root = JSONObject(payload)
    val posts = root.optJSONObject("post_stream")?.optJSONArray("posts")
    val post = when {
        posts != null && posts.length() > 0 -> posts.optJSONObject(0)
        else -> root
    } ?: error("Invalid Tilt Forums payload.")
    val cooked = post.optString("cooked").trim().ifBlank { error("Missing Tilt Forums content.") }
    val topicSlug = post.optString("topic_slug").ifBlank { null }
    val topicId = post.optInt("topic_id").takeIf { it > 0 }
    val canonicalUrl = if (topicSlug != null && topicId != null) {
        "https://tiltforums.com/t/$topicSlug/$topicId"
    } else {
        canonicalTopicUrl(fallbackUrl)
    }
    return TiltForumsParsedDocument(
        cooked = cooked,
        canonicalUrl = canonicalUrl,
        updatedAt = post.optString("updated_at").ifBlank { null },
    )
}

private fun canonicalTopicUrl(rawUrl: String): String = rawUrl.substringBefore('?').removeSuffix(".json")
