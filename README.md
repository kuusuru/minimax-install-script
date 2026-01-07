# MiniMax Claude Code Installer

Automated installer for using MiniMax-M2.1 with Claude Code, adapted for the MiniMax Coding Plan.

## Credits

This installer is adapted from:
- [MiniMax AI Coding Tools Documentation](https://platform.minimax.io/docs/guides/text-ai-coding-tools)
- Original script from Z.ai

## Prerequisites

- **Operating System:** Linux or macOS
- **Node.js:** Version 18 or higher (will be installed automatically if missing)
- **MiniMax API Key:** Get your Coding Plan API key at https://platform.minimax.io/user-center/payment/coding-plan

## Usage

```bash
chmod +x install_minimax.sh
./install_minimax.sh
```

The script will:
1. Check/install Node.js via NVM
2. Install/upgrade Claude Code
3. Configure Claude Code with your MiniMax credentials
4. Set all model variants to use MiniMax-M2.1

## About Coding Plan

This installer is specifically adapted for users with a **MiniMax Coding Plan**. If you have a Pay-As-You-Go platform key, this script will still work - just select option 2 when prompted for your billing type.

## After Installation

Run `claude` in your terminal to start using Claude Code with MiniMax-M2.1.

## Troubleshooting

If you encounter issues, ensure you've cleared any existing Anthropic environment variables:
```bash
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_BASE_URL
```
