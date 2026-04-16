#!/bin/bash
#
# MiniMax Claude Code Installer (Token Plan Edition)
# Adapted from:
#   - https://platform.minimax.io/docs/token-plan/claude-code
#   - https://downloads.claude.ai/claude-code-releases/bootstrap.sh
#   - Original script from Z.ai
#
# Prerequisites:
#   - Linux or macOS (requires bash)
#   - Node.js 18+ (script installs via NVM if missing)
#   - MiniMax Token Plan API Key
#

set -euo pipefail

# ========================
#        Define Constants
# ========================
NODE_MIN_VERSION=18
NODE_INSTALL_VERSION=22
NVM_VERSION="v0.40.3"
CLAUDE_PACKAGE="@anthropic-ai/claude-code"
CONFIG_DIR="$HOME/.claude"

# API Key URLs
TOKEN_PLAN_URL="https://platform.minimax.io/user-center/payment/token-plan"
PLATFORM_URL="https://platform.minimax.io/user-center/basic-information/interface-key"

# Claude Code bootstrap URL
CLAUDE_BOOTSTRAP_URL="https://downloads.claude.ai/claude-code-releases/bootstrap.sh"

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
#      Region Selection
# ========================

select_region() {
    while true; do
        echo "Select your region:"
        echo "  1) International (outside China) - uses api.minimax.io"
        echo "  2) China (Mainland) - uses api.minimaxi.com"
        echo ""
        read -p "Enter choice (1 or 2): " choice
        echo ""

        case "$choice" in
            1)
                API_BASE_URL="https://api.minimax.io/anthropic"
                log_info "Selected International endpoint: $API_BASE_URL"
                return 0
                ;;
            2)
                API_BASE_URL="https://api.minimaxi.com/anthropic"
                log_info "Selected China endpoint: $API_BASE_URL"
                return 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# ========================
#      Model Selection
# ========================

select_model() {
    while true; do
        echo "Select your MiniMax model:"
        echo "  1) MiniMax-M2.7          (~50 TPS normal, 100 TPS off-peak)"
        echo "  2) MiniMax-M2.7-highspeed (~100 TPS sustained, HS plan only)"
        echo "  3) MiniMax-M2.5"
        echo "  4) MiniMax-M2.5-highspeed (HS plan only)"
        echo "  5) MiniMax-M2.1"
        echo "  6) MiniMax-M2"
        echo "  7) Custom (enter manually)"
        echo ""
        echo "Note: '-highspeed' models require an HS-tier subscription."
        echo "      Available only with: Plus–HS, Max–HS, or Ultra–HS."
        echo "      Standard plans (Starter, Plus, Max) use the base M2.7."
        echo ""
        read -p "Enter choice (1-7): " choice
        echo ""

        case "$choice" in
            1)
                MINIMAX_MODEL="MiniMax-M2.7"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            2)
                MINIMAX_MODEL="MiniMax-M2.7-highspeed"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            3)
                MINIMAX_MODEL="MiniMax-M2.5"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            4)
                MINIMAX_MODEL="MiniMax-M2.5-highspeed"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            5)
                MINIMAX_MODEL="MiniMax-M2.1"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            6)
                MINIMAX_MODEL="MiniMax-M2"
                log_info "Selected model: $MINIMAX_MODEL"
                return 0
                ;;
            7)
                read -p "Enter custom model name: " MINIMAX_MODEL
                echo ""
                if [ -z "$MINIMAX_MODEL" ]; then
                    log_error "Model name cannot be empty."
                    continue
                fi
                log_info "Selected custom model: $MINIMAX_MODEL"
                return 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1-7."
                ;;
        esac
    done
}

# ========================
#      Node.js Installation
# ========================

