#!/bin/bash
#
# MiniMax Claude Code Uninstaller
# Removes Claude Code and MiniMax configuration
#

set -euo pipefail

CONFIG_DIR="$HOME/.claude"

log_info() {
    echo "🔹 $*"
}

log_success() {
    echo "✅ $*"
}

log_error() {
    echo "❌ $*" >&2
}

# ========================
#        Uninstallation
# ========================

uninstall_claude_code() {
    if ! command -v npm &>/dev/null; then
        log_info "npm not found. Claude Code may not be installed."
    else
        log_info "Uninstalling Claude Code..."
        npm uninstall -g @anthropic-ai/claude-code || {
            log_error "Failed to uninstall Claude Code via npm."
        }
        log_success "Claude Code uninstalled."
    fi
}

remove_config() {
    log_info "Removing MiniMax configuration..."

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
}

main() {
    echo ""
    log_info "MiniMax Claude Code Uninstaller"
    echo ""

    read -p "Uninstall Claude Code and remove MiniMax config? (y/N): " confirm
    echo ""

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled."
        exit 0
    fi

    uninstall_claude_code
    remove_config

    echo ""
    log_success "Uninstallation complete!"
    echo " Note: Node.js and NVM were not removed."
}

main "$@"
