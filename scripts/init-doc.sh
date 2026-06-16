#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# init-doc: Initialize a new document from the document template
# Usage: init-doc [options] <document-name>
#
# Options:
#   -y                       Skip all interactive prompts; use tag values only
#   --doctype TYPE           Document doctype: book (default) | article
#   --title-page yes|no      Include title page
#   --product-name NAME      Product name (document subtitle; default: -)
#   --document-no NO         Document number (default: -)
#   --module-name NAME       Module name (default: -)
#   --document-type TYPE     Document type string (default: -)
#   --project-manager NAME   Project manager (required)
#   --final-editor NAME      Final editor / main author (required)
#   --authors AUTHORS        Other authors, comma-separated
#   --document-version VER   Document version (default: -)
#   --release-date DATE      Release date (YYYY-MM-DD)
#   --doc-info yes|no        Include inner cover (default: yes)
#   --revision yes|no        Include revision history (default: yes)
#   --toc yes|no             Include table of contents (default: yes)
#   --figure-list yes|no     Include figure list (default: yes)
#   --table-list yes|no      Include table list (default: yes)
# ---------------------------------------------------------------------------

# ── parse options ────────────────────────────────────────────────────────────

YES_MODE=false
FLAG_DOCTYPE=""
FLAG_TITLE_PAGE=""
FLAG_PRODUCT_NAME=""
FLAG_DOCUMENT_NO=""
FLAG_MODULE_NAME=""
FLAG_DOCUMENT_TYPE=""
FLAG_PROJECT_MANAGER=""
FLAG_FINAL_EDITOR=""
FLAG_AUTHORS=""
FLAG_DOCUMENT_VERSION=""
FLAG_RELEASE_DATE=""
FLAG_DOC_INFO=""
FLAG_REVISION=""
FLAG_TOC=""
FLAG_FIGURE_LIST=""
FLAG_TABLE_LIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      cat << 'USAGE'
Usage: init-doc [options] <document-name>

Options:
  -y                       Skip all interactive prompts; use tag values only
  --doctype TYPE           Document doctype: book (default) | article
  --title-page yes|no      Include title page
  --product-name NAME      Product name (document subtitle; default: -)
  --document-no NO         Document number (default: -)
  --module-name NAME       Module name (default: -)
  --document-type TYPE     Document type string (default: -)
  --project-manager NAME   Project manager (required)
  --final-editor NAME      Final editor / main author (required)
  --authors AUTHORS        Other authors, comma-separated
  --document-version VER   Document version (default: -)
  --release-date DATE      Release date (YYYY-MM-DD)
  --doc-info yes|no        Include inner cover (default: yes)
  --revision yes|no        Include revision history (default: yes)
  --toc yes|no             Include table of contents (default: yes)
  --figure-list yes|no     Include figure list (default: yes)
  --table-list yes|no      Include table list (default: yes)
USAGE
      exit 0 ;;
    -y)                 YES_MODE=true;                   shift ;;
    --doctype)          FLAG_DOCTYPE="${2:-}";            shift 2 ;;
    --title-page)       FLAG_TITLE_PAGE="${2:-}";         shift 2 ;;
    --product-name)     FLAG_PRODUCT_NAME="${2:-}";       shift 2 ;;
    --document-no)      FLAG_DOCUMENT_NO="${2:-}";        shift 2 ;;
    --module-name)      FLAG_MODULE_NAME="${2:-}";        shift 2 ;;
    --document-type)    FLAG_DOCUMENT_TYPE="${2:-}";      shift 2 ;;
    --project-manager)  FLAG_PROJECT_MANAGER="${2:-}";    shift 2 ;;
    --final-editor)     FLAG_FINAL_EDITOR="${2:-}";       shift 2 ;;
    --authors)          FLAG_AUTHORS="${2:-}";             shift 2 ;;
    --document-version) FLAG_DOCUMENT_VERSION="${2:-}";   shift 2 ;;
    --release-date)     FLAG_RELEASE_DATE="${2:-}";       shift 2 ;;
    --doc-info)         FLAG_DOC_INFO="${2:-}";            shift 2 ;;
    --revision)         FLAG_REVISION="${2:-}";            shift 2 ;;
    --toc)              FLAG_TOC="${2:-}";                 shift 2 ;;
    --figure-list)      FLAG_FIGURE_LIST="${2:-}";         shift 2 ;;
    --table-list)       FLAG_TABLE_LIST="${2:-}";          shift 2 ;;
    --)                 shift; break ;;
    -*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  cat >&2 << 'USAGE'