install_nodejs() {
    local platform
    platform=$(uname -s)

    case "$platform" in
        Linux|Darwin)
            log_info "Installing Node.js via NVM..."

            # Install nvm — use mktemp to avoid /tmp race conditions
            log_info "Downloading NVM..."
            local nvm_tmp
            nvm_tmp=$(mktemp /tmp/nvm_install.XXXXXX.sh)
            if ! curl -fsSL --connect-timeout 30 --max-time 120 \
                "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
                -o "$nvm_tmp"; then
                log_error "NVM download failed. Check your network connection."
                rm -f "$nvm_tmp"
                exit 1
            fi
            bash "$nvm_tmp" || {
                log_error "NVM installation script failed."
                rm -f "$nvm_tmp"
                exit 1
            }
            rm -f "$nvm_tmp"

            # Load nvm into current session
            export NVM_DIR="$HOME/.nvm"
            # shellcheck source=/dev/null
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            # shellcheck source=/dev/null
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

    # Detect user's login shell, not the script's shell
    local shell_name
    shell_name=$(basename "$SHELL")
    local shell_config=""
    case "$shell_name" in
        zsh)
            shell_config="$HOME/.zshrc"
            ;;
        bash)
            shell_config="$HOME/.bashrc"
            ;;
        *)
            # Fallback: check for common shell configs, then .profile (POSIX standard)
            if [ -f "$HOME/.zshrc" ]; then
                shell_config="$HOME/.zshrc"
            elif [ -f "$HOME/.bashrc" ]; then
                shell_config="$HOME/.bashrc"
            else
                shell_config="$HOME/.profile"
            fi
            ;;
    esac

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
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if command -v node &>/dev/null; then
        local current_version
        current_version=$(node -v | sed 's/v//')
        local major_version
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
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if command -v claude &>/dev/null; then
        log_success "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
        return 0
    fi
    return 1
}

install_claude_code() {
    # Fix the "No such file or directory" bash cache error
    hash -r

    log_info "Installing Claude Code using official bootstrap script..."

    # Use mktemp to avoid /tmp race conditions
    local bootstrap_tmp
    bootstrap_tmp=$(mktemp /tmp/claude_bootstrap.XXXXXX.sh)
    if ! curl -fsSL --connect-timeout 30 --max-time 120 \
        "$CLAUDE_BOOTSTRAP_URL" -o "$bootstrap_tmp"; then
        log_error "Failed to download bootstrap script. Check your network."
        rm -f "$bootstrap_tmp"
        exit 1
    fi

    bash "$bootstrap_tmp" || {
        log_error "Bootstrap installation failed. Falling back to npm..."
        rm -f "$bootstrap_tmp"
        if ! npm install -g "$CLAUDE_PACKAGE"; then
            log_error "NPM installation failed."
            exit 1
        fi
    }
    rm -f "$bootstrap_tmp"
    log_success "Claude Code installed successfully"
}

configure_claude_json(){
    # Sets onboarding as complete so it doesn't prompt for auth
    local file_path="$HOME/.claude.json"
    local tmp_file
    tmp_file=$(mktemp) || { log_error "Failed to create temp file"; return 1; }

    # Read existing or start fresh
    if [ -f "$file_path" ]; then
        # Preserve existing data, only set hasCompletedOnboarding
        node -e "
            const fs = require('fs');
            const path = require('path');
            const filePath = '$file_path';
            const tmpPath = '$tmp_file';
            let data = {};
            try {
                data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
            } catch (e) {}
            data.hasCompletedOnboarding = true;
            fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
        " || { log_error "Failed to update .claude.json"; rm -f "$tmp_file"; return 1; }
    else
        echo '{"hasCompletedOnboarding": true}' > "$tmp_file"
    fi

    mv "$tmp_file" "$file_path" || { log_error "Failed to write .claude.json"; rm -f "$tmp_file"; return 1; }
}

# ========================
#      API Configuration
# ========================

select_key_type() {
    while true; do
        echo "Select your MiniMax billing type:"
        echo "  1) Token Plan (fixed monthly fee, includes usage)"
        echo "  2) Pay-As-You-Go (pay per usage)"
        echo ""
        read -p "Enter choice (1 or 2): " choice
        echo ""

        case "$choice" in
            1)
                echo " Get your Token Plan API Key at: $TOKEN_PLAN_URL"
                BILLING_TYPE="token"
                return 0
                ;;
            2)
                echo " Get your Platform API Key at: $PLATFORM_URL"
                BILLING_TYPE="payg"
                return 0
                ;;
            *)
                log_error "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

