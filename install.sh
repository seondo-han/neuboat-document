#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# avikus-document-template installer
# Usage:
#   sudo ./install.sh            # install
#   sudo ./install.sh uninstall  # uninstall
# ---------------------------------------------------------------------------

PREFIX="${PREFIX:-/usr/local}"
SHARE_DIR="${PREFIX}/share/document-tools"
BIN_DIR="${PREFIX}/bin"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ─────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

check_deps() {
  local missing=()
  command -v docker   &>/dev/null || missing+=("docker")
  command -v python3  &>/dev/null || missing+=("python3")
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing dependencies: ${missing[*]}"
  fi
  if ! docker compose version &>/dev/null; then
    error "docker compose plugin is required (docker compose v2)"
  fi
}

# ── docker group setup ───────────────────────────────────────────────────────
setup_docker_group() {
  local REAL_USER="${SUDO_USER:-${USER}}"

  # Create docker group if it doesn't exist
  if ! getent group docker &>/dev/null; then
    info "Creating docker group..."
    groupadd docker
  fi

  # Add the invoking user to the docker group
  if ! id -nG "${REAL_USER}" | grep -qw docker; then
    info "Adding ${REAL_USER} to docker group..."
    usermod -aG docker "${REAL_USER}"
  else
    info "${REAL_USER} is already in docker group."
  fi

  # Fix socket ownership so the group can connect
  if [[ -S /var/run/docker.sock ]]; then
    chown root:docker /var/run/docker.sock
    chmod 660 /var/run/docker.sock
    info "Fixed /var/run/docker.sock permissions."
  fi

  # Persist socket fix across Docker Desktop restarts via .bashrc
  local BASHRC="/home/${REAL_USER}/.bashrc"
  local MARKER="# docker-socket-fix"
  if [[ -f "${BASHRC}" ]] && ! grep -q "${MARKER}" "${BASHRC}"; then
    cat >> "${BASHRC}" << 'EOF'

# docker-socket-fix (added by install.sh)
if [ -S /var/run/docker.sock ]; then
  SOCK_GROUP=$(stat -c '%G' /var/run/docker.sock 2>/dev/null || true)
  if [ "${SOCK_GROUP}" = "root" ] || [ "${SOCK_GROUP}" = "UNKNOWN" ]; then
    sudo chown root:docker /var/run/docker.sock 2>/dev/null || true
  fi
fi
EOF
    info "Added docker socket fix to ${BASHRC}."
  fi
}

# ── uninstall ────────────────────────────────────────────────────────────────
uninstall() {
  info "Uninstalling avikus-document-template..."
  rm -f  "${BIN_DIR}/avk-docs"
  rm -rf "${SHARE_DIR}"
  success "Uninstalled."
}

# ── install ──────────────────────────────────────────────────────────────────
do_install() {
  [[ "$(id -u)" -eq 0 ]] || error "Run with sudo: sudo ./install.sh"

  info "Checking dependencies..."
  check_deps

  info "Installing files to ${SHARE_DIR}..."
  install -d "${SHARE_DIR}/scripts"
  install -d "${SHARE_DIR}/template"
  install -d "${SHARE_DIR}/document"

  # Core files needed by docker compose
  install -m 644 "${SOURCE_DIR}/docker-compose.yml" "${SHARE_DIR}/docker-compose.yml"
  install -m 644 "${SOURCE_DIR}/Dockerfile"         "${SHARE_DIR}/Dockerfile"

  # Scripts
  install -m 755 "${SOURCE_DIR}/scripts/avk-docs.sh"   "${SHARE_DIR}/scripts/avk-docs.sh"
  install -m 755 "${SOURCE_DIR}/scripts/build-pdf.sh"  "${SHARE_DIR}/scripts/build-pdf.sh"
  install -m 755 "${SOURCE_DIR}/scripts/build-html.sh" "${SHARE_DIR}/scripts/build-html.sh"
  install -m 755 "${SOURCE_DIR}/scripts/serve-html.sh" "${SHARE_DIR}/scripts/serve-html.sh"
  install -m 755 "${SOURCE_DIR}/scripts/init-doc.sh"   "${SHARE_DIR}/scripts/init-doc.sh"

  # Template (fonts, theme, pages) and document
  cp -r "${SOURCE_DIR}/template/."   "${SHARE_DIR}/template/"
  cp -r "${SOURCE_DIR}/document/."   "${SHARE_DIR}/document/"

  # Symlink: single avk-docs entry point
  info "Creating symlink in ${BIN_DIR}..."
  ln -sf "${SHARE_DIR}/scripts/avk-docs.sh" "${BIN_DIR}/avk-docs"

  # Build Docker image from the source directory.
  # WSL2 + Docker Desktop BuildKit cannot access system paths like /usr/local/share/...
  # directly as a build context, so we build from SOURCE_DIR (the git repo) which is
  # always accessible. The Dockerfile only needs template/ which lives in SOURCE_DIR.
  info "Building Docker image (neuboat-asciidoctor)..."
  docker build -t neuboat-asciidoctor "${SOURCE_DIR}"

  info "Configuring Docker permissions..."
  setup_docker_group

  echo ""
  success "Installation complete."
  echo ""
  echo "  Commands available:"
  echo "    avk-docs init  <document-name>"
  echo "    avk-docs build pdf  <document-name> [version]"
  echo "    avk-docs build html <document-name>"
  echo "    avk-docs serve html <document-name>"
  echo ""
  echo "  Run 'avk-docs --help' for full usage."
  echo ""
  echo "  IMPORTANT: Open a new terminal (or run 'newgrp docker') to apply"
  echo "             the docker group membership before using avk-docs."
  echo ""
  echo "  To uninstall: sudo ./install.sh uninstall"
}

# ── entry point ──────────────────────────────────────────────────────────────
case "${1:-install}" in
  uninstall) uninstall   ;;
  install)   do_install  ;;
  *) error "Unknown command: $1. Use 'install' or 'uninstall'." ;;
esac