Usage: init-doc [options] <document-name>

Options:
  -y                       Skip all interactive prompts; use tag values only
  --doctype TYPE           Document doctype: book (default) | article
  --title-page yes|no      Include title page
  --product-name NAME      Product name (document subtitle; default: -)
  --document-no NO         Document number (default: -)
  --module-name NAME       Module name (default: -)
  --document-type TYPE     Document type string (default: -)
  --project-manager NAME   Project manager (required)
  --final-editor NAME      Final editor / main author (required)
  --authors AUTHORS        Other authors, comma-separated
  --document-version VER   Document version (default: -)
  --release-date DATE      Release date (YYYY-MM-DD)
  --doc-info yes|no        Include inner cover (default: yes)
  --revision yes|no        Include revision history (default: yes)
  --toc yes|no             Include table of contents (default: yes)
  --figure-list yes|no     Include figure list (default: yes)
  --table-list yes|no      Include table list (default: yes)
USAGE
  exit 1
fi

RAW_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXAMPLE_DIR="${PROJECT_ROOT}/document"

# ── helpers ──────────────────────────────────────────────────────────────────

ask_yn() {
  local prompt="$1" default="${2:-y}" ans
  while true; do
    if [[ "${default}" == "y" ]]; then
      read -r -p "${prompt} [Y/n]: " ans
    else
      read -r -p "${prompt} [y/N]: " ans
    fi
    ans="${ans:-${default}}"
    ans="$(echo "${ans}" | tr '[:upper:]' '[:lower:]')"
    case "${ans}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) echo "  Please enter y or n." ;;
    esac
  done
}

ask_value() {
  local prompt="$1" val=""
  read -r -p "${prompt}: " val || true
  echo "${val}"
}

attr_or_comment() {
  local key="$1" val="$2"
  if [[ -n "${val}" ]]; then
    echo "${key}: ${val}"
  else
    echo "// ${key}:"
  fi
}

# Returns "true", "false", or "" (invalid) for a yes/no flag value
parse_yn_flag() {
  local val
  val="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "${val}" in
    yes|y|true|1)  echo "true"  ;;
    no|n|false|0)  echo "false" ;;
    *)             echo ""      ;;
  esac
}

# ── collect all inputs ───────────────────────────────────────────────────────

if ! "${YES_MODE}"; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Document Setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# ── doctype ──────────────────────────────────────────────────────────────────

if [[ -n "${FLAG_DOCTYPE}" ]]; then
  case "${FLAG_DOCTYPE}" in
    book|article) DOCTYPE="${FLAG_DOCTYPE}" ;;
    *) echo "Error: --doctype must be 'book' or 'article'." >&2; exit 1 ;;
  esac
elif "${YES_MODE}"; then
  DOCTYPE="book"
else
  echo "Select document type:"
  echo "  1) book    — formal document with chapter numbering [default]"
  echo "  2) article — simple letter or notes"
  echo ""
  DOCTYPE="book"
  while true; do
    read -r -p "Choose [1/2]: " dt_choice
    dt_choice="${dt_choice:-1}"
    case "${dt_choice}" in
      1) DOCTYPE="book";    break ;;
      2) DOCTYPE="article"; break ;;
      *) echo "  Please enter 1 or 2." ;;
    esac
  done
fi

# ── title page ───────────────────────────────────────────────────────────────

TITLE_PAGE_ATTR=""
if [[ -n "${FLAG_TITLE_PAGE}" ]]; then
  _tp="$(parse_yn_flag "${FLAG_TITLE_PAGE}")"
  if [[ -z "${_tp}" ]]; then
    echo "Error: --title-page must be 'yes' or 'no'." >&2; exit 1
  fi
  if [[ "${_tp}" == "true" && "${DOCTYPE}" == "article" ]]; then
    TITLE_PAGE_ATTR=":title-page:"
  elif [[ "${_tp}" == "false" && "${DOCTYPE}" == "book" ]]; then
    TITLE_PAGE_ATTR=":notitle:"
  fi
