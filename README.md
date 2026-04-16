# MiniMax Claude Code Installer

Installs and configures [Claude Code](https://claude.ai/code) to use MiniMax models via the Token Plan API.
Supports **Linux/macOS** (Bash) and **Windows** (PowerShell).

## Prerequisites

| Platform | Requirements |
|---|---|
| Linux / macOS | Bash, Node.js 18+ (auto-installed via NVM if missing) |
| Windows | PowerShell 5.1+, Node.js 18+ (auto-installed via nvm-windows if missing) |

Get your API key:
- **Token Plan:** https://platform.minimax.io/user-center/payment/token-plan
- **Pay-As-You-Go:** https://platform.minimax.io/user-center/basic-information/interface-key

## Features

- Installs Claude Code via the official bootstrap script (Linux/macOS) or npm (Windows)
- Region selection: International (`api.minimax.io`) or China (`api.minimaxi.com`)
- Model selection: M2.7, M2.7-hs, M2.5, M2.5-hs, M2.1, M2, or Custom
- Billing type: Token Plan or Pay-As-You-Go
- Optional MiniMax MCP server (`web_search`, `understand_image`)
- Merges config into existing `settings.json` — preserves other tool settings
- Secure: all user input (API key, model, URL) passed via environment variables to Node.js

## Usage

### Linux / macOS

```bash
git clone https://github.com/kuusuru/minimax-install-script.git
cd minimax-install-script
chmod +x install_minimax.sh
./install_minimax.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/kuusuru/minimax-install-script.git
cd minimax-install-script

# Allow local scripts to run (one-time)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\install_minimax.ps1
```

The script will prompt for:
1. Region (International or China)
2. Model (M2.7, M2.7-hs, M2.5, M2.5-hs, M2.1, M2, or Custom)
3. Billing type (Token Plan or Pay-As-You-Go)
4. API key
5. Optional MCP server installation (`web_search`, `understand_image`)

After installation:

**Linux/macOS:**
```bash
cd /your/project
source ~/.bashrc  # or open a new terminal
claude
```

**Windows:**
```powershell
# Open a NEW terminal window (required for PATH to update)
cd C:\your\project
claude
```

## API Endpoints

| Region | Endpoint |
|---|---|
| International | `https://api.minimax.io/anthropic` |
| China (Mainland) | `https://api.minimaxi.com/anthropic` |

## Models

| Model | Description |
|---|---|
| MiniMax-M2.7 | ~50 TPS normal, 100 TPS off-peak |
| MiniMax-M2.7-highspeed | ~100 TPS sustained (HS plan only) |
| MiniMax-M2.5 | Balanced performance |
| MiniMax-M2.5-highspeed | Premium speed tier (HS plan only) |
| MiniMax-M2.1 | Stable model |
| MiniMax-M2 | Base model |
| Custom | Enter any model name manually |

> **Note:** `-highspeed` models require an HS-tier subscription (Plus–HS, Max–HS, or Ultra–HS). Standard plans use the base M2.7.

## MCP Server (Optional)

MiniMax Token Plan MCP provides two exclusive tools for use inside Claude Code:

- **`web_search`** — Search the web for current information
- **`understand_image`** — Analyze and understand image content

Requires [uv](https://astral.sh/uv) (installed automatically if missing). The MCP entry is added to `~/.claude/settings.json` (`%USERPROFILE%\.claude\settings.json` on Windows). Restart Claude Code after installation for MCP tools to appear.

## Uninstall

**Linux/macOS:**
```bash
./uninstall_minimax.sh
```

**Windows:**
```powershell
.\uninstall_minimax.ps1
```

Choose **"MiniMax Config Only"** to keep Claude Code installed but remove MiniMax settings.
Choose **"Full Uninstall"** to remove Claude Code entirely.

> **Note:** Neither uninstaller removes Node.js, NVM/nvm-windows, or shell profile entries added during installation. Remove those manually if needed.
