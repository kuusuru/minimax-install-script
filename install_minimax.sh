#!/bin/bash
#
# MiniMax Claude Code Installer (Coding Plan Edition)
# Adapted from:
#   - https://platform.minimax.io/docs/guides/text-ai-coding-tools
#   - Original script from Z.ai
#
# Prerequisites:
#   - Linux or macOS
#   - Node.js 18+ (will be installed if missing)
#   - MiniMax Coding Plan API Key
#

set -euo pipefail

# ========================
#        Define Constants
# ========================
SCRIPT_NAME=$(basename "$0")
NODE_MIN_VERSION=18
NODE_INSTALL_VERSION=22
NVM_VERSION="v0.40.3"
CLAUDE_PACKAGE="@anthropic-ai/claude-code"
CONFIG_DIR="$HOME/.claude"

# MiniMax Constants
API_BASE_URL="https://api.minimax.io/anthropic"
API_TIMEOUT_MS=3000000
MINIMAX_MODEL="MiniMax-M2.1"

# API Key URLs
CODING_PLAN_URL="https://platform.minimax.io/user-center/payment/coding-plan"
PLATFORM_URL="https://platform.minimax.io/user-center/basic-information/interface-key"

# ========================
#        Functions
# ========================

log_info() {
    echo "🔹 $*"
}

log_success() {
    echo "✅ $*"
}

log_error() {
    echo "❌ $*" >&2
}

ensure_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            exit 1
        }
    fi
}

# ========================
#      Node.js Installation
# ========================

install_nodejs() {
    local platform=$(uname -s)

    case "$platform" in
        Linux|Darwin)
            log_info "Installing Node.js via NVM..."

            # Install nvm
            curl -s https://raw.githubusercontent.com/nvm-sh/nvm/"$NVM_VERSION"/install.sh | bash

            # Load nvm into current session
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

            # Install and use Node
            nvm install "$NODE_INSTALL_VERSION"
            nvm use "$NODE_INSTALL_VERSION"
            nvm alias default "$NODE_INSTALL_VERSION"

            log_success "Node.js $(node -v) is ready."
            ;;
        *)
            log_error "Unsupported platform: $platform"
            exit 1
            ;;
    esac

    # Add NVM to shell profile for future sessions
    add_nvm_to_shell_profile
}

add_nvm_to_shell_profile() {
    local nvm_export='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    # Detect shell config file
    local shell_config=""
    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bashrc"
    fi

    # Check if already added
    if grep -q "NVM_DIR=\"\$HOME/.nvm\"" "$shell_config" 2>/dev/null; then
        log_info "NVM already configured in $shell_config"
        return 0
    fi

    log_info "Adding NVM to $shell_config..."

    # Append NVM configuration
    {
        echo ""
        echo "# NVM (added by minimax-install-script)"
        echo "$nvm_export"
    } >> "$shell_config"

    log_success "NVM added to $shell_config"
    log_info "Restart your terminal or run: source $shell_config"
}

check_nodejs() {
    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if command -v node &>/dev/null; then
        current_version=$(node -v | sed 's/v//')
        major_version=$(echo "$current_version" | cut -d. -f1)

        if [ "$major_version" -ge "$NODE_MIN_VERSION" ]; then
            log_success "Node.js v$current_version detected."
            return 0
        fi
    fi
    log_info "Node.js missing or outdated. Installing..."
    install_nodejs
}

# ========================
#      Claude Code Installation
# ========================

check_claude_code() {
    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if command -v claude &>/dev/null; then
        log_success "Claude Code is already installed."
        return 0
    fi
    return 1
}

install_claude_code() {
    # Fix the "No such file or directory" bash cache error
    hash -r

    log_info "Installing Claude Code..."
    npm install -g "$CLAUDE_PACKAGE" || {
        log_error "NPM installation failed."
        exit 1
    }
}

