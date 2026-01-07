#!/bin/bash
#
# MiniMax Claude Code Uninstaller
#
# WARNING: This script will remove Claude Code and all MiniMax configuration.
# Please read the following carefully before proceeding.
#
# =============================================================================
#                            WARNING - READ THIS
# =============================================================================
#
# This uninstaller offers TWO options:
#
# 1) FULL UNINSTALL - Removes EVERYTHING:
#    - Claude Code application
#    - All MiniMax configuration files
#    - All project-specific Claude settings
#    - All MCP configurations
#
#    After this, Claude Code will be completely removed from your system.
#    You can reinstall fresh using install_minimax.sh
#
# 2) MINIMAX CONFIG ONLY - Removes only MiniMax settings:
#    - ~/.claude/settings.json (MiniMax config)
#    - ~/.claude.json
#    - Project-specific .claude/ and .mcp.json
#
#    This keeps Claude Code installed but removes MiniMax configuration.
#    You can reconfigure MiniMax by running install_minimax.sh again.
#
# =============================================================================
#

set -euo pipefail

CONFIG_DIR="$HOME/.claude"

log_info() {
    echo "  * $*"
}

log_success() {
    echo "  [OK] $*"
}

log_error() {
    echo "  [ERROR] $*" >&2
}

# ========================
#      Verification
# ========================

check_claude_location() {
    log_info "Checking Claude Code installation location..."

    local claude_path=""

    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # Clear bash cache
    hash -r

    # Check via which command
    if command -v claude &>/dev/null; then
        claude_path=$(which claude 2>/dev/null || true)
        log_info "Claude Code found at: $claude_path"
    else
        log_info "Claude Code not found in PATH"
    fi

    echo "$claude_path"
}

# ========================
#      Full Uninstall
# ========================

full_uninstall() {
    echo ""
    log_info "Starting FULL UNINSTALL..."
    echo ""
    log_info "This will remove:"
    echo "  - Claude Code application"
    echo "  - All configuration files"
    echo "  - Project-specific settings"
    echo ""
    echo "NOTE: Node.js and NVM will NOT be removed."
    echo ""

    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    echo ""

    if [ "$confirm" != "yes" ]; then
        log_info "Cancelled."
        exit 0
    fi

    # Load nvm if available
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # 1. Uninstall via npm
    log_info "Uninstalling Claude Code via npm..."
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || {
        log_info "Claude Code not found via npm (may have been installed differently)"
    }

    # 2. Remove configuration directories
    log_info "Removing configuration files..."

    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        log_success "Removed $CONFIG_DIR/"
    fi

    if [ -f "$HOME/.claude.json" ]; then
        rm -f "$HOME/.claude.json"
        log_success "Removed $HOME/.claude.json"
    fi

    # 3. Remove project-specific settings (from current directory)
    if [ -d ".claude" ]; then
        rm -rf ".claude"
        log_success "Removed .claude/ (project settings)"
    fi

    if [ -f ".mcp.json" ]; then
        rm -f ".mcp.json"
        log_success "Removed .mcp.json"
    fi

    # 4. Clear terminal cache
    hash -r

    # 5. Verify removal
    log_info "Verifying removal..."

    # Load nvm again to check properly
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    hash -r

    if command -v claude &>/dev/null; then
        log_error "Claude Code may still be installed at: $(which claude)"
        log_error "You may need to manually remove it."
    else
        log_success "Claude Code is no longer in PATH"
    fi

    echo ""
    log_success "FULL UNINSTALL COMPLETE!"
    echo ""
    echo "To reinstall, run: ./install_minimax.sh"
}

# ========================
#   MiniMax Config Only
# ========================

config_only_uninstall() {
    echo ""
    log_info "Removing MiniMax configuration only..."
    echo ""
    log_info "This will remove:"
    echo "  - ~/.claude/settings.json (MiniMax config)"
    echo "  - ~/.claude.json"
    echo "  - Project-specific .claude/"
    echo "  - Project-specific .mcp.json"
    echo ""
    log_info "Claude Code will remain installed."
    echo ""

    read -p "Continue? (y/N): " confirm
    echo ""

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        exit 0
    fi

    # 1. Remove MiniMax configuration
    log_info "Removing MiniMax configuration files..."

    if [ -f "$CONFIG_DIR/settings.json" ]; then
        rm -f "$CONFIG_DIR/settings.json"
        log_success "Removed $CONFIG_DIR/settings.json"
    else
        log_info "No settings.json found."
    fi

    if [ -f "$HOME/.claude.json" ]; then
        rm -f "$HOME/.claude.json"
        log_success "Removed $HOME/.claude.json"
    fi

    # 2. Remove project-specific settings
    if [ -d ".claude" ]; then
        rm -rf ".claude"
        log_success "Removed .claude/ (project settings)"
    fi

    if [ -f ".mcp.json" ]; then
        rm -f ".mcp.json"
        log_success "Removed .mcp.json"
    fi

    # 3. Clear terminal cache
    hash -r

    echo ""
    log_success "MINIMAX CONFIGURATION REMOVED!"
    echo ""
    echo "Claude Code is still installed."
    echo "To reconfigure MiniMax, run: ./install_minimax.sh"
}

# ========================
#          Main
# ========================

main() {
    echo ""
    echo "=============================================="
    echo "   MiniMax Claude Code Uninstaller"
    echo "=============================================="
    echo ""
    log_info "Before proceeding, please read the header comments in this script."
    echo ""
    echo "Select uninstall option:"
    echo ""
    echo "  1) FULL UNINSTALL - Removes everything"
    echo "  2) MiniMax Config Only - Keeps Claude Code"
    echo "  3) Cancel"
    echo ""

    read -p "Enter choice (1, 2, or 3): " choice
    echo ""

    check_claude_location

    case "$choice" in
        1)
            full_uninstall
            ;;
        2)
            config_only_uninstall
            ;;
        3)
            log_info "Cancelled."
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please enter 1, 2, or 3."
            exit 1
            ;;
    esac
}

main "$@"
