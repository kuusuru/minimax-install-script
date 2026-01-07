# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains an installation script (`install_minimax.sh`) that automates the setup of MiniMax-M2.1 model integration with Claude Code. The script:
1. Checks/installs Node.js (v18+ required)
2. Installs/updates Claude Code via npm
3. Configures `~/.claude/settings.json` with MiniMax API credentials

## Usage

```bash
./install_minimax.sh
```

The script will prompt for a MiniMax API key during configuration.

## Configuration

The script configures Claude Code via `~/.claude/settings.json` with:
- `ANTHROPIC_BASE_URL`: `https://api.minimax.io/anthropic` (international) or `https://api.minimaxi.com/anthropic` (China)
- `ANTHROPIC_MODEL`: `MiniMax-M2.1`
- All model variants mapped to MiniMax-M2.1 (sonnet, opus, haiku, small_fast)

## Architecture

Single bash script with modular functions:
- `log_info/success/error` - Logging utilities
- `install_nodejs/check_nodejs` - Node.js installation via NVM
- `install_claude_code` - npm global install of `@anthropic-ai/claude-code`
- `configure_claude_json` - Sets onboarding as complete
- `configure_claude` - Interactive API key configuration
