#!/bin/bash
#
# MiniMax Claude Code Installer (Token Plan Edition)
# Adapted from:
#   - https://platform.minimax.io/docs/token-plan/claude-code
#   - https://downloads.claude.ai/claude-code-releases/bootstrap.sh
#   - Original script from Z.ai
#
# Prerequisites:
#   - Linux or macOS
#   - Node.js 18+ (will be installed if missing)
#   - MiniMax Token Plan API Key
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
            select_region
            ;;
    esac
}

# ========================
#      Model Selection
# ========================

select_model() {
    echo "Select your MiniMax model:"
    echo "  1) MiniMax-M2.7          (~50 TPS normal, 100 TPS off-peak)"
    echo "  2) MiniMax-M2.7-highspeed (~100 TPS sustained, Token Plan only)"
    echo "  3) MiniMax-M2.5"
    echo "  4) MiniMax-M2.5-highspeed (Token Plan only)"
    echo "  5) MiniMax-M2.1"
    echo "  6) MiniMax-M2"
    echo "  7) Custom (enter manually)"
    echo ""
    echo "Note: '-highspeed' models require a Token Plan subscription."
    echo "      They will not work with Starter, Plus, or Max packages."
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
                select_model
            fi
            log_info "Selected custom model: $MINIMAX_MODEL"
            return 0
            ;;
        *)
            log_error "Invalid choice. Please enter 1-7."
            select_model
            ;;
    esac
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
        log_success "Claude Code is already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
        return 0
    fi
    return 1
}

install_claude_code() {
    # Fix the "No such file or directory" bash cache error
    hash -r

    log_info "Installing Claude Code using official bootstrap script..."

    # Download and run the official Claude Code bootstrap script
    curl -fsSL "$CLAUDE_BOOTSTRAP_URL" | bash || {
        log_error "Bootstrap installation failed. Falling back to npm..."
        npm install -g "$CLAUDE_PACKAGE" || {
            log_error "NPM installation failed."
            exit 1
        }
    }
    log_success "Claude Code installed successfully"
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
    echo "  1) Token Plan (fixed monthly fee, includes usage)"
    echo "  2) Pay-As-You-Go (pay per usage)"
    echo ""
    read -p "Enter choice (1 or 2): " choice
    echo ""

    case "$choice" in
        1)
            echo " Get your Token Plan API Key at: $TOKEN_PLAN_URL"
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
    log_info "Configuring Claude Code for MiniMax (Token Plan Edition)..."
    echo ""

    # Select region first
    select_region
    echo ""

    # Select model
    select_model
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
#      MCP Server Installation
# ========================

configure_mcp_servers() {
    log_info "Configuring MiniMax MCP servers..."

    local settings_file="$HOME/.claude/settings.json"

    # Read current settings or create new
    local settings_json
    if [ -f "$settings_file" ]; then
        settings_json=$(cat "$settings_file")
    else
        settings_json="{}"
    fi

    # Determine API host based on API_BASE_URL
    local api_host
    if [[ "$API_BASE_URL" == *"minimaxi.com"* ]]; then
        api_host="https://api.minimaxi.com"
    else
        api_host="https://api.minimax.io"
    fi

    # Read existing API key from settings
    local existing_key=""
    if [ -f "$settings_file" ]; then
        existing_key=$(node --eval "
            const fs = require('fs');
            const path = require('path');
            const settings = JSON.parse(fs.readFileSync(path.join(process.env.HOME, '.claude', 'settings.json'), 'utf-8'));
            console.log(settings.env?.ANTHROPIC_AUTH_TOKEN || '');
        " 2>/dev/null || echo "")
    fi

    local api_key="${MINIMAX_API_KEY:-$existing_key}"

    if [ -z "$api_key" ]; then
        log_info "No API key found. Skipping MCP server configuration."
        return 0
    fi

    # Build mcpServers JSON
    local mcp_json="{\"mcpServers\":{\"MiniMax\":{\"command\":\"uvx\",\"args\":[\"minimax-coding-plan-mcp\",\"-y\"],\"env\":{\"MINIMAX_API_KEY\":\"$api_key\",\"MINIMAX_API_HOST\":\"$api_host\"}}}}"

    # Merge with existing settings
    node --eval "
        const fs = require('fs');
        const path = require('path');
        const settingsPath = path.join(process.env.HOME, '.claude', 'settings.json');
        let settings = {};
        try {
            if (fs.existsSync(settingsPath)) {
                settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
            }
        } catch (e) {}
        const mcp = $mcp_json;
        if (!settings.mcpServers) settings.mcpServers = {};
        settings.mcpServers = { ...settings.mcpServers, ...mcp.mcpServers };
        fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
    "

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

    if [[ "$install_mcp" =~ ^[Yy]$ ]]; then
        # Check for uv
        if ! command -v uv &>/dev/null; then
            log_info "Installing uv..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            export PATH="$HOME/.local/bin:$PATH"
        fi

        # Install the MCP server globally
        uvx minimax-coding-plan-mcp -y 2>/dev/null || log_info "uvx install attempted (may need manual config in settings.json)"

        configure_mcp_servers

        log_success "MiniMax MCP server installed."
        echo ""
        echo "Note: Restart Claude Code for MCP tools to appear."
    else
        log_info "Skipping MCP server installation."
    fi
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
    install_mcp_servers

    # Final cache clear
    hash -r

    echo ""
    log_success "MiniMax is ready!"
    echo ""
    echo "IMPORTANT:"
    echo "  - NVM was added to ~/.bashrc"
    echo "  - Switch to your project folder before running claude"
    echo ""
    echo "To use claude immediately in current terminal, run:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Or simply open a new terminal, cd to your project, then run: claude"
}

main "$@"