configure_claude_json(){
  # Sets onboarding as complete so it doesn't prompt for auth
  node --eval '
      const os = require("os");
      const fs = require("fs");
      const path = require("path");
      const filePath = path.join(os.homedir(), ".claude.json");
      const data = fs.existsSync(filePath) ? JSON.parse(fs.readFileSync(filePath, "utf-8")) : {};
      fs.writeFileSync(filePath, JSON.stringify({ ...data, hasCompletedOnboarding: true }, null, 2));'
}

# ========================
#      API Configuration
# ========================

select_key_type() {
    echo "Select your MiniMax billing type:"
    echo "  1) Coding Plan (fixed monthly fee, includes usage)"
    echo "  2) Pay-As-You-Go (pay per usage)"
    echo ""
    read -p "Enter choice (1 or 2): " choice
    echo ""

    case "$choice" in
        1)
            echo " Get your Coding Plan API Key at: $CODING_PLAN_URL"
            return 0
            ;;
        2)
            echo " Get your Platform API Key at: $PLATFORM_URL"
            return 1
            ;;
        *)
            log_error "Invalid choice. Please enter 1 or 2."
            select_key_type
            ;;
    esac
}

configure_claude() {
    log_info "Configuring Claude Code for MiniMax (Coding Plan Edition)..."
    echo ""

    select_key_type
    read -s -p " Paste your MiniMax API Key: " api_key
    echo

    if [ -z "$api_key" ]; then
        log_error "API key is required."
        exit 1
    fi

    ensure_dir_exists "$CONFIG_DIR"

    # Write settings.json with MiniMax Model Mapping
    node --eval '
        const os = require("os");
        const fs = require("fs");
        const path = require("path");

        const filePath = path.join(os.homedir(), ".claude", "settings.json");
        const config = {
            env: {
                ANTHROPIC_AUTH_TOKEN: "'"$api_key"'",
                ANTHROPIC_BASE_URL: "'"$API_BASE_URL"'",
                API_TIMEOUT_MS: "3000000",
                CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: 1,
                ANTHROPIC_MODEL: "'"$MINIMAX_MODEL"'",
                ANTHROPIC_SMALL_FAST_MODEL: "'"$MINIMAX_MODEL"'",
                ANTHROPIC_DEFAULT_SONNET_MODEL: "'"$MINIMAX_MODEL"'",
                ANTHROPIC_DEFAULT_OPUS_MODEL: "'"$MINIMAX_MODEL"'",
                ANTHROPIC_DEFAULT_HAIKU_MODEL: "'"$MINIMAX_MODEL"'"
            }
        };

        fs.writeFileSync(filePath, JSON.stringify(config, null, 2), "utf-8");
    '
    log_success "Settings saved to $CONFIG_DIR/settings.json"
}

# ========================
#          Main
# ========================

main() {
    echo ""
    echo "=============================================="
    echo "   MiniMax Claude Code Installer"
    echo "   (Coding Plan Edition)"
    echo "=============================================="
    echo ""

    # Check if Claude Code is already installed
    if check_claude_code; then
        echo ""
        log_info "Claude Code is already installed on this system."
        echo ""
        echo "Do you want to adapt your existing installation to use MiniMax?"
        echo ""
        echo "  1) Yes - Configure MiniMax (keeps Claude Code, updates settings)"
        echo "  2) No - Exit (use uninstall_minimax.sh for full removal)"
        echo ""
        read -p "Enter choice (1 or 2): " choice
        echo ""

        if [ "$choice" != "1" ]; then
            log_info "Exiting. Run ./uninstall_minimax.sh if you want to remove Claude Code."
            exit 0
        fi

        log_info "Configuring your existing Claude Code for MiniMax..."
        SKIP_INSTALL=1
    else
        SKIP_INSTALL=0
    fi

    check_nodejs

    if [ "$SKIP_INSTALL" -eq 0 ] && ! command -v claude &>/dev/null; then
        install_claude_code
    fi

    configure_claude_json
    configure_claude

    # Final cache clear
    hash -r

    echo ""
    log_success "MiniMax is ready!"
    echo ""
    echo "IMPORTANT: NVM was added to ~/.bashrc"
    echo ""
    echo "To use claude immediately, run:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Or simply open a new terminal window."
    echo ""
    echo "Then run: claude"
}

main "$@"