elif ! "${YES_MODE}"; then
  echo ""
  if [[ "${DOCTYPE}" == "book" ]]; then
    if ! ask_yn "Include title page (cover)?" "y"; then
      TITLE_PAGE_ATTR=":notitle:"
    fi
  else
    if ask_yn "Include title page (cover)?" "n"; then
      TITLE_PAGE_ATTR=":title-page:"
    fi
  fi
fi

# ── metadata ─────────────────────────────────────────────────────────────────

if ! "${YES_MODE}"; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Metadata  (press Enter to leave blank)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

META_DOCUMENT_TITLE="${RAW_NAME}"

if [[ -n "${FLAG_PRODUCT_NAME}" ]]; then
  META_PRODUCT_NAME="${FLAG_PRODUCT_NAME}"
elif "${YES_MODE}"; then
  META_PRODUCT_NAME=""
else
  META_PRODUCT_NAME=$(ask_value "Product name         (document subtitle, blank = -)")
fi

if [[ -n "${FLAG_DOCUMENT_NO}" ]]; then
  META_DOCUMENT_NUMBER="${FLAG_DOCUMENT_NO}"
elif "${YES_MODE}"; then
  META_DOCUMENT_NUMBER=""
else
  META_DOCUMENT_NUMBER=$(ask_value "Document number      (e.g. AVK-XXX-XXXXXXX-0001, blank = -)")
fi

if [[ -n "${FLAG_MODULE_NAME}" ]]; then
  META_MODULE_NAME="${FLAG_MODULE_NAME}"
elif "${YES_MODE}"; then
  META_MODULE_NAME=""
else
  META_MODULE_NAME=$(ask_value "Module name          (blank = -)")
fi
META_MODULE_NAME="${META_MODULE_NAME:-"-"}"

if [[ -n "${FLAG_DOCUMENT_TYPE}" ]]; then
  META_DOCUMENT_TYPE="${FLAG_DOCUMENT_TYPE}"
elif "${YES_MODE}"; then
  META_DOCUMENT_TYPE=""
else
  META_DOCUMENT_TYPE=$(ask_value "Document type        (e.g. Design Document, blank = -)")
fi

if [[ -n "${FLAG_PROJECT_MANAGER}" ]]; then
  META_PROJECT_MANAGER="${FLAG_PROJECT_MANAGER}"
elif "${YES_MODE}"; then
  META_PROJECT_MANAGER=""
else
  META_PROJECT_MANAGER=$(ask_value "Project manager      (required)")
fi

if [[ -n "${FLAG_FINAL_EDITOR}" ]]; then
  META_FINAL_EDITOR="${FLAG_FINAL_EDITOR}"
elif "${YES_MODE}"; then
  META_FINAL_EDITOR=""
else
  META_FINAL_EDITOR=$(ask_value "Final editor / main author (required)")
fi

if [[ -n "${FLAG_AUTHORS}" ]]; then
  META_AUTHORS="${FLAG_AUTHORS}"
elif "${YES_MODE}"; then
  META_AUTHORS=""
else
  META_AUTHORS=$(ask_value "Other authors        (comma-separated, or blank)")
fi

if [[ -n "${FLAG_DOCUMENT_VERSION}" ]]; then
  META_VERSION="${FLAG_DOCUMENT_VERSION}"
elif "${YES_MODE}"; then
  META_VERSION=""
else
  META_VERSION=$(ask_value "Document version     (e.g. 1.0.0, blank = -)")
fi

if [[ -n "${FLAG_RELEASE_DATE}" ]]; then
  META_DATE="${FLAG_RELEASE_DATE}"
elif "${YES_MODE}"; then
  META_DATE=""
else
  META_DATE=$(ask_value "Release date         (YYYY-MM-DD, blank = omit)")
fi

# ── optional sections ────────────────────────────────────────────────────────

# Parse boolean flags upfront; interactive prompts fill any remaining blanks
INCLUDE_DOC_INFO=""
INCLUDE_REVISION=""
INCLUDE_TOC=""
INCLUDE_FIGURE_LIST=""
INCLUDE_TABLE_LIST=""

_parse_section_flag() {
  local flag_name="$1" flag_val="$2"
  local _v
  _v="$(parse_yn_flag "${flag_val}")"
  if [[ -z "${_v}" ]]; then
    echo "Error: ${flag_name} must be 'yes' or 'no'." >&2; exit 1
  fi
  echo "${_v}"
}

