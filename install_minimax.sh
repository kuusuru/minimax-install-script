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

# Claude Code version pinning — set to a specific version (e.g. "1.0.53") to pin,
# or leave empty to install the latest release.
CLAUDE_CODE_VERSION=""

# API timeout in milliseconds (50 minutes)
API_TIMEOUT_MS="3000000"

# API Key URLs
TOKEN_PLAN_URL="https://platform.minimax.io/user-center/payment/token-plan"
PLATFORM_URL="https://platform.minimax.io/user-center/basic-information/interface-key"

# Claude Code bootstrap URL
CLAUDE_BOOTSTRAP_URL="https://downloads.claude.ai/claude-code-releases/bootstrap.sh"

# ========================
#   Batch / Non-interactive mode
# ========================
ARG_REGION=""
ARG_MODEL=""
ARG_API_KEY=""
ARG_BILLING=""

# ========================
#   Emoji / ASCII fallback
# ========================
USE_EMOJI=1
if [ "${TERM:-}" = "dumb" ] || [ "${TERM:-}" = "linux" ] ||
   { command -v locale &>/dev/null && ! locale charmap 2>/dev/null | grep -qi utf; }; then
    USE_EMOJI=0
fi

# ========================
#        Functions
# ========================

log_info() {
    if [ "$USE_EMOJI" -eq 1 ]; then
        echo "🔹 $*"
    else
        echo "[INFO] $*"
    fi
}

log_success() {
    if [ "$USE_EMOJI" -eq 1 ]; then
        echo "✅ $*"
    else
        echo "[OK] $*"
    fi
}

log_error() {
    if [ "$USE_EMOJI" -eq 1 ]; then
        echo "❌ $*" >&2
    else
        echo "[ERROR] $*" >&2
    fi
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

# Load NVM into the current shell session
load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

# Cleanup sensitive environment variables on exit
cleanup_sensitive() {
    unset MINIMAX_API_KEY MINIMAX_API_BASE_URL MINIMAX_MODEL_NAME MINIMAX_API_TIMEOUT 2>/dev/null || true
    unset CLAUDE_JSON_PATH CLAUDE_JSON_TMP MINIMAX_SETTINGS_FILE MINIMAX_API_HOST 2>/dev/null || true
}
trap cleanup_sensitive EXIT

# ========================
#   Parse command-line args
# ========================

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --region)     ARG_REGION="$2";  shift 2 ;;
            --model)      ARG_MODEL="$2";   shift 2 ;;
            --api-key)    ARG_API_KEY="$2"; shift 2 ;;
            --billing)    ARG_BILLING="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --region <1|2>            1=International, 2=China"
                echo "  --model <name>            Model name (e.g. MiniMax-M3)"
                echo "  --api-key <key>           MiniMax API key"
                echo "  --billing <token|payg>    Billing type"
                echo "  --help                    Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# ========================
#      Region Selection
# ========================

select_region() {
    # Batch mode: use command-line argument
    if [ -n "$ARG_REGION" ]; then
        case "$ARG_REGION" in
            1) API_BASE_URL="https://api.minimax.io/anthropic"
               log_info "Selected International endpoint: $API_BASE_URL"; return 0 ;;
            2) API_BASE_URL="https://api.minimaxi.com/anthropic"
               log_info "Selected China endpoint: $API_BASE_URL"; return 0 ;;
            *) log_error "Invalid --region value: $ARG_REGION (must be 1 or 2)"; exit 1 ;;
        esac
    fi

    while true; do
        echo "Select your region:"
        echo "  1) International (outside China) - uses api.minimax.io"
        echo "  2) China (Mainland) - uses api.minimaxi.com"
        echo ""
        local choice
        read -p "Enter choice (1 or 2): " choice || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
        echo ""

        case "$choice" in
            1) API_BASE_URL="https://api.minimax.io/anthropic"
               log_info "Selected International endpoint: $API_BASE_URL"; return 0 ;;
            2) API_BASE_URL="https://api.minimaxi.com/anthropic"
               log_info "Selected China endpoint: $API_BASE_URL"; return 0 ;;
            *) log_error "Invalid choice. Please enter 1 or 2." ;;
        esac
    done
}

