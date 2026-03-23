#!/usr/bin/env python3
"""Render Mermaid blocks from a Markdown file into sequential PNG assets."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


MERMAID_FENCE = re.compile(r"```mermaid\s*\n(.*?)\n```", re.DOTALL)


def extract_blocks(markdown_text: str) -> list[str]:
    return [match.group(1).strip() + "\n" for match in MERMAID_FENCE.finditer(markdown_text)]


def render_block(block: str, output_dir: Path, index: int, config_file: Path | None) -> None:
    source_path = output_dir / f"diagram_{index:02d}.mmd"
    image_path = output_dir / f"diagram_{index:02d}.png"
    source_path.write_text(block, encoding="utf-8")

    command = [
        "npx",
        "-y",
        "@mermaid-js/mermaid-cli",
        "-i",
        str(source_path),
        "-o",
        str(image_path),
        "-b",
        "transparent",
    ]
    if config_file is not None:
        command.extend(["-c", str(config_file)])

    subprocess.run(command, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Mermaid blocks from a Markdown file")
    parser.add_argument("--input", required=True, help="Input Markdown file")
    parser.add_argument("--output-dir", required=True, help="Directory for rendered Mermaid assets")
    parser.add_argument(
        "--config",
        help="Optional Mermaid config JSON",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    blocks = extract_blocks(input_path.read_text(encoding="utf-8"))
    for index, block in enumerate(blocks, start=1):
        render_block(
            block=block,
            output_dir=output_dir,
            index=index,
            config_file=Path(args.config) if args.config else None,
        )


if __name__ == "__main__":
    main()
