#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
BINARY="xscp"

info() { echo -e "${CYAN}::${NC} $*"; }
ok() { echo -e "${GREEN}::${NC} $*"; }
warn() { echo -e "${YELLOW}::${NC} $*"; }

# Ensure install dir exists
mkdir -p "$INSTALL_DIR"

# Link
TARGET="${INSTALL_DIR}/${BINARY}"
if [[ -L "$TARGET" ]]; then
    existing=$(readlink -f "$TARGET")
    if [[ "$existing" == "${SCRIPT_DIR}/${BINARY}" ]]; then
        ok "Already linked: ${TARGET} -> ${SCRIPT_DIR}/${BINARY}"
    else
        warn "Existing symlink points to ${existing}, updating..."
        ln -sf "${SCRIPT_DIR}/${BINARY}" "$TARGET"
        ok "Updated: ${TARGET} -> ${SCRIPT_DIR}/${BINARY}"
    fi
elif [[ -e "$TARGET" ]]; then
    warn "${TARGET} exists and is not a symlink, skipping (remove it manually first)"
    exit 1
else
    ln -s "${SCRIPT_DIR}/${BINARY}" "$TARGET"
    ok "Linked: ${TARGET} -> ${SCRIPT_DIR}/${BINARY}"
fi

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    warn "${INSTALL_DIR} is not in your PATH"
    echo "  Add to your shell rc:"
    echo "    export PATH=\"\${HOME}/.local/bin:\${PATH}\""
fi

# Check dependencies
info "Checking dependencies..."
for cmd in scp fzf; do
    if command -v "$cmd" &>/dev/null; then
        ok "${cmd} found"
    else
        warn "${cmd} NOT FOUND (required)"
    fi
done
for cmd in nnn sshfs; do
    if command -v "$cmd" &>/dev/null; then
        ok "${cmd} found"
    else
        warn "${cmd} not found (optional - install for better experience)"
    fi
done

echo ""
ok "xscp installed. Run 'xscp' or 'xscp --help' to get started."
