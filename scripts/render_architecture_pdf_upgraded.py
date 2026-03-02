#!/usr/bin/env python3
"""Render architecture markdown to a polished print-layout PDF with embedded Mermaid diagrams."""

from __future__ import annotations

import argparse
import datetime as dt
import html
import re
from pathlib import Path
from typing import List

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, StyleSheet1, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image, Paragraph, Preformatted, SimpleDocTemplate, Spacer


def render_inline_markdown(text: str, mono_font: str) -> str:
    # Protect inline code spans first so emphasis parsing does not mutate them.
    code_tokens: list[str] = []

    def _stash_code(match: re.Match[str]) -> str:
        code_tokens.append(match.group(1))
        return f"@@CODE{len(code_tokens)-1}@@"

    text = re.sub(r"`([^`]+)`", _stash_code, text)
    text = html.escape(text)

    # Basic inline markdown support for PDF text rendering.
    text = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        r"<font color='#1D4ED8'><u>\1</u></font>",
        text,
    )
    text = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", text)
    text = re.sub(r"(?<!_)_([^_]+)_(?!_)", r"<i>\1</i>", text)

    for idx, code in enumerate(code_tokens):
        code_html = (
            f"<font name='{mono_font}' backColor='#EEF2FF'>"
            f"{html.escape(code)}"
            "</font>"
        )
        text = text.replace(f"@@CODE{idx}@@", code_html)

    return text


def register_fonts() -> dict[str, str]:
    candidates = {
        "serif": [
            ("Georgia", "/System/Library/Fonts/Supplemental/Georgia.ttf"),
            ("Times-Roman", None),
        ],
        "serif_bold": [
            ("Georgia-Bold", "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"),
            ("Times-Bold", None),
        ],
        "mono": [
            ("Menlo", "/System/Library/Fonts/Menlo.ttc"),
            ("Courier", None),
        ],
    }

    selected: dict[str, str] = {}
    for key, options in candidates.items():
        for font_name, font_path in options:
            if font_path is None:
                selected[key] = font_name
                break
            path = Path(font_path)
            if not path.exists():
                continue
            try:
                pdfmetrics.registerFont(TTFont(font_name, str(path)))
                selected[key] = font_name
                break
            except Exception:
                continue
        if key not in selected:
            selected[key] = "Helvetica"
    return selected


