# MiniMax Claude Code Installer

Installs and configures Claude Code to use MiniMax-M2.7 via the Token Plan API.

## Prerequisites

- Linux or macOS
- Node.js 18+ (script installs via NVM if missing)
- MiniMax API key from https://platform.minimax.io/user-center/payment/token-plan

## What This Script Does

1. Installs Claude Code via the official bootstrap script
2. Prompts for region (International or China) to set the correct API endpoint
3. Configures all Claude Code model variants to use MiniMax-M2.7

## Usage

```bash
git clone https://github.com/kuusuru/minimax-install-script.git
cd minimax-install-script
chmod +x install_minimax.sh
./install_minimax.sh
```

When prompted:
- Select billing type (Token Plan or Pay-As-You-Go)
- Select region (International or China)
- Paste your MiniMax API key

After installation:
```bash
cd /your/project
source ~/.bashrc  # or open a new terminal
claude
```

## API Endpoints

- International: `https://api.minimax.io/anthropic`
- China: `https://api.minimaxi.com/anthropic`

## Uninstall

```bash
./uninstall_minimax.sh
```

Choose "MiniMax Config Only" to keep Claude Code installed.
