# MiniMax Claude Code Installer

Installs and configures Claude Code to use MiniMax models via the Token Plan API.

## Prerequisites

- Linux or macOS
- Node.js 18+ (script installs via NVM if missing)
- MiniMax API key from https://platform.minimax.io/user-center/payment/token-plan

## Features

- Installs Claude Code via the official bootstrap script
- Supports region selection (International or China) with appropriate API endpoints
- Model selection: M2.7, M2.7-hs, M2.5, M2.5-hs, M2.1, M2, or Custom
- Optional MiniMax MCP server (web_search, understand_image)
- Token Plan and Pay-As-You-Go billing support

## Usage

```bash
git clone https://github.com/kuusuru/minimax-install-script.git
cd minimax-install-script
chmod +x install_minimax.sh
./install_minimax.sh
```

The script will prompt for:
1. Region (International or China)
2. Model (M2.7, M2.7-hs, M2.5, M2.5-hs, M2.1, M2, or Custom)
3. Billing type (Token Plan or Pay-As-You-Go)
4. API key
5. Optional MCP server installation (web_search, understand_image)

After installation:
```bash
cd /your/project
source ~/.bashrc  # or open a new terminal
claude
```

## API Endpoints

- International: `https://api.minimax.io/anthropic`
- China: `https://api.minimaxi.com/anthropic`

## Models

| Model | Description |
|-------|-------------|
| MiniMax-M2.7 | ~50 TPS normal, 100 TPS off-peak |
| MiniMax-M2.7-highspeed | ~100 TPS sustained (Token Plan only) |
| MiniMax-M2.5 | Balanced performance |
| MiniMax-M2.5-highspeed | Premium speed tier (Token Plan only) |
| MiniMax-M2.1 | Stable model |
| MiniMax-M2 | Base model |
| Custom | Enter any model name manually |

Note: `-highspeed` models require a Token Plan subscription. They will not work with Starter, Plus, or Max packages.

## MCP Server (Optional)

MiniMax Token Plan MCP provides two exclusive tools:

- **web_search** - Search the web for current information
- **understand_image** - Analyze and understand image content

The script will ask if you want to install the MCP server. Requires [uv](https://astral.sh/uv) (installed automatically if missing).

MCP configuration is added to `~/.claude/settings.json`. Restart Claude Code after installation for MCP tools to appear.

## Uninstall

```bash
./uninstall_minimax.sh
```

Choose "MiniMax Config Only" to keep Claude Code installed.
