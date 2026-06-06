#!/usr/bin/env bash
# AutoBuilder Input Parser — convert .txt/.md/.docx/.pdf to plain text

set -euo pipefail

# Parse a file and emit its text content to stdout.
# Supports: .txt, .md, .markdown, .pdf, .docx
parse_input_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        exit 1
    fi

    local ext="${file##*.}"

    case "${ext,,}" in
        pdf)
            _parse_pdf "$file"
            ;;
        docx)
            _parse_docx "$file"
            ;;
        txt|md|markdown)
            cat "$file"
            ;;
        *)
            echo "ERROR: Unsupported file type: .${ext} (supported: .txt .md .pdf .docx)" >&2
            exit 1
            ;;
    esac
}

_parse_pdf() {
    local file="$1"
    if command -v pdftotext &>/dev/null; then
        pdftotext "$file" -
    elif python3 -c "import pypdf" &>/dev/null 2>&1; then
        python3 - "$file" <<'PYEOF'
import sys
import pypdf
reader = pypdf.PdfReader(sys.argv[1])
for page in reader.pages:
    text = page.extract_text()
    if text:
        print(text)
PYEOF
    elif python3 -c "import PyPDF2" &>/dev/null 2>&1; then
        python3 - "$file" <<'PYEOF'
import sys
import PyPDF2
with open(sys.argv[1], 'rb') as f:
    reader = PyPDF2.PdfReader(f)
    for page in reader.pages:
        text = page.extract_text()
        if text:
            print(text)
PYEOF
    else
        echo "ERROR: Cannot parse PDF. Install one of: pdftotext (poppler-utils), pypdf, or PyPDF2" >&2
        echo "  sudo apt install poppler-utils" >&2
        echo "  pip install pypdf" >&2
        exit 1
    fi
}

_parse_docx() {
    local file="$1"
    if ! command -v python3 &>/dev/null; then
        echo "ERROR: python3 is required to parse .docx files" >&2
        exit 1
    fi

    python3 - "$file" <<'PYEOF'
import sys

filepath = sys.argv[1]

# Try docx2txt first (simpler)
try:
    import docx2txt
    text = docx2txt.process(filepath)
    if text:
        print(text)
    sys.exit(0)
except ImportError:
    pass

# Try python-docx
try:
    from docx import Document
    doc = Document(filepath)
    for para in doc.paragraphs:
        if para.text.strip():
            print(para.text)
    # Also extract tables
    for table in doc.tables:
        for row in table.rows:
            cells = [cell.text.strip() for cell in row.cells if cell.text.strip()]
            if cells:
                print(' | '.join(cells))
    sys.exit(0)
except ImportError:
    pass

print("ERROR: Cannot parse .docx. Install python-docx or docx2txt:", file=sys.stderr)
print("  pip install python-docx", file=sys.stderr)
print("  pip install docx2txt", file=sys.stderr)
sys.exit(1)
PYEOF
}

# Detect file type without extension (fallback)
detect_filetype() {
    local file="$1"
    if command -v file &>/dev/null; then
        local mime
        mime=$(file --mime-type -b "$file" 2>/dev/null || true)
        case "$mime" in
            application/pdf)          echo "pdf" ;;
            application/vnd.openxml*) echo "docx" ;;
            text/*)                   echo "txt"  ;;
            *)                        echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Validate that a file extension is supported
validate_input_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file" >&2
        return 1
    fi
    local ext="${file##*.}"
    case "${ext,,}" in
        pdf|docx|txt|md|markdown) return 0 ;;
        *)
            echo "ERROR: Unsupported file type: .${ext}" >&2
            echo "Supported types: .txt .md .markdown .pdf .docx" >&2
            return 1
            ;;
    esac
}
