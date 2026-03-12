package com.pillyliu.pinprofandroid.practice

internal fun formatScoreInputWithCommas(raw: String): String {
    val digits = raw.filter { it.isDigit() }
    if (digits.isEmpty()) return ""
    return digits.reversed().chunked(3).joinToString(",").reversed()
}
