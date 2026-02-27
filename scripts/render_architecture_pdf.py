#!/usr/bin/env python3
"""Render the architecture markdown into a print-layout PDF.

Uses ReportLab only (no external PDF engine requirement).
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
from pathlib import Path
from typing import List

from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, StyleSheet1, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer


def build_styles() -> StyleSheet1:
    styles = getSampleStyleSheet()

    styles.add(
        ParagraphStyle(
            name="BodySmall",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9.5,
            leading=13,
            wordWrap="CJK",
            textColor=colors.HexColor("#1f2937"),
        )
    )

    styles.add(
        ParagraphStyle(
            name="H1App",
            parent=styles["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=18,
            leading=22,
            spaceBefore=8,
            spaceAfter=10,
            textColor=colors.HexColor("#0f172a"),
        )
    )

    styles.add(
        ParagraphStyle(
            name="H2App",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=13,
            leading=16,
            spaceBefore=10,
            spaceAfter=6,
            textColor=colors.HexColor("#111827"),
        )
    )

    styles.add(
        ParagraphStyle(
            name="H3App",
            parent=styles["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11,
            leading=14,
            spaceBefore=8,
            spaceAfter=4,
            textColor=colors.HexColor("#1f2937"),
        )
    )

    styles.add(
        ParagraphStyle(
            name="CodeBlock",
            parent=styles["BodyText"],
            fontName="Courier",
            fontSize=8,
            leading=10,
            leftIndent=10,
            rightIndent=6,
            borderColor=colors.HexColor("#d1d5db"),
            borderWidth=0.6,
            borderPadding=6,
            backColor=colors.HexColor("#f8fafc"),
            wordWrap="CJK",
            textColor=colors.HexColor("#111827"),
        )
    )

    styles.add(
        ParagraphStyle(
            name="Footer",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=8,
            leading=10,
            alignment=TA_RIGHT,
            textColor=colors.HexColor("#6b7280"),
        )
    )

    return styles


def flush_paragraph(buffer: List[str], story: list, styles: StyleSheet1) -> None:
    if not buffer:
        return
    text = " ".join(item.strip() for item in buffer if item.strip())
    if text:
        story.append(Paragraph(html.escape(text), styles["BodySmall"]))
        story.append(Spacer(1, 4))
    buffer.clear()


def flush_bullets(items: List[str], story: list, styles: StyleSheet1) -> None:
    if not items:
        return
    clean_items = [item.strip() for item in items if item.strip()]
    if clean_items:
        for item in clean_items:
            story.append(Paragraph(f"- {html.escape(item)}", styles["BodySmall"]))
        story.append(Spacer(1, 4))
    items.clear()


def flush_code(lines: List[str], story: list, styles: StyleSheet1) -> None:
    if not lines:
        return
    code_text = "<br/>".join(html.escape(line.rstrip("\n")) for line in lines)
    story.append(Paragraph(code_text, styles["CodeBlock"]))
    story.append(Spacer(1, 6))
    lines.clear()


def parse_markdown(md_text: str, styles: StyleSheet1) -> list:
    story: list = []

    in_code = False
    code_lines: List[str] = []
    para_buffer: List[str] = []
    bullet_buffer: List[str] = []

    for raw_line in md_text.splitlines():
        line = raw_line.rstrip("\n")
        stripped = line.strip()

        if stripped.startswith("```"):
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            if in_code:
                flush_code(code_lines, story, styles)
                in_code = False
            else:
                in_code = True
                code_lines = []
            continue

        if in_code:
            code_lines.append(line)
            continue

        if not stripped:
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            story.append(Spacer(1, 2))
            continue

        if stripped == "---":
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            story.append(Spacer(1, 8))
            continue

        if stripped.startswith("# "):
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            story.append(Paragraph(html.escape(stripped[2:].strip()), styles["H1App"]))
            continue

        if stripped.startswith("## "):
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            story.append(Paragraph(html.escape(stripped[3:].strip()), styles["H2App"]))
            continue

        if stripped.startswith("### "):
            flush_paragraph(para_buffer, story, styles)
            flush_bullets(bullet_buffer, story, styles)
            story.append(Paragraph(html.escape(stripped[4:].strip()), styles["H3App"]))
            continue

        if stripped.startswith("- "):
            flush_paragraph(para_buffer, story, styles)
            bullet_buffer.append(stripped[2:])
            continue

        if stripped.startswith("1. ") or stripped.startswith("2. ") or stripped.startswith("3. ") or stripped.startswith("4. "):
            flush_paragraph(para_buffer, story, styles)
            bullet_buffer.append(stripped)
            continue

        # Keep markdown tables and inline-code-heavy rows readable as body lines.
        para_buffer.append(stripped)

    flush_paragraph(para_buffer, story, styles)
    flush_bullets(bullet_buffer, story, styles)
    flush_code(code_lines, story, styles)

    return story


def draw_footer(canvas, doc, source_name: str) -> None:
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#6b7280"))
    ts = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
    footer = f"{source_name} | Generated {ts} | Page {doc.page}"
    canvas.drawRightString(doc.pagesize[0] - 0.6 * inch, 0.45 * inch, footer)
    canvas.restoreState()


def render_markdown_to_pdf(markdown_path: Path, output_path: Path) -> None:
    styles = build_styles()
    text = markdown_path.read_text(encoding="utf-8")
    story = parse_markdown(text, styles)

    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=LETTER,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.72 * inch,
        bottomMargin=0.72 * inch,
        title="Pinball App Architecture Blueprint",
        author="Pinball App",
    )

    source_name = markdown_path.name
    doc.build(
        story,
        onFirstPage=lambda c, d: draw_footer(c, d, source_name),
        onLaterPages=lambda c, d: draw_footer(c, d, source_name),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Render architecture markdown into print-layout PDF.")
    parser.add_argument("--input", required=True, help="Input markdown path")
    parser.add_argument("--output", required=True, help="Output PDF path")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    render_markdown_to_pdf(input_path, output_path)


if __name__ == "__main__":
    main()