configure_claude() {
    log_info "Configuring Claude Code for MiniMax (Token Plan Edition)..."
    echo ""

    # Select region first
    select_region
    echo ""

    # Select model
    select_model
    echo ""

    # Select billing type
    select_key_type
    echo ""

    read -s -p " Paste your MiniMax API Key: " api_key
    echo

    if [ -z "$api_key" ]; then
        log_error "API key is required."
        exit 1
    fi

    ensure_dir_exists "$CONFIG_DIR"

    # Export API key and other user-supplied values as env vars so Node.js
    # reads them safely — avoids any shell injection risk from user input
    export MINIMAX_API_KEY="$api_key"
    export MINIMAX_API_BASE_URL="$API_BASE_URL"
    export MINIMAX_MODEL_NAME="$MINIMAX_MODEL"

    # Write settings.json with MiniMax Model Mapping (merge with existing settings)
    node -e "
        const os = require('os');
        const fs = require('fs');
        const path = require('path');

        const filePath = path.join(os.homedir(), '.claude', 'settings.json');
        let config = {};
        try {
            if (fs.existsSync(filePath)) {
                config = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
            }
        } catch (e) {
            console.error('Warning: could not parse existing settings.json:', e.message);
        }

        // Ensure env object exists
        if (!config.env) config.env = {};

        // Set MiniMax env vars (preserves other env vars from other tools)
        const model = process.env.MINIMAX_MODEL_NAME;
        config.env.ANTHROPIC_AUTH_TOKEN = process.env.MINIMAX_API_KEY;
        config.env.ANTHROPIC_BASE_URL = process.env.MINIMAX_API_BASE_URL;
        config.env.API_TIMEOUT_MS = '3000000';
        config.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1';
        config.env.ANTHROPIC_MODEL = model;
        config.env.ANTHROPIC_SMALL_FAST_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_SONNET_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_OPUS_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = model;

        fs.writeFileSync(filePath, JSON.stringify(config, null, 2), 'utf-8');
    " || { log_error "Failed to write settings.json"; unset MINIMAX_API_KEY MINIMAX_API_BASE_URL MINIMAX_MODEL_NAME; exit 1; }

    # Clear sensitive values from environment
    unset MINIMAX_API_KEY MINIMAX_API_BASE_URL MINIMAX_MODEL_NAME

    log_success "Settings saved to $CONFIG_DIR/settings.json"
}

# ========================
#      MCP Server Installation
# ========================

configure_mcp_servers() {
    log_info "Configuring MiniMax MCP servers..."

    local settings_file="$HOME/.claude/settings.json"

    # Determine API host based on API_BASE_URL
    local api_host
    if [[ "$API_BASE_URL" == *"minimaxi.com"* ]]; then
        api_host="https://api.minimaxi.com"
    else
        api_host="https://api.minimax.io"
    fi

    # Read existing API key from settings.json
    local api_key
    api_key=$(node -e "
        const fs = require('fs');
        try {
            const settings = JSON.parse(fs.readFileSync(process.env.MINIMAX_SETTINGS_FILE, 'utf-8'));
            console.log(settings.env?.ANTHROPIC_AUTH_TOKEN || '');
        } catch (e) {
            console.log('');
        }
    " 2>/dev/null) || api_key=""

    if [ -z "$api_key" ]; then
        log_info "No API key found in settings. Skipping MCP server configuration."
        return 0
    fi

    # Export values as env vars for Node.js (no shell injection)
    export MINIMAX_API_KEY="$api_key"
    export MINIMAX_API_HOST="$api_host"
    export MINIMAX_SETTINGS_FILE="$settings_file"

    # Merge MiniMax MCP config into settings.json
    node -e "
        const fs = require('fs');
        const settingsPath = process.env.MINIMAX_SETTINGS_FILE;

        let settings = {};
        try {
            if (fs.existsSync(settingsPath)) {
                settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
            }
        } catch (e) {
            console.error('Warning: could not parse settings.json:', e.message);
        }

        if (!settings.mcpServers) settings.mcpServers = {};
        settings.mcpServers.MiniMax = {
            command: 'uvx',
            args: ['minimax-coding-plan-mcp'],
            env: {
                MINIMAX_API_KEY: process.env.MINIMAX_API_KEY,
                MINIMAX_API_HOST: process.env.MINIMAX_API_HOST
            }
        };

        fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
    " || {
        log_error "Failed to configure MCP server"
        unset MINIMAX_API_KEY MINIMAX_API_HOST MINIMAX_SETTINGS_FILE
        return 1
    }

    unset MINIMAX_API_KEY MINIMAX_API_HOST MINIMAX_SETTINGS_FILE
    log_success "MiniMax MCP server configured."
}

