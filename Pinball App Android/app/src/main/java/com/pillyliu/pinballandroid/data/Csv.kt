package com.pillyliu.pinballandroid.data

fun parseCsv(text: String): List<List<String>> {
    val rows = mutableListOf<List<String>>()
    val row = mutableListOf<String>()
    val field = StringBuilder()
    var inQuotes = false
    var i = 0

    while (i < text.length) {
        val c = text[i]
        if (inQuotes) {
            if (c == '"') {
                if (i + 1 < text.length && text[i + 1] == '"') {
                    field.append('"')
                    i += 1
                } else {
                    inQuotes = false
                }
            } else {
                field.append(c)
            }
        } else {
            when (c) {
                '"' -> inQuotes = true
                ',' -> {
                    row.add(field.toString())
                    field.setLength(0)
                }
                '\n' -> {
                    row.add(field.toString())
                    rows.add(row.toList())
                    row.clear()
                    field.setLength(0)
                }
                '\r' -> Unit
                else -> field.append(c)
            }
        }
        i += 1
    }

    if (field.isNotEmpty() || row.isNotEmpty()) {
        row.add(field.toString())
        rows.add(row.toList())
    }

    return rows
}
