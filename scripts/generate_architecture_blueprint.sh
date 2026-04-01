#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_PATH="${1:-$ROOT_DIR/Pinball_App_Architecture_Blueprint.md}"
OUTPUT_PATH="${2:-$ROOT_DIR/Pinball_App_Architecture_Blueprint_print_layout.pdf}"
DIAGRAMS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pinball-architecture-diagrams.XXXXXX")"
VENV_DIR="$ROOT_DIR/.venv-architecture-docs"
PYTHON_BIN="$VENV_DIR/bin/python3"

cleanup() {
  rm -rf "$DIAGRAMS_DIR"
}

trap cleanup EXIT

if [ ! -x "$PYTHON_BIN" ]; then
  python3 -m venv "$VENV_DIR"
fi

if ! "$PYTHON_BIN" -c "import reportlab" >/dev/null 2>&1; then
  "$PYTHON_BIN" -m pip install --quiet reportlab
fi

"$PYTHON_BIN" "$ROOT_DIR/scripts/render_mermaid_blocks.py" \
  --input "$INPUT_PATH" \
  --output-dir "$DIAGRAMS_DIR" \
  --config "$ROOT_DIR/scripts/mermaid_print_theme.json"

"$PYTHON_BIN" "$ROOT_DIR/scripts/render_architecture_pdf_upgraded.py" \
  --input "$INPUT_PATH" \
  --output "$OUTPUT_PATH" \
  --diagrams-dir "$DIAGRAMS_DIR"

echo "Generated architecture PDF: $OUTPUT_PATH"