install_mcp_servers() {
    echo ""
    echo "=============================================="
    echo "   MiniMax MCP Server (web_search, understand_image)"
    echo "=============================================="
    echo ""
    echo "Token Plan MCP provides two exclusive tools for coding:"
    echo "  - web_search: Search the web for current information"
    echo "  - understand_image: Analyze and understand image content"
    echo ""
    echo "The MCP server requires uv (Python package installer)."
    echo ""

    local install_mcp="n"
    read -p "Install MiniMax MCP server? (y/N): " install_mcp
    echo ""

    if [[ ! "$install_mcp" =~ ^[Yy]$ ]]; then
        log_info "Skipping MCP server installation."
        return 0
    fi

    # Load nvm to ensure uv is findable if installed via nvm
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # Check for uv
    if ! command -v uv &>/dev/null; then
        log_info "Installing uv..."
        local uv_tmp
        uv_tmp=$(mktemp /tmp/uv_install.XXXXXX.sh)
        if ! curl -LsSf --connect-timeout 30 --max-time 120 \
            https://astral.sh/uv/install.sh -o "$uv_tmp"; then
            log_error "Failed to download uv installer."
            rm -f "$uv_tmp"
            return 1
        fi
        sh "$uv_tmp" || { log_error "uv installation failed."; rm -f "$uv_tmp"; return 1; }
        rm -f "$uv_tmp"

        # Source the profile to get uv in PATH for this session
        # shellcheck source=/dev/null
        [ -s "$HOME/.local/bin/env" ] && \. "$HOME/.local/bin/env"
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # uvx runs the package on-the-fly; no separate install step needed.
    # The settings.json mcpServers entry tells Claude Code to launch it.
    configure_mcp_servers
    log_success "MiniMax MCP server ready (configured in settings.json)."

    echo ""
    echo "Note: Restart Claude Code for MCP tools to appear."
}

# ========================
#          Main
# ========================

main() {
    echo ""
    echo "=============================================="
    echo "   MiniMax Claude Code Installer"
    echo "   (Token Plan Edition)"
    echo "=============================================="
    echo ""

    # Initialize early to avoid set -u failures if logic flow changes
    SKIP_INSTALL=0

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
    fi

    check_nodejs

    if [ "$SKIP_INSTALL" -eq 0 ] && ! command -v claude &>/dev/null; then
        install_claude_code
    fi

    configure_claude_json
    configure_claude
    install_mcp_servers

    # Final cache clear
    hash -r

    echo ""
    log_success "MiniMax is ready!"
    echo ""
    echo "IMPORTANT:"
    echo "  - NVM was added to your shell config"
    echo "  - Switch to your project folder before running claude"
    echo ""
    echo "To use claude immediately in current terminal, run:"
    echo "  source ~/.bashrc   # (or source ~/.zshrc if you use ZSH)"
    echo ""
    echo "Or simply open a new terminal, cd to your project, then run: claude"
}

main "$@"
