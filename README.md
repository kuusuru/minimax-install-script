# MiniMax Claude Code Installer

Automated installer for using MiniMax-M2.1 with Claude Code, adapted for the MiniMax Coding Plan.

## Credits

This installer is adapted from:
- [MiniMax AI Coding Tools Documentation](https://platform.minimax.io/docs/guides/text-ai-coding-tools)
- Original script from Z.ai

## Prerequisites

- **Operating System:** Linux or macOS
- **Node.js:** Version 18 or higher (will be installed automatically if missing)
- **MiniMax API Key:** Get from https://platform.minimax.io/user-center/payment/coding-plan

> **Note:** This installer is specifically adapted for the MiniMax Coding Plan. If you have a Pay-As-You-Go platform key, you can still use it - just select option 2 when prompted for your billing type.

## Installation

### 1. Clone and run the installer

```bash
# Clone the repository
git clone https://github.com/kuusuru/minimax-install-script.git

# Navigate to the directory
cd minimax-install-script

# Make the installer executable
chmod +x install_minimax.sh

# Run the installer
./install_minimax.sh
```

The installer will:
1. Check/install Node.js via NVM (if not present)
2. Install Claude Code (if not already installed)
3. Configure Claude Code with your MiniMax credentials
4. Set all model variants to use MiniMax-M2.1

### 2. Get your MiniMax API Key

When prompted, select your billing type and get your API key from:
- **Coding Plan**: https://platform.minimax.io/user-center/payment/coding-plan
- **Pay-As-You-Go**: https://platform.minimax.io/user-center/basic-information/interface-key

### 3. Start using Claude Code

After installation, run:
```bash
claude
```

## Uninstallation

### 1. Clone and run the uninstaller (if not already cloned)

```bash
# Clone the repository (if not already cloned)
git clone https://github.com/kuusuru/minimax-install-script.git

# Navigate to the directory
cd minimax-install-script

# Make the uninstaller executable
chmod +x uninstall_minimax.sh

# Run the uninstaller
./uninstall_minimax.sh
```

The uninstaller offers two options:

### 1) Full Uninstall
Removes EVERYTHING:
- Claude Code application
- All configuration files (`.claude/`, `.mcp.json`, etc.)

Use this to completely remove Claude Code from your system.

### 2) MiniMax Config Only (Safer)
Removes only MiniMax settings:
- `~/.claude/settings.json`
- `~/.claude.json`
- Project-specific `.claude/` and `.mcp.json`

Keeps Claude Code installed. Use this to just reconfigure MiniMax.

Note: Node.js and NVM are never removed by this script.

## Adapting Existing Installation

If Claude Code is already installed, the installer will detect it and ask:

```
Claude Code is already installed on this system.

Do you want to adapt your existing installation to use MiniMax?

  1) Yes - Configure MiniMax (keeps Claude Code, updates settings)
  2) No - Exit (use uninstall_minimax.sh for full removal)
```

Select option 1 to configure your existing Claude Code to use MiniMax without reinstallation.

## Troubleshooting

If you encounter issues, ensure you've cleared any existing Anthropic environment variables:
```bash
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_BASE_URL
```
