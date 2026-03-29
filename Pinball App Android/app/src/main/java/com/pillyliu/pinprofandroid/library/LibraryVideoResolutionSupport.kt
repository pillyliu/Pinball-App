package com.pillyliu.pinprofandroid.library

internal fun resolveVideoLinks(videoLinks: List<CatalogVideoLinkRecord>): List<Video> {
    val selected = linkedMapOf<String, CatalogVideoLinkRecord>()
    videoLinks.sortedWith(compareVideoLinks()).forEach { link ->
        val url = normalizedOptionalString(link.url) ?: return@forEach
        val key = canonicalVideoMergeKey(link.kind, url)
        if (key !in selected) {
            selected[key] = link
        }
    }
    return selected.values
        .sortedWith(compareVideoLinks())
        .map { link -> Video(kind = link.kind, label = link.label, url = link.url) }
}

internal fun compareVideoLinks(): Comparator<CatalogVideoLinkRecord> =
    Comparator { lhs, rhs ->
        val kindComparison = videoKindOrder(lhs.kind).compareTo(videoKindOrder(rhs.kind))
        if (kindComparison != 0) return@Comparator kindComparison

        val priorityComparison = (lhs.priority ?: Int.MAX_VALUE).compareTo(rhs.priority ?: Int.MAX_VALUE)
        if (priorityComparison != 0) return@Comparator priorityComparison

        val labelComparison = compareNaturalVideoLabels(lhs.label, rhs.label)
        if (labelComparison != 0) return@Comparator labelComparison

        val providerComparison = videoProviderOrder(lhs.provider).compareTo(videoProviderOrder(rhs.provider))
        if (providerComparison != 0) return@Comparator providerComparison

        normalizedOptionalString(lhs.url).orEmpty().lowercase()
            .compareTo(normalizedOptionalString(rhs.url).orEmpty().lowercase())
    }

private fun videoProviderOrder(provider: String): Int =
    when (provider.trim().lowercase()) {
        "local" -> 0
        "matchplay" -> 1
        else -> 99
    }

private fun videoKindOrder(kind: String?): Int =
    when (kind?.trim()?.lowercase()) {
        "tutorial" -> 0
        "gameplay" -> 1
        "competition" -> 2
        else -> 99
    }

private fun extractYouTubeVideoId(rawUrl: String): String? {
    val uri = runCatching { android.net.Uri.parse(rawUrl) }.getOrNull() ?: return null
    val host = uri.host?.trim()?.lowercase() ?: return null
    val pathParts = uri.pathSegments?.filter { it.isNotBlank() }.orEmpty()
    return when {
        host == "youtu.be" || host == "www.youtu.be" -> pathParts.firstOrNull()
        host == "youtube.com" ||
            host == "www.youtube.com" ||
            host == "m.youtube.com" ||
            host == "music.youtube.com" ||
            host == "youtube-nocookie.com" ||
            host == "www.youtube-nocookie.com" ||
            host.endsWith(".youtube.com") ||
            host.endsWith(".youtube-nocookie.com") -> when {
                pathParts.firstOrNull() == "watch" -> uri.getQueryParameter("v")
                pathParts.firstOrNull() in setOf("embed", "shorts", "live") && pathParts.size >= 2 -> pathParts[1]
                else -> uri.getQueryParameter("v")
            }
        else -> null
    }
}

private fun canonicalVideoIdentity(url: String): String =
    extractYouTubeVideoId(url)?.let { "youtube:$it" } ?: "url:${url.trim()}"

private fun canonicalVideoMergeKey(kind: String?, url: String): String =
    "${kind?.trim()?.lowercase().orEmpty()}::${canonicalVideoIdentity(url)}"

internal fun mergeResolvedVideos(primary: List<Video>, secondary: List<Video>): List<Video> {
    val merged = linkedMapOf<String, Video>()
    (primary + secondary).forEach { video ->
        val url = normalizedOptionalString(video.url) ?: return@forEach
        val key = canonicalVideoMergeKey(video.kind, url)
        if (key !in merged) {
            merged[key] = video
        }
    }
    return merged.values.sortedWith(::compareResolvedVideos)
}

private fun compareResolvedVideos(lhs: Video, rhs: Video): Int {
    val kindComparison = videoKindOrder(lhs.kind).compareTo(videoKindOrder(rhs.kind))
    if (kindComparison != 0) return kindComparison

    val labelComparison = compareNaturalVideoLabels(
        resolvedVideoSortLabel(lhs),
        resolvedVideoSortLabel(rhs),
    )
    if (labelComparison != 0) return labelComparison

    return normalizedOptionalString(lhs.url).orEmpty().lowercase()
        .compareTo(normalizedOptionalString(rhs.url).orEmpty().lowercase())
}

private fun resolvedVideoSortLabel(video: Video): String {
    val trimmedLabel = video.label?.trim().orEmpty()
    if (trimmedLabel.isNotEmpty()) return trimmedLabel
    val trimmedKind = video.kind?.trim().orEmpty()
    if (trimmedKind.isNotEmpty()) return trimmedKind.replace("_", " ")
    return ""
}

private fun compareNaturalVideoLabels(lhs: String, rhs: String): Int {
    val leftTokens = naturalVideoLabelTokens(lhs)
    val rightTokens = naturalVideoLabelTokens(rhs)
    val count = minOf(leftTokens.size, rightTokens.size)

    for (index in 0 until count) {
        val left = leftTokens[index]
        val right = rightTokens[index]

        if (left.isNumber && right.isNumber) {
            val leftValue = left.text.toLongOrNull() ?: Long.MAX_VALUE
            val rightValue = right.text.toLongOrNull() ?: Long.MAX_VALUE
            if (leftValue != rightValue) return leftValue.compareTo(rightValue)
            if (left.text.length != right.text.length) return left.text.length.compareTo(right.text.length)
            continue
        }

        val textComparison = left.text.lowercase().compareTo(right.text.lowercase())
        if (textComparison != 0) return textComparison
    }

    if (leftTokens.size != rightTokens.size) {
        return leftTokens.size.compareTo(rightTokens.size)
    }

    return lhs.lowercase().compareTo(rhs.lowercase())
}

private data class NaturalVideoLabelToken(val text: String, val isNumber: Boolean)

private fun naturalVideoLabelTokens(label: String): List<NaturalVideoLabelToken> {
    val trimmed = label.trim()
    if (trimmed.isEmpty()) return emptyList()
    val tokens = mutableListOf<NaturalVideoLabelToken>()
    var current = StringBuilder()
    var currentIsNumber = trimmed.first().isDigit()

    trimmed.forEach { character ->
        val isNumber = character.isDigit()
        if (current.isNotEmpty() && isNumber != currentIsNumber) {
            tokens += NaturalVideoLabelToken(current.toString(), currentIsNumber)
            current = StringBuilder()
        }
        current.append(character)
        currentIsNumber = isNumber
    }

    if (current.isNotEmpty()) {
        tokens += NaturalVideoLabelToken(current.toString(), currentIsNumber)
    }
    return tokens
}