def build_styles(fonts: dict[str, str]) -> StyleSheet1:
    styles = getSampleStyleSheet()

    styles.add(
        ParagraphStyle(
            name="TitleApp",
            parent=styles["Title"],
            fontName=fonts["serif_bold"],
            fontSize=24,
            leading=28,
            textColor=colors.HexColor("#0B1220"),
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Subtitle",
            parent=styles["Normal"],
            fontName=fonts["serif"],
            fontSize=11,
            leading=15,
            textColor=colors.HexColor("#334155"),
            spaceAfter=16,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H1App",
            parent=styles["Heading1"],
            fontName=fonts["serif_bold"],
            fontSize=16,
            leading=20,
            textColor=colors.HexColor("#0F172A"),
            spaceBefore=12,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H2App",
            parent=styles["Heading2"],
            fontName=fonts["serif_bold"],
            fontSize=13,
            leading=17,
            textColor=colors.HexColor("#111827"),
            spaceBefore=10,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H3App",
            parent=styles["Heading3"],
            fontName=fonts["serif_bold"],
            fontSize=11.5,
            leading=15,
            textColor=colors.HexColor("#1F2937"),
            spaceBefore=8,
            spaceAfter=5,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyApp",
            parent=styles["BodyText"],
            fontName=fonts["serif"],
            fontSize=10.2,
            leading=14.2,
            textColor=colors.HexColor("#111827"),
            spaceAfter=4,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BulletApp",
            parent=styles["BodyText"],
            fontName=fonts["serif"],
            fontSize=10.2,
            leading=14.2,
            leftIndent=12,
            bulletIndent=2,
            textColor=colors.HexColor("#111827"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="CodeApp",
            parent=styles["BodyText"],
            fontName=fonts["mono"],
            fontSize=8.6,
            leading=11,
            leftIndent=10,
            rightIndent=8,
            borderColor=colors.HexColor("#D1D5DB"),
            borderWidth=0.6,
            borderPadding=6,
            backColor=colors.HexColor("#F8FAFC"),
            textColor=colors.HexColor("#0F172A"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="Caption",
            parent=styles["Normal"],
            fontName=fonts["serif"],
            fontSize=8.8,
            leading=11,
            textColor=colors.HexColor("#475569"),
            alignment=TA_CENTER,
            spaceBefore=3,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Footer",
            parent=styles["Normal"],
            fontName=fonts["serif"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#64748B"),
            alignment=TA_RIGHT,
        )
    )
    return styles


def flush_paragraph(buf: List[str], story: list, styles: StyleSheet1, mono_font: str) -> None:
    if not buf:
        return
    text = " ".join(part.strip() for part in buf if part.strip())
    if text:
        story.append(Paragraph(render_inline_markdown(text, mono_font), styles["BodyApp"]))
    buf.clear()


def flush_bullets(buf: List[str], story: list, styles: StyleSheet1, mono_font: str) -> None:
    if not buf:
        return
    for item in buf:
        if item.strip():
            bullet_text = render_inline_markdown(item.strip(), mono_font)
            story.append(Paragraph(f"- {bullet_text}", styles["BulletApp"]))
    story.append(Spacer(1, 3))
    buf.clear()


def flush_code(buf: List[str], story: list, styles: StyleSheet1) -> None:
    if not buf:
        return
    story.append(Preformatted("\n".join(buf), styles["CodeApp"]))
    story.append(Spacer(1, 6))
    buf.clear()


def add_diagram(story: list, diagram_path: Path, styles: StyleSheet1, idx: int) -> None:
    if not diagram_path.exists():
        story.append(Paragraph(f"[Missing Mermaid diagram image: {diagram_path.name}]", styles["CodeApp"]))
        story.append(Spacer(1, 6))
        return

    reader = ImageReader(str(diagram_path))
    iw, ih = reader.getSize()
    max_width = 6.2 * inch
    max_height = 4.6 * inch
    scale = min(max_width / iw, max_height / ih, 1.0)

    img = Image(str(diagram_path), width=iw * scale, height=ih * scale)
    img.hAlign = "CENTER"
    story.append(Spacer(1, 2))
    story.append(img)
    story.append(Paragraph(f"Diagram {idx}", styles["Caption"]))


def parse_markdown(md_text: str, styles: StyleSheet1, diagrams_dir: Path, mono_font: str) -> list:
    story: list = []

    in_code = False
    in_mermaid = False
    code_lines: List[str] = []
    para_buf: List[str] = []
    bullet_buf: List[str] = []
    diagram_idx = 0

    lines = md_text.splitlines()

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("```mermaid"):
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            in_code = True
            in_mermaid = True
            code_lines = []
            continue

        if stripped.startswith("```"):
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            if in_code:
                if in_mermaid:
                    diagram_idx += 1
                    add_diagram(story, diagrams_dir / f"diagram_{diagram_idx:02d}.png", styles, diagram_idx)
                else:
                    flush_code(code_lines, story, styles)
                code_lines = []
                in_code = False
                in_mermaid = False
            else:
                in_code = True
                in_mermaid = False
                code_lines = []
            continue

        if in_code:
            code_lines.append(line)
            continue

        if not stripped:
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            story.append(Spacer(1, 2))
            continue

        if stripped == "---":
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            story.append(Spacer(1, 10))
            continue

        if stripped.startswith("# "):
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            story.append(Paragraph(render_inline_markdown(stripped[2:].strip(), mono_font), styles["H1App"]))
            continue

        if stripped.startswith("## "):
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            story.append(Paragraph(render_inline_markdown(stripped[3:].strip(), mono_font), styles["H2App"]))
            continue

        if stripped.startswith("### "):
            flush_paragraph(para_buf, story, styles, mono_font)
            flush_bullets(bullet_buf, story, styles, mono_font)
            story.append(Paragraph(render_inline_markdown(stripped[4:].strip(), mono_font), styles["H3App"]))
            continue

        if stripped.startswith("* ") or stripped.startswith("- "):
            flush_paragraph(para_buf, story, styles, mono_font)
            bullet_buf.append(stripped[2:])
            continue

        if any(stripped.startswith(f"{n}. ") for n in range(1, 10)):
            flush_paragraph(para_buf, story, styles, mono_font)
            bullet_buf.append(stripped)
            continue

        para_buf.append(stripped)

    flush_paragraph(para_buf, story, styles, mono_font)
    flush_bullets(bullet_buf, story, styles, mono_font)
    if code_lines and not in_mermaid:
        flush_code(code_lines, story, styles)

    return story


def draw_header_footer(canvas, doc, source_name: str, fonts: dict[str, str]) -> None:
    canvas.saveState()
    w, h = doc.pagesize

    canvas.setStrokeColor(colors.HexColor("#CBD5E1"))
    canvas.setLineWidth(0.4)
    canvas.line(doc.leftMargin, h - 0.58 * inch, w - doc.rightMargin, h - 0.58 * inch)

    canvas.setFillColor(colors.HexColor("#0F172A"))
    canvas.setFont(fonts["serif_bold"], 9)
    canvas.drawString(doc.leftMargin, h - 0.50 * inch, "Pinball App Architecture Blueprint")

    ts = dt.datetime.now().strftime("%Y-%m-%d")
    canvas.setFont(fonts["serif"], 8)
    canvas.setFillColor(colors.HexColor("#64748B"))
    canvas.drawRightString(w - doc.rightMargin, h - 0.50 * inch, f"Generated {ts}")

    canvas.setStrokeColor(colors.HexColor("#CBD5E1"))
    canvas.line(doc.leftMargin, 0.62 * inch, w - doc.rightMargin, 0.62 * inch)

    canvas.setFont(fonts["serif"], 8)
    footer = f"{source_name}  |  Page {doc.page}"
    canvas.drawRightString(w - doc.rightMargin, 0.46 * inch, footer)

    canvas.restoreState()


def render(markdown_path: Path, output_path: Path, diagrams_dir: Path) -> None:
    fonts = register_fonts()
    styles = build_styles(fonts)
    text = markdown_path.read_text(encoding="utf-8")

    story = [
        Paragraph("Pinball App Architecture Blueprint", styles["TitleApp"]),
        Paragraph(
            "Complete architecture documentation for the current iOS and Android applications, including embedded diagrams and detailed behavior flows.",
            styles["Subtitle"],
        ),
        Spacer(1, 8),
    ]

    story.extend(parse_markdown(text, styles, diagrams_dir, fonts["mono"]))

    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=LETTER,
        leftMargin=0.8 * inch,
        rightMargin=0.8 * inch,
        topMargin=0.86 * inch,
        bottomMargin=0.82 * inch,
        title="Pinball App Architecture Blueprint",
        author="Pinball App",
    )

    doc.build(story, onFirstPage=lambda c, d: draw_header_footer(c, d, markdown_path.name, fonts), onLaterPages=lambda c, d: draw_header_footer(c, d, markdown_path.name, fonts))


def main() -> None:
    parser = argparse.ArgumentParser(description="Render architecture markdown to a polished PDF")
    parser.add_argument("--input", required=True, help="Input markdown file")
    parser.add_argument("--output", required=True, help="Output PDF path")
    parser.add_argument(
        "--diagrams-dir",
        required=True,
        help="Directory containing Mermaid diagram images named diagram_01.png, diagram_02.png, ...",
    )
    args = parser.parse_args()

    render(Path(args.input), Path(args.output), Path(args.diagrams_dir))


if __name__ == "__main__":
    main()