[[ -n "${FLAG_DOC_INFO}"    ]] && INCLUDE_DOC_INFO="$(_parse_section_flag    "--doc-info"    "${FLAG_DOC_INFO}")"
[[ -n "${FLAG_REVISION}"    ]] && INCLUDE_REVISION="$(_parse_section_flag    "--revision"    "${FLAG_REVISION}")"
[[ -n "${FLAG_TOC}"         ]] && INCLUDE_TOC="$(_parse_section_flag         "--toc"         "${FLAG_TOC}")"
[[ -n "${FLAG_FIGURE_LIST}" ]] && INCLUDE_FIGURE_LIST="$(_parse_section_flag "--figure-list" "${FLAG_FIGURE_LIST}")"
[[ -n "${FLAG_TABLE_LIST}"  ]] && INCLUDE_TABLE_LIST="$(_parse_section_flag  "--table-list"  "${FLAG_TABLE_LIST}")"

if "${YES_MODE}"; then
  INCLUDE_DOC_INFO="${INCLUDE_DOC_INFO:-true}"
  INCLUDE_REVISION="${INCLUDE_REVISION:-true}"
  INCLUDE_TOC="${INCLUDE_TOC:-true}"
  INCLUDE_FIGURE_LIST="${INCLUDE_FIGURE_LIST:-true}"
  INCLUDE_TABLE_LIST="${INCLUDE_TABLE_LIST:-true}"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Optional Sections"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [[ -z "${INCLUDE_DOC_INFO}" ]]; then
    ask_yn "Include inner cover (document information page)?" "y" \
      && INCLUDE_DOC_INFO=true || INCLUDE_DOC_INFO=false
  fi
  if [[ -z "${INCLUDE_REVISION}" ]]; then
    ask_yn "Include revision history?" "y" \
      && INCLUDE_REVISION=true || INCLUDE_REVISION=false
  fi
  if [[ -z "${INCLUDE_TOC}" ]]; then
    ask_yn "Include table of contents?" "y" \
      && INCLUDE_TOC=true || INCLUDE_TOC=false
  fi

  if [[ -z "${INCLUDE_FIGURE_LIST}" && -z "${INCLUDE_TABLE_LIST}" ]]; then
    if ask_yn "Include figure and table lists?" "y"; then
      INCLUDE_FIGURE_LIST=true
      INCLUDE_TABLE_LIST=true
    else
      INCLUDE_FIGURE_LIST=false
      INCLUDE_TABLE_LIST=false
    fi
  elif [[ -z "${INCLUDE_FIGURE_LIST}" ]]; then
    ask_yn "Include figure list?" "y" \
      && INCLUDE_FIGURE_LIST=true || INCLUDE_FIGURE_LIST=false
  elif [[ -z "${INCLUDE_TABLE_LIST}" ]]; then
    ask_yn "Include table list?" "y" \
      && INCLUDE_TABLE_LIST=true || INCLUDE_TABLE_LIST=false
  fi
fi

# ── apply defaults for optional fields ───────────────────────────────────────

META_PRODUCT_NAME="${META_PRODUCT_NAME:-"-"}"
META_DOCUMENT_NUMBER="${META_DOCUMENT_NUMBER:-"-"}"
META_DOCUMENT_TYPE="${META_DOCUMENT_TYPE:-"-"}"
META_VERSION="${META_VERSION:-"-"}"

# ── validate required fields ──────────────────────────────────────────────────

if [[ -z "${META_PROJECT_MANAGER}" ]]; then
  echo "" >&2
  echo "Error: 'project-manager' is required." >&2
  echo "       Provide it with --project-manager NAME or enter it when prompted." >&2
  exit 1
fi

if [[ -z "${META_FINAL_EDITOR}" ]]; then
  echo "" >&2
  echo "Error: 'final-editor' is required." >&2
  echo "       Provide it with --final-editor NAME or enter it when prompted." >&2
  exit 1
fi

# ── determine directory name (use release date as prefix if given) ────────────

if [[ -n "${META_DATE}" ]]; then
  DOCUMENT_NAME="${META_DATE} ${RAW_NAME}"
else
  DOCUMENT_NAME="${RAW_NAME}"
fi
DEST="$(pwd)/${DOCUMENT_NAME}"

if [[ -d "${DEST}" ]]; then
  echo "Error: Directory '${DEST}' already exists."
  exit 1
fi

