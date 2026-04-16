# MiniMax Claude Code Installer

Installs and configures Claude Code to use MiniMax models via the Token Plan API.

## Prerequisites

- Linux or macOS
- Node.js 18+ (script installs via NVM if missing)
- MiniMax API key from https://platform.minimax.io/user-center/payment/token-plan

## Features

- Installs Claude Code via the official bootstrap script
- Supports region selection (International or China) with appropriate API endpoints
- Model selection: M2.7, M2.1, M1, or M1-80K

## Usage

```bash
git clone https://github.com/kuusuru/minimax-install-script.git
cd minimax-install-script
chmod +x install_minimax.sh
./install_minimax.sh
```

The script will prompt for:
1. Region (International or China)
2. Model (M2.7, M2.1, M1, M1-80K)
3. Billing type (Token Plan or Pay-As-You-Go)
4. API key

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
| MiniMax-M2.7 | Latest model, best for complex tasks |
| MiniMax-M2.1 | Stable model, good balance |
| MiniMax-M1 | Base model |
| MiniMax-M1-80K | Extended context base model |

## Uninstall

```bash
./uninstall_minimax.sh
```

Choose "MiniMax Config Only" to keep Claude Code installed.
