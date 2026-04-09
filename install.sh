#!/usr/bin/env bash
# orchystraw installer — one-command setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ChetanSarda99/openOrchyStraw/main/install.sh | bash
#   # or
#   git clone https://github.com/ChetanSarda99/openOrchyStraw.git && cd openOrchyStraw && ./install.sh

set -euo pipefail

REPO="https://github.com/ChetanSarda99/openOrchyStraw.git"
INSTALL_DIR="${ORCH_INSTALL_DIR:-$HOME/.orchystraw/app}"
BIN_DIR="${ORCH_BIN_DIR:-$HOME/.local/bin}"

echo "╔══════════════════════════════════════════════════╗"
echo "║  orchystraw installer                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Check requirements ──────────────────────────────────────────────────

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  ✓ $1 $(command -v "$1")"
        return 0
    else
        echo "  ✗ $1 not found"
        return 1
    fi
}

echo "Checking requirements..."
errors=0

# Bash 5+
bash_ver="${BASH_VERSINFO[0]}"
if [[ "$bash_ver" -ge 5 ]]; then
    echo "  ✓ bash $BASH_VERSION"
else
    echo "  ✗ bash $BASH_VERSION (need 5.0+)"
    echo ""
    echo "  Install bash 5:"
    case "$(uname -s)" in
        Darwin) echo "    brew install bash" ;;
        Linux)  echo "    sudo apt-get install -y bash  # or: sudo yum install -y bash" ;;
        *)      echo "    Install bash 5.0+ for your platform" ;;
    esac
    errors=$((errors + 1))
fi

check_cmd git || errors=$((errors + 1))

# Optional but recommended
echo ""
echo "Optional (recommended):"
check_cmd claude || echo "    Install: https://docs.anthropic.com/en/docs/claude-code"
check_cmd gh || echo "    Install: https://cli.github.com"
check_cmd jq || true

if [[ "$errors" -gt 0 ]]; then
    echo ""
    echo "Fix the required items above, then re-run this script."
    exit 1
fi

# ── Clone or update ─────────────────────────────────────────────────────

echo ""
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Updating existing install at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || {
        echo "  Warning: Could not update (local changes?). Continuing with existing version."
    }
else
    echo "Installing to $INSTALL_DIR..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth 1 "$REPO" "$INSTALL_DIR"
fi

# ── Symlink binaries ────────────────────────────────────────────────────

echo ""
echo "Setting up CLI..."
mkdir -p "$BIN_DIR"

for cmd in orchystraw orch-context; do
    if [[ -f "$INSTALL_DIR/bin/$cmd" ]]; then
        chmod +x "$INSTALL_DIR/bin/$cmd"
        ln -sf "$INSTALL_DIR/bin/$cmd" "$BIN_DIR/$cmd"
        echo "  ✓ $cmd → $BIN_DIR/$cmd"
    fi
done

# ── PATH setup ──────────────────────────────────────────────────────────

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo ""
    echo "Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo ""
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo ""

    # Auto-add if user confirms (skip if non-interactive, e.g. piped from curl)
    if [[ -t 0 ]]; then
        read -rp "Add to PATH now? [Y/n] " answer
    else
        answer="Y"
    fi
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^[Yy] ]]; then
        shell_rc=""
        case "$SHELL" in
            */zsh)  shell_rc="$HOME/.zshrc" ;;
            */bash) shell_rc="$HOME/.bashrc" ;;
            *)      shell_rc="$HOME/.profile" ;;
        esac
        echo "" >> "$shell_rc"
        echo "# orchystraw" >> "$shell_rc"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$shell_rc"
        echo "  ✓ Added to $shell_rc (restart shell or: source $shell_rc)"
    fi
fi

# ── Config ──────────────────────────────────────────────────────────────

echo ""
mkdir -p "$HOME/.orchystraw"
if [[ ! -f "$HOME/.orchystraw/config.env" ]]; then
    cp "$INSTALL_DIR/template/orchystraw.env.example" "$HOME/.orchystraw/config.env"
    echo "  ✓ Created ~/.orchystraw/config.env (edit with your API keys)"
else
    echo "  ✓ ~/.orchystraw/config.env already exists"
fi

# ── Done ────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  Installation complete!                          ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Edit ~/.orchystraw/config.env with your API key"
echo "  2. orchystraw doctor              # verify setup"
echo "  3. orchystraw init ~/my-project   # set up a project"
echo "  4. orchystraw run ~/my-project --cycles 1 --dry-run"
echo ""
echo "Docs: https://github.com/ChetanSarda99/openOrchyStraw"
