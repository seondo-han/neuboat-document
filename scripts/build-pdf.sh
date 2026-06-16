#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: build-pdf <document-name|directory-path> [version]"
  exit 1
fi

INPUT="$1"
VERSION="${2:-}"

# Resolve absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── resolve DOCUMENT_DIR and DOCUMENT_NAME ───────────────────────────────────

# 1. Try input as a path (relative or absolute)
CANDIDATE=""
if [[ "${INPUT}" = /* ]]; then
  CANDIDATE="${INPUT}"
else
  CANDIDATE="$(pwd)/${INPUT}"
fi

if [[ -d "${CANDIDATE}" ]]; then
  DOCUMENT_DIR="$(cd "${CANDIDATE}" && pwd)"
  DIR_BASENAME="$(basename "${DOCUMENT_DIR}")"
  # 1.1 / 1.2: strip leading "yyyy-mm-dd " prefix if present
  if [[ "${DIR_BASENAME}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]](.+)$ ]]; then
    DOCUMENT_NAME="${BASH_REMATCH[1]}"
  else
    DOCUMENT_NAME="${DIR_BASENAME}"
  fi
else
  # 2. Search current directory for "yyyy-mm-dd {INPUT}"
  FOUND=""
  while IFS= read -r -d '' entry; do
    BASENAME="$(basename "${entry}")"
    if [[ "${BASENAME}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]](.+)$ ]]; then
      if [[ "${BASH_REMATCH[1]}" == "${INPUT}" ]]; then
        FOUND="${entry}"
        break
      fi
    fi
  done < <(find "$(pwd)" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

  if [[ -n "${FOUND}" ]]; then
    DOCUMENT_DIR="$(cd "${FOUND}" && pwd)"
    DOCUMENT_NAME="${INPUT}"
  else
    echo "Error: cannot find document directory for '${INPUT}'." >&2
    echo "  Tried path  : ${CANDIDATE}" >&2
    echo "  Tried search: <date> ${INPUT} in $(pwd)" >&2
    exit 1
  fi
fi

# Set output filename
if [[ -n "${VERSION}" ]]; then
  OUTPUT_FILE="${DOCUMENT_NAME}_${VERSION}"
else
  OUTPUT_FILE="${DOCUMENT_NAME}"
fi

# Ensure output directory exists
mkdir -p "${DOCUMENT_DIR}/output"

docker run --rm \
  -v "${DOCUMENT_DIR}:/documents" \
  -v "${DOCUMENT_DIR}/output:/documents/output" \
  -w /documents \
  -e "OUTPUT_FILE=${OUTPUT_FILE}" \
  neuboat-asciidoctor \
  /bin/sh -c '
    echo "Generating PDF..." &&
    asciidoctor-pdf --version &&
    asciidoctor-pdf \
      -a pdf-fontsdir=/template/fonts \
      -a pdf-themesdir=/template/theme \
      -r asciidoctor-diagram \
      -r asciidoctor-mathematical \
      -r asciidoctor-lists \
      -o "/documents/output/${OUTPUT_FILE}.pdf" \
      document.adoc &&
    echo "PDF generation completed: ./output/${OUTPUT_FILE}.pdf"
  '
