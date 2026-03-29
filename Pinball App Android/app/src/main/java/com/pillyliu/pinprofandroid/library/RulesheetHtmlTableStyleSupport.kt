package com.pillyliu.pinprofandroid.library

internal fun rulesheetHtmlTableStyles(
    panelHex: String,
    panelStrongHex: String,
): String = """
    :root {
        --panel: $panelHex;
        --panel-strong: $panelStrongHex;
    }
    .table-scroll {
        overflow-x: auto;
        overflow-y: visible;
        -webkit-overflow-scrolling: touch;
        margin: 0 0 1rem;
        padding-bottom: 0.1rem;
        border: 1px solid var(--table-border);
        border-radius: 12px;
        background: var(--panel);
    }
    table {
        border-collapse: separate;
        border-spacing: 0;
        width: 100%;
        table-layout: auto;
        margin-bottom: 0;
    }
    th, td {
        border-right: 1px solid var(--table-border);
        border-bottom: 1px solid var(--table-border);
        padding: 8px 10px;
        vertical-align: top;
        word-break: normal;
        overflow-wrap: normal;
        white-space: normal;
    }
    tr > :last-child {
        border-right: none;
    }
    tbody tr:last-child td,
    table tr:last-child td {
        border-bottom: none;
    }
    th {
        background: var(--panel-strong);
        text-align: left;
    }
    thead tr:first-child th:first-child,
    table tr:first-child > *:first-child {
        border-top-left-radius: 12px;
    }
    thead tr:first-child th:last-child,
    table tr:first-child > *:last-child {
        border-top-right-radius: 12px;
    }
    tbody tr:last-child td:first-child,
    table tr:last-child td:first-child {
        border-bottom-left-radius: 12px;
    }
    tbody tr:last-child td:last-child,
    table tr:last-child td:last-child {
        border-bottom-right-radius: 12px;
    }
    .primer-rulesheet table td:first-child,
    .primer-rulesheet table th:first-child {
        width: 34%;
        min-width: 7.5rem;
    }
    .primer-rulesheet table td:last-child,
    .primer-rulesheet table th:last-child {
        width: 66%;
    }
    table img,
    .table-scroll img {
        width: auto;
        max-height: min(42vh, 24rem);
        object-fit: contain;
    }
""".trimIndent()