# ========================
#      Model Selection
# ========================

select_model() {
    # Batch mode: use command-line argument
    if [ -n "$ARG_MODEL" ]; then
        MINIMAX_MODEL="$ARG_MODEL"
        log_info "Selected model: $MINIMAX_MODEL"
        return 0
    fi

    while true; do
        echo "Select your MiniMax model:"
        echo "  1) MiniMax-M3             (Frontier, 1M context, multimodal, agentic)"
        echo "  2) MiniMax-M2.7           (~50 TPS normal, 100 TPS off-peak)"
        echo "  3) MiniMax-M2.7-highspeed (~100 TPS sustained, HS plan only)"
        echo "  4) MiniMax-M2.5"
        echo "  5) MiniMax-M2.5-highspeed (HS plan only)"
        echo "  6) MiniMax-M2.1"
        echo "  7) MiniMax-M2"
        echo "  8) Custom (enter manually)"
        echo ""
        echo "Note: '-highspeed' models require an HS-tier subscription."
        echo "      Available only with: Plus–HS, Max–HS, or Ultra–HS."
        echo "      Standard plans (Starter, Plus, Max) use M3 or base M2.7."
        echo ""
        local choice
        read -p "Enter choice (1-8): " choice || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
        echo ""

        case "$choice" in
            1) MINIMAX_MODEL="MiniMax-M3";             log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            2) MINIMAX_MODEL="MiniMax-M2.7";           log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            3) MINIMAX_MODEL="MiniMax-M2.7-highspeed"; log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            4) MINIMAX_MODEL="MiniMax-M2.5";           log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            5) MINIMAX_MODEL="MiniMax-M2.5-highspeed"; log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            6) MINIMAX_MODEL="MiniMax-M2.1";           log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            7) MINIMAX_MODEL="MiniMax-M2";             log_info "Selected model: $MINIMAX_MODEL"; return 0 ;;
            8)
                read -p "Enter custom model name: " MINIMAX_MODEL || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
                echo ""
                if [ -z "$MINIMAX_MODEL" ]; then
                    log_error "Model name cannot be empty."
                    continue
                fi
                log_info "Selected custom model: $MINIMAX_MODEL"
                return 0
                ;;
            *) log_error "Invalid choice. Please enter 1-8." ;;
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

            # Verify the download is non-empty before executing
            if [ ! -s "$nvm_tmp" ]; then
                log_error "NVM download appears empty or corrupt. Aborting."
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
            load_nvm

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
    load_nvm

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
    load_nvm

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
        if [ -n "$CLAUDE_CODE_VERSION" ]; then
            npm install -g "${CLAUDE_PACKAGE}@${CLAUDE_CODE_VERSION}" || {
                log_error "NPM installation failed."
                exit 1
            }
        else
            npm install -g "$CLAUDE_PACKAGE" || {
                log_error "NPM installation failed."
                exit 1
            }
        fi
    }
    rm -f "$bootstrap_tmp"
    log_success "Claude Code installed successfully"
}

configure_claude_json() {
    # Ensure node is available
    if ! command -v node &>/dev/null; then
        log_error "Node.js is not available. Cannot configure .claude.json."
        return 1
    fi

    # Sets onboarding as complete so it doesn't prompt for auth
    local file_path="$HOME/.claude.json"
    local tmp_file
    tmp_file=$(mktemp) || { log_error "Failed to create temp file"; return 1; }

    # Read existing or start fresh
    if [ -f "$file_path" ]; then
        # Pass paths via environment variables to avoid shell injection from user paths
        export CLAUDE_JSON_PATH="$file_path"
        export CLAUDE_JSON_TMP="$tmp_file"
        # Preserve existing data, only set hasCompletedOnboarding
        node -e "
            const fs = require('fs');
            const filePath = process.env.CLAUDE_JSON_PATH;
            const tmpPath = process.env.CLAUDE_JSON_TMP;
            let data = {};
            try {
                data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
            } catch (e) {}
            data.hasCompletedOnboarding = true;
            fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
        " || { log_error "Failed to update .claude.json"; rm -f "$tmp_file"; unset CLAUDE_JSON_PATH CLAUDE_JSON_TMP; return 1; }
        unset CLAUDE_JSON_PATH CLAUDE_JSON_TMP
    else
        echo '{"hasCompletedOnboarding": true}' > "$tmp_file"
    fi

    mv "$tmp_file" "$file_path" || { log_error "Failed to write .claude.json"; rm -f "$tmp_file"; return 1; }
}

