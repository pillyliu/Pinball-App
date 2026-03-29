import Foundation

let rulesheetHTMLDocumentStyles = """
:root {
  color-scheme: light dark;
  --text: #162035;
  --text-muted: #556270;
  --link: #0a65cc;
  --link-soft: rgba(10, 101, 204, 0.14);
  --panel: rgba(255, 255, 255, 0.72);
  --panel-strong: rgba(255, 255, 255, 0.9);
  --code-bg: #eef2f7;
  --code-text: #162035;
  --rule: rgba(22, 32, 53, 0.14);
  --table-border: rgba(22, 32, 53, 0.14);
  --blockquote-bar: rgba(10, 101, 204, 0.42);
}
@media (prefers-color-scheme: dark) {
  :root {
    --text: #e7efff;
    --text-muted: #aebcd2;
    --link: #a6c8ff;
    --link-soft: rgba(166, 200, 255, 0.16);
    --panel: rgba(16, 22, 34, 0.72);
    --panel-strong: rgba(18, 25, 39, 0.9);
    --code-bg: #111824;
    --code-text: #f3f7ff;
    --rule: rgba(231, 239, 255, 0.12);
    --table-border: rgba(231, 239, 255, 0.12);
    --blockquote-bar: rgba(166, 200, 255, 0.5);
  }
}
html, body {
  margin: 0;
  padding: 0;
  background: transparent;
}
body {
  padding: 76px 16px calc(env(safe-area-inset-bottom) + 28px);
  font: -apple-system-body;
  -webkit-text-size-adjust: 100%;
  text-size-adjust: 100%;
  color: var(--text);
  line-height: 1.5;
  box-sizing: border-box;
}
@media (orientation: landscape) {
  body {
    padding-top: 19px;
  }
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
  scroll-margin-top: 88px;
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
img {
  display: block;
  max-width: 100%;
  height: auto;
  margin: 0.5rem auto;
  border-radius: 10px;
}
table img,
.table-scroll img {
  width: auto;
  max-height: min(42vh, 24rem);
  object-fit: contain;
}
hr { border: none; border-top: 1px solid var(--rule); }
.pinball-rulesheet, .remote-rulesheet { display: block; }
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
@media (min-width: 820px) {
  body {
    padding-left: 24px;
    padding-right: 24px;
  }
}
"""
