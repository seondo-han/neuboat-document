#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: serve-html <document-name|directory-path>"
  exit 1
fi

INPUT="$1"

# ── resolve DOCUMENT_DIR ─────────────────────────────────────────────────────

if [[ "${INPUT}" = /* ]]; then
  CANDIDATE="${INPUT}"
else
  CANDIDATE="$(pwd)/${INPUT}"
fi

if [[ -d "${CANDIDATE}" ]]; then
  DOCUMENT_DIR="$(cd "${CANDIDATE}" && pwd)"
else
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
  else
    echo "Error: cannot find document directory for '${INPUT}'." >&2
    echo "  Tried path  : ${CANDIDATE}" >&2
    echo "  Tried search: <date> ${INPUT} in $(pwd)" >&2
    exit 1
  fi
fi

HTML_DIR="${DOCUMENT_DIR}/output/html"

if [[ ! -d "${HTML_DIR}" ]]; then
  echo "Error: HTML output not found at ${HTML_DIR}"
  echo "Run 'avk-docs build html \"${INPUT}\"' first."
  exit 1
fi

echo "Serving HTML from ${HTML_DIR} at http://localhost:8000"
cd "${HTML_DIR}"
python3 -m http.server 8000
