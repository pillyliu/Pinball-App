package com.pillyliu.pinprofandroid.library

internal fun rulesheetHtmlStyles(
    bodyColorHex: String,
    mutedColorHex: String,
    linkColorHex: String,
    linkSoftHex: String,
    codeBgHex: String,
    panelHex: String,
    panelStrongHex: String,
    tableBorderHex: String,
    blockquoteBarHex: String,
): String = listOf(
    rulesheetHtmlTypographyStyles(
        bodyColorHex = bodyColorHex,
        mutedColorHex = mutedColorHex,
        linkColorHex = linkColorHex,
        linkSoftHex = linkSoftHex,
        codeBgHex = codeBgHex,
        tableBorderHex = tableBorderHex,
        blockquoteBarHex = blockquoteBarHex,
    ),
    rulesheetHtmlTableStyles(
        panelHex = panelHex,
        panelStrongHex = panelStrongHex,
    ),
    rulesheetResponsiveHtmlStyles(),
).joinToString(separator = "\n")

private fun rulesheetResponsiveHtmlStyles(): String = """
    @media (orientation: landscape) {
        body {
            padding-top: 19px;
        }
    }
    @media (min-width: 820px) {
        body {
            padding-left: 24px;
            padding-right: 24px;
        }
    }
""".trimIndent()