# ========================
#      API Configuration
# ========================

select_key_type() {
    # Batch mode: use command-line argument
    if [ -n "$ARG_BILLING" ]; then
        case "$ARG_BILLING" in
            token)
                echo " Get your Token Plan API Key at: $TOKEN_PLAN_URL"
                BILLING_TYPE="token"
                return 0
                ;;
            payg)
                echo " Get your Platform API Key at: $PLATFORM_URL"
                BILLING_TYPE="payg"
                return 0
                ;;
            *)
                log_error "Invalid --billing value: $ARG_BILLING (must be 'token' or 'payg')"
                exit 1
                ;;
        esac
    fi

    while true; do
        echo "Select your MiniMax billing type:"
        echo "  1) Token Plan (fixed monthly fee, includes usage)"
        echo "  2) Pay-As-You-Go (pay per usage)"
        echo ""
        local choice
        read -p "Enter choice (1 or 2): " choice || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
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

    # Batch mode or interactive API key input
    local api_key
    if [ -n "$ARG_API_KEY" ]; then
        api_key="$ARG_API_KEY"
    else
        read -s -p " Paste your MiniMax API Key: " api_key || { echo; log_error "Input interrupted (EOF). Aborting."; exit 1; }
        echo
    fi

    if [ -z "$api_key" ]; then
        log_error "API key is required."
        exit 1
    fi

    ensure_dir_exists "$CONFIG_DIR"

    # Ensure node is available
    if ! command -v node &>/dev/null; then
        log_error "Node.js is not available. Cannot write settings.json."
        exit 1
    fi

    # Export API key and other user-supplied values as env vars so Node.js
    # reads them safely — avoids any shell injection risk from user input
    export MINIMAX_API_KEY="$api_key"
    export MINIMAX_API_BASE_URL="$API_BASE_URL"
    export MINIMAX_MODEL_NAME="$MINIMAX_MODEL"
    export MINIMAX_API_TIMEOUT="$API_TIMEOUT_MS"

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
        config.env.API_TIMEOUT_MS = process.env.MINIMAX_API_TIMEOUT;
        config.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1';
        config.env.ANTHROPIC_MODEL = model;
        config.env.ANTHROPIC_SMALL_FAST_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_SONNET_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_OPUS_MODEL = model;
        config.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = model;

        fs.writeFileSync(filePath, JSON.stringify(config, null, 2), 'utf-8');
    " || { log_error "Failed to write settings.json"; exit 1; }

    # Restrict settings.json permissions to owner only
    chmod 600 "$CONFIG_DIR/settings.json"

    # Clear sensitive values from environment
    unset MINIMAX_API_KEY MINIMAX_API_BASE_URL MINIMAX_MODEL_NAME MINIMAX_API_TIMEOUT

    log_success "Settings saved to $CONFIG_DIR/settings.json"
    log_info "Note: $CONFIG_DIR/settings.json contains your API key. Keep it secure."
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

    # Export MINIMAX_SETTINGS_FILE BEFORE the first Node.js call that reads it
    export MINIMAX_SETTINGS_FILE="$settings_file"

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
        unset MINIMAX_SETTINGS_FILE
        return 0
    fi

    # Export remaining values as env vars for the second Node.js call
    export MINIMAX_API_KEY="$api_key"
    export MINIMAX_API_HOST="$api_host"

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
    read -p "Install MiniMax MCP server? (y/N): " install_mcp || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
    echo ""

    if [[ ! "$install_mcp" =~ ^[Yy]$ ]]; then
        log_info "Skipping MCP server installation."
        return 0
    fi

    # Load nvm to ensure uv is findable if installed via nvm
    load_nvm

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
    # Parse command-line arguments
    parse_args "$@"

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
        local choice
        read -p "Enter choice (1 or 2): " choice || { log_error "Input interrupted (EOF). Aborting."; exit 1; }
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