# ── copy template ────────────────────────────────────────────────────────────

echo ""
echo "Initializing document '${DOCUMENT_NAME}'..."
mkdir -p "${DEST}"
rsync -a \
  --exclude='.DS_Store' \
  --exclude='output/' \
  --exclude='generated-images/' \
  "${EXAMPLE_DIR}/" "${DEST}/"
mkdir -p "${DEST}/output" "${DEST}/generated-images"

# ── write metadata.adoc ──────────────────────────────────────────────────────

cat > "${DEST}/metadata.adoc" << EOF
// 제품 이름 (문서 소제목으로 들어감.)
$(attr_or_comment ":product-name" "${META_PRODUCT_NAME}")

// 문서 이름 (문서 제목으로 들어감.)
$(attr_or_comment ":document-title" "${META_DOCUMENT_TITLE}")

// 문서 번호
$(attr_or_comment ":document-number" "${META_DOCUMENT_NUMBER}")

// 모듈 이름. 없으면 - (hyphen)
:module-name: ${META_MODULE_NAME}

// 문서 타입: Concept document, Test report, Design document 등
$(attr_or_comment ":document-type" "${META_DOCUMENT_TYPE}")

// 프로젝트 관리자
$(attr_or_comment ":project-manager" "${META_PROJECT_MANAGER}")

// 문서 주 편집자 혹은 주 저자
$(attr_or_comment ":final-editor" "${META_FINAL_EDITOR}")

// 문서 저자. final editor 제외하고 작성. 별도로 없어도 주석 처리하지 말 것.
:authors: ${META_AUTHORS}

// 문서 버전. 버전이 없으면 - (hyphen)
:document-version: ${META_VERSION}
:revnumber: {document-version}

// 문서 일자. 따로 문서 일자가 없는 경우, 모두 주석 처리 할 것.
EOF

if [[ -n "${META_DATE}" ]]; then
  cat >> "${DEST}/metadata.adoc" << EOF
:release-date: ${META_DATE}
:revdate: {release-date}
EOF
else
  cat >> "${DEST}/metadata.adoc" << 'EOF'
// :release-date:
// :revdate: {release-date}
EOF
fi

# ── write document.adoc ──────────────────────────────────────────────────────

{
  echo "include::metadata.adoc[]"
  echo "include::_document_settings.adoc[]"
  echo ""
  echo ""
  echo ":doctype: ${DOCTYPE}"
  if [[ -n "${TITLE_PAGE_ATTR}" ]]; then
    echo "${TITLE_PAGE_ATTR}"
  fi
  echo ""
  echo "= {document-title}: {product-name}"
  echo ""
  echo ""

  if "${INCLUDE_DOC_INFO}"; then
    echo "// Document information (속표지)"
    echo "include::../template/pages/document_information.adoc[]"
  else
    echo "// Document information (속표지)"
    echo "// include::../template/pages/document_information.adoc[]"
  fi
  echo ""

  if "${INCLUDE_REVISION}"; then
    echo "// Revision history"
    echo "include::revision_history.adoc[]"
  else
    echo "// Revision history"
    echo "// include::revision_history.adoc[]"
  fi
  echo ""

  if "${INCLUDE_TOC}"; then
    echo "// Table of contents"
    echo "toc::[]"
  else
    echo "// Table of contents"
    echo "// toc::[]"
  fi
  echo ""

  if "${INCLUDE_FIGURE_LIST}"; then
    echo "// Figure list"
    echo "include::../template/pages/figure_list.adoc[]"
  else
    echo "// Figure list"
    echo "// include::../template/pages/figure_list.adoc[]"
  fi
  echo ""

  if "${INCLUDE_TABLE_LIST}"; then
    echo "// Table list"
    echo "include::../template/pages/table_list.adoc[]"
  else
    echo "// Table list"
    echo "// include::../template/pages/table_list.adoc[]"
  fi

  echo ""
  echo ""
  echo ""
  echo "== Chapter 1"
  echo ""
} > "${DEST}/document.adoc"

# ── cleanup ──────────────────────────────────────────────────────────────────

if ! "${INCLUDE_REVISION}"; then
  rm -f "${DEST}/revision_history.adoc"
fi

# ── done ─────────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done! Document initialized."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Location : ${DEST}"
  echo "  Build PDF: avk-docs build pdf \"${DOCUMENT_NAME}\""
echo ""
