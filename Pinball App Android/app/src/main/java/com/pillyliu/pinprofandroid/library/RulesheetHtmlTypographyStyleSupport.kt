package com.pillyliu.pinprofandroid.library

internal fun rulesheetHtmlTypographyStyles(
    bodyColorHex: String,
    mutedColorHex: String,
    linkColorHex: String,
    linkSoftHex: String,
    codeBgHex: String,
    tableBorderHex: String,
    blockquoteBarHex: String,
): String = """
    :root {
        --text: $bodyColorHex;
        --text-muted: $mutedColorHex;
        --link: $linkColorHex;
        --link-soft: $linkSoftHex;
        --code-bg: $codeBgHex;
        --code-text: $bodyColorHex;
        --rule: $tableBorderHex;
        --table-border: $tableBorderHex;
        --blockquote-bar: $blockquoteBarHex;
    }
    html, body {
        margin: 0;
        padding: 0;
        background: transparent;
    }
    body {
        padding: 76px 16px 28px;
        font-family: sans-serif;
        -webkit-text-size-adjust: 100%;
        text-size-adjust: 100%;
        color: var(--text);
        line-height: 1.5;
        font-size: 16px;
        box-sizing: border-box;
    }
    *, *:before, *:after {
        box-sizing: border-box;
    }
    #content {
        margin: 0 auto;
        max-width: 44rem;
        overflow-x: hidden;
        overflow-wrap: anywhere;
        word-break: normal;
    }
    #content > :first-child { margin-top: 0 !important; }
    #content > :last-child { margin-bottom: 0 !important; }
    p, ul, ol, blockquote, pre, table, hr {
        margin: 0 0 0.95rem;
    }
    p, li, dd, dt, small, div, span {
        max-width: 100%;
        overflow-wrap: anywhere;
        word-wrap: break-word;
        word-break: break-word;
        white-space: normal;
    }
    a {
        color: var(--link);
        text-decoration: underline;
        text-decoration-thickness: 0.08em;
        text-underline-offset: 0.14em;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
    a:hover {
        background: var(--link-soft);
    }
    h1, h2, h3, h4, h5, h6 {
        color: var(--text);
        line-height: 1.2;
        margin: 1.35rem 0 0.55rem;
    }
    h1 { font-size: 1.8rem; letter-spacing: -0.02em; }
    h2 {
        font-size: 1.35rem;
        letter-spacing: -0.015em;
        padding-bottom: 0.2rem;
        border-bottom: 1px solid var(--rule);
    }
    h3 { font-size: 1.08rem; }
    h4, h5, h6 { font-size: 0.98rem; }
    strong { color: var(--text); }
    small, .bodySmall, .rulesheet-attribution {
        color: var(--text-muted);
    }
    ul, ol {
        padding-left: 1.35rem;
    }
    li {
        margin: 0.18rem 0;
    }
    li > ul, li > ol {
        margin-top: 0.28rem;
        margin-bottom: 0.28rem;
    }
    blockquote {
        margin-left: 0;
        padding: 0.15rem 0 0.15rem 0.95rem;
        border-left: 3px solid var(--blockquote-bar);
        color: var(--text-muted);
        background: transparent;
    }
    code, pre {
        background: var(--code-bg);
        border-radius: 10px;
        color: var(--code-text);
    }
    code {
        padding: 0.12rem 0.34rem;
        overflow-wrap: anywhere;
        word-break: break-word;
    }
    pre {
        padding: 12px 14px;
        overflow-x: auto;
        border: 1px solid var(--rule);
    }
    pre code {
        padding: 0;
        background: transparent;
        border-radius: 0;
    }
    img {
        display: block;
        max-width: 100%;
        height: auto;
        margin: 0.5rem auto;
        border-radius: 10px;
    }
    hr {
        border: none;
        border-top: 1px solid var(--rule);
    }
    .pinball-rulesheet, .remote-rulesheet {
        display: block;
    }
    .legacy-rulesheet .bodyTitle {
        display: block;
        font-size: 1.08rem;
        font-weight: 700;
        margin: 1rem 0 0.4rem;
    }
    .legacy-rulesheet .bodySmall {
        display: block;
        font-size: 0.92rem;
        opacity: 0.88;
    }
    .legacy-rulesheet pre.rulesheet-preformatted {
        white-space: pre-wrap;
        font: inherit;
        background: transparent;
        padding: 0;
        border-radius: 0;
        border: none;
    }
    .rulesheet-attribution {
        display: block;
        font-size: 0.78rem;
        line-height: 1.35;
        opacity: 0.92;
        margin-bottom: 0.8rem;
    }
    .rulesheet-attribution, .rulesheet-attribution * {
        overflow-wrap: anywhere;
        word-break: break-word;
    }
""".trimIndent()
