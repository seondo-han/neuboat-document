#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# avk-docs — Avikus Document CLI
# ---------------------------------------------------------------------------

_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${_SOURCE}" ]]; do
  _DIR="$(cd -P "$(dirname "${_SOURCE}")" && pwd)"
  _SOURCE="$(readlink "${_SOURCE}")"
  [[ "${_SOURCE}" != /* ]] && _SOURCE="${_DIR}/${_SOURCE}"
done
SCRIPT_DIR="$(cd -P "$(dirname "${_SOURCE}")" && pwd)"
unset _SOURCE _DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── help texts ───────────────────────────────────────────────────────────────

help_root() {
  cat << 'EOF'
avk-docs — Avikus Document CLI

USAGE
  avk-docs <command> [subcommand] [options]

COMMANDS
  init  <document-name>         Initialize a new document interactively
  build pdf <document-name> [version]
                                Build PDF from an AsciiDoc document
  build html <document-name>    Build HTML from an AsciiDoc document
  serve html <document-name>    Serve built HTML locally at http://localhost:8000

OPTIONS
  -h, --help                    Show this help message

Run 'avk-docs <command> --help' for more information on a command.
EOF
}

help_init() {
  cat << 'EOF'
avk-docs init — Initialize a new document

USAGE
  avk-docs init [options] <document-name>

ARGUMENTS
  document-name          Name of the new document directory to create (in current directory)
                         If a release date is provided, the directory will be
                         created as "<YYYY-MM-DD> <document-name>".

OPTIONS
  -y                     Skip all interactive prompts; use tag values only
  --doctype TYPE         Document doctype: book (default) | article
  --title-page yes|no    Include title page
  --product-name NAME    Product name / document subtitle (default: -)
  --document-no NO       Document number, e.g. AVK-XXX-XXXXXXX-0001 (default: -)
  --module-name NAME     Module name (default: -)
  --document-type TYPE   Document type string, e.g. Design Document (default: -)
  --project-manager NAME Project manager (required)
  --final-editor NAME    Final editor / main author (required)
  --authors AUTHORS      Other authors, comma-separated
  --document-version VER Document version, e.g. 1.0.0 (default: -)
  --release-date DATE    Release date, YYYY-MM-DD
  --doc-info yes|no      Include inner cover / document information page (default: yes)
  --revision yes|no      Include revision history (default: yes)
  --toc yes|no           Include table of contents (default: yes)
  --figure-list yes|no   Include figure list (default: yes)
  --table-list yes|no    Include table list (default: yes)

DESCRIPTION
  Copies the document template into a new document directory.
  Any option not supplied via a flag will be collected interactively,
  unless -y is given (in which case missing flags use their default values).

  Required fields: --project-manager, --final-editor
  Fields that default to "-" when blank: --product-name, --document-no,
    --document-type, --document-version

EXAMPLES
  # Fully interactive
  avk-docs init my-document

  # Partially tagged (skips prompted fields that are supplied)
  avk-docs init --product-name "MyProduct" --final-editor "Jane" my-document

  # Non-interactive (-y mode)
  avk-docs init -y \\
    --project-manager "John" --final-editor "Jane" \\
    --document-no "AVK-001" my-document
EOF
}

help_build() {
  cat << 'EOF'
avk-docs build — Build a document

USAGE
  avk-docs build <format> [options]

FORMATS
  pdf   <document-name> [version]    Build PDF
  html  <document-name>              Build HTML

Run 'avk-docs build pdf --help' or 'avk-docs build html --help' for details.
EOF
}

help_build_pdf() {
  cat << 'EOF'
avk-docs build pdf — Build PDF

USAGE
  avk-docs build pdf <document-name> [version]

ARGUMENTS
  document-name     Name of the document directory (relative to current directory)
  version           (optional) Version string to append to output filename

OUTPUT
  <document-name>/output/<document-name>.pdf
  <document-name>/output/<document-name>_<version>.pdf  (when version is given)

EXAMPLES
  avk-docs build pdf my-document
  avk-docs build pdf my-document 1.0.0
EOF
}

help_build_html() {
  cat << 'EOF'
avk-docs build html — Build HTML

USAGE
  avk-docs build html <document-name>

ARGUMENTS
  document-name     Name of the document directory (relative to current directory)

OUTPUT
  <document-name>/output/html/index.html

EXAMPLE
  avk-docs build html my-document
EOF
}

help_serve() {
  cat << 'EOF'
avk-docs serve — Serve a built document

USAGE
  avk-docs serve <format> [options]

FORMATS
  html  <document-name>    Serve HTML locally at http://localhost:8000

Run 'avk-docs serve html --help' for details.
EOF
}

help_serve_html() {
  cat << 'EOF'
avk-docs serve html — Serve HTML locally

USAGE
  avk-docs serve html <document-name>

ARGUMENTS
  document-name     Name of the document directory (relative to current directory)

DESCRIPTION
  Starts a local HTTP server at http://localhost:8000 serving the built HTML.
  Run 'avk-docs build html <document-name>' first if output does not exist.

EXAMPLE
  avk-docs serve html my-document
EOF
}

# ── command implementations ──────────────────────────────────────────────────

cmd_init() {
  # Scan for -h/--help anywhere in the arguments
  for _arg in "$@"; do
    case "${_arg}" in -h|--help) help_init; exit 0 ;; esac
  done
  if [[ $# -eq 0 ]]; then
    echo "Error: missing argument <document-name>." >&2; echo; help_init; exit 1
  fi
  bash "${SCRIPT_DIR}/init-doc.sh" "$@"
}

cmd_build_pdf() {
  case "${1:-}" in
    -h|--help) help_build_pdf; exit 0 ;;
    "") echo "Error: missing argument <document-name>." >&2; echo; help_build_pdf; exit 1 ;;
  esac
  bash "${SCRIPT_DIR}/build-pdf.sh" "$@"
}

cmd_build_html() {
  case "${1:-}" in
    -h|--help) help_build_html; exit 0 ;;
    "") echo "Error: missing argument <document-name>." >&2; echo; help_build_html; exit 1 ;;
  esac
  bash "${SCRIPT_DIR}/build-html.sh" "$@"
}

cmd_build() {
  local sub="${1:-}"
  case "${sub}" in
    -h|--help|"") help_build; exit 0 ;;
    pdf)  shift; cmd_build_pdf  "$@" ;;
    html) shift; cmd_build_html "$@" ;;
    *) echo "Error: unknown format '${sub}'. Use 'pdf' or 'html'." >&2; echo; help_build; exit 1 ;;
  esac
}

cmd_serve_html() {
  case "${1:-}" in
    -h|--help) help_serve_html; exit 0 ;;
    "") echo "Error: missing argument <document-name>." >&2; echo; help_serve_html; exit 1 ;;
  esac
  bash "${SCRIPT_DIR}/serve-html.sh" "$@"
}

cmd_serve() {
  local sub="${1:-}"
  case "${sub}" in
    -h|--help|"") help_serve; exit 0 ;;
    html) shift; cmd_serve_html "$@" ;;
    *) echo "Error: unknown format '${sub}'. Use 'html'." >&2; echo; help_serve; exit 1 ;;
  esac
}

# ── entry point ──────────────────────────────────────────────────────────────

CMD="${1:-}"
case "${CMD}" in
  -h|--help|"") help_root; exit 0 ;;
  init)  shift; cmd_init  "$@" ;;
  build) shift; cmd_build "$@" ;;
  serve) shift; cmd_serve "$@" ;;
  *)
    echo "Error: unknown command '${CMD}'." >&2
    echo
    help_root
    exit 1
    ;;
esac
