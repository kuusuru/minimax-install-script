#Requires -Version 5.1
<#
.SYNOPSIS
    MiniMax Claude Code Uninstaller - Windows

.DESCRIPTION
    Removes Claude Code and/or MiniMax configuration on Windows.

    WARNING: Please read the options below carefully before proceeding.

    This uninstaller offers TWO options:

    1) FULL UNINSTALL - Removes EVERYTHING:
       - Claude Code application (via npm)
       - All MiniMax configuration files
       - Project-specific Claude settings
       - All MCP configurations

       After this, Claude Code will be completely removed from your system.
       You can reinstall fresh using install_minimax.ps1

    2) MINIMAX CONFIG ONLY - Removes only MiniMax settings:
       - MiniMax env vars from %USERPROFILE%\.claude\settings.json
       - MiniMax mcpServers from settings.json
       - %USERPROFILE%\.claude.json
       - Project-specific .claude\ and .mcp.json

       Keeps Claude Code installed. Reconfigure by running install_minimax.ps1 again.

    NOTE: Neither option removes Node.js, nvm-windows, or any PATH changes
          made during installation. Remove those manually if needed.

.NOTES
    Run with:
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
      .\uninstall_minimax.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CONFIG_DIR = Join-Path $env:USERPROFILE '.claude'

# ========================
#     Logging Helpers
# ========================
function Log-Info  { param([string]$Msg) Write-Host "  * $Msg" -ForegroundColor Cyan }
function Log-OK    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Log-Error { param([string]$Msg) Write-Host "  [ERROR] $Msg" -ForegroundColor Red }
function Log-Warn  { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }

# Refresh PATH in current session from registry
function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path    = "$machinePath;$userPath"
}

# ========================
#     Verify Installation
# ========================
function Get-ClaudeLocation {
    Refresh-Path
    try {
        $path = (Get-Command claude -ErrorAction Stop).Source
        Log-Info "Claude Code found at: $path"
        return $path
    } catch {
        Log-Info 'Claude Code not found in PATH.'
        return ''
    }
}

# ========================
#     Remove MCP Config
# ========================
function Remove-McpConfig {
    param([string]$SettingsPath)
    if (-not (Test-Path $SettingsPath)) { return }

    $env:MINIMAX_SETTINGS_FILE = $SettingsPath
    $nodeScript = @"
const fs = require('fs');
const filePath = process.env.MINIMAX_SETTINGS_FILE;
try {
    const settings = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    if (settings.mcpServers) {
        delete settings.mcpServers.MiniMax;
        if (Object.keys(settings.mcpServers).length === 0) delete settings.mcpServers;
    }
    fs.writeFileSync(filePath, JSON.stringify(settings, null, 2), 'utf-8');
} catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
}
"@
    try {
        & node -e $nodeScript
        Log-OK 'Removed MiniMax MCP config from settings.json'
    } catch {
        Log-Error "Failed to update settings.json: $_"
    } finally {
        Remove-Item env:MINIMAX_SETTINGS_FILE -ErrorAction SilentlyContinue
    }
}

# ========================
#     Full Uninstall
# ========================
function Invoke-FullUninstall {
    Write-Host ''
    Log-Info 'Starting FULL UNINSTALL...'
    Write-Host ''
    Log-Info 'This will remove:'
    Write-Host '  - Claude Code application'
    Write-Host '  - All configuration files'
    Write-Host '  - Project-specific settings'
    Write-Host ''
    Write-Host 'NOTE: Node.js and nvm-windows will NOT be removed.'
    Write-Host '      PATH changes will NOT be reverted automatically.'
    Write-Host ''

    $confirm = Read-Host "Type 'yes' to confirm full uninstall"
    Write-Host ''

    if ($confirm -ne 'yes') {
        Log-Info 'Cancelled.'
        exit 0
    }

    # 1. Uninstall Claude Code via npm
    Log-Info 'Uninstalling Claude Code via npm...'
    Refresh-Path
    try {
        & npm uninstall -g @anthropic-ai/claude-code 2>$null
        Log-OK 'Claude Code uninstalled via npm.'
    } catch {
        Log-Warn 'Claude Code not found via npm (may have been installed differently).'
    }

    # 2. Remove MCP config entry
    $settingsPath = Join-Path $CONFIG_DIR 'settings.json'
    Log-Info 'Removing MiniMax MCP configuration...'
    Remove-McpConfig -SettingsPath $settingsPath

    # 3. Remove configuration directories
    Log-Info 'Removing configuration files...'
    if (Test-Path $CONFIG_DIR) {
        Remove-Item -Recurse -Force $CONFIG_DIR
        Log-OK "Removed $CONFIG_DIR"
    }

    $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
    if (Test-Path $claudeJson) {
        Remove-Item -Force $claudeJson
        Log-OK "Removed $claudeJson"
    }

    # 4. Remove project-specific settings (current directory)
    if (Test-Path '.claude') {
        Remove-Item -Recurse -Force '.claude'
        Log-OK 'Removed .claude\ (project settings)'
    }
    if (Test-Path '.mcp.json') {
        Remove-Item -Force '.mcp.json'
        Log-OK 'Removed .mcp.json'
    }

    # 5. Verify removal
    Refresh-Path
    Log-Info 'Verifying removal...'
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Log-Error "Claude Code may still be installed at: $((Get-Command claude).Source)"
        Log-Warn 'You may need to manually remove it.'
    } else {
        Log-OK 'Claude Code is no longer in PATH.'
    }

    Write-Host ''
    Log-OK 'FULL UNINSTALL COMPLETE!'
    Write-Host ''
    Write-Host 'Open a new terminal to clear any cached PATH entries.'
    Write-Host 'To reinstall, run: .\install_minimax.ps1'
    Write-Host ''
}

# ========================
#     Config-Only Uninstall
# ========================
function Invoke-ConfigOnlyUninstall {
    Write-Host ''
    Log-Info 'Removing MiniMax configuration only...'
    Write-Host ''
    Log-Info 'This will remove:'
    Write-Host "  - MiniMax env vars from $CONFIG_DIR\settings.json"
    Write-Host "  - MiniMax mcpServers from $CONFIG_DIR\settings.json"
    Write-Host "  - $env:USERPROFILE\.claude.json"
    Write-Host '  - Project-specific .claude\ and .mcp.json'
    Write-Host ''
    Log-Info 'Claude Code and other MCP servers will remain configured.'
    Write-Host ''

    $confirm = Read-Host 'Continue? (y/N)'
    Write-Host ''

    if ($confirm -notmatch '^[Yy]$') {
        Log-Info 'Cancelled.'
        exit 0
    }

    # 1. Remove MiniMax-specific env vars and MCP from settings.json
    $settingsPath = Join-Path $CONFIG_DIR 'settings.json'
    if (Test-Path $settingsPath) {
        $env:MINIMAX_SETTINGS_FILE = $settingsPath
        $nodeScript = @"
const fs = require('fs');
const filePath = process.env.MINIMAX_SETTINGS_FILE;
try {
    const settings = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    if (settings.env) {
        const keys = [
            'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_BASE_URL', 'API_TIMEOUT_MS',
            'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC', 'ANTHROPIC_MODEL',
            'ANTHROPIC_SMALL_FAST_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL',
            'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL'
        ];
        keys.forEach(k => delete settings.env[k]);
        if (Object.keys(settings.env).length === 0) delete settings.env;
    }
    if (settings.mcpServers) {
        delete settings.mcpServers.MiniMax;
        if (Object.keys(settings.mcpServers).length === 0) delete settings.mcpServers;
    }
    fs.writeFileSync(filePath, JSON.stringify(settings, null, 2), 'utf-8');
} catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
}
"@
        try {
            & node -e $nodeScript
            Log-OK "Removed MiniMax config from $settingsPath"
        } catch {
            Log-Error "Failed to update settings.json: $_"
        } finally {
            Remove-Item env:MINIMAX_SETTINGS_FILE -ErrorAction SilentlyContinue
        }
    } else {
        Log-Info 'No settings.json found.'
    }

    # 2. Remove .claude.json
    $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
    if (Test-Path $claudeJson) {
        Remove-Item -Force $claudeJson
        Log-OK "Removed $claudeJson"
    }

    # 3. Remove project-specific settings
    if (Test-Path '.claude') {
        Remove-Item -Recurse -Force '.claude'
        Log-OK 'Removed .claude\ (project settings)'
    }
    if (Test-Path '.mcp.json') {
        Remove-Item -Force '.mcp.json'
        Log-OK 'Removed .mcp.json'
    }

    Write-Host ''
    Log-OK 'MINIMAX CONFIGURATION REMOVED!'
    Write-Host ''
    Write-Host 'Claude Code is still installed.'
    Write-Host 'To reconfigure MiniMax, run: .\install_minimax.ps1'
    Write-Host ''
}

# ========================
#     Main
# ========================
function Main {
    Write-Host ''
    Write-Host '=============================================='
    Write-Host '   MiniMax Claude Code Uninstaller (Windows)'
    Write-Host '=============================================='
    Write-Host ''
    Log-Info 'Please read the script header comments before proceeding.'
    Write-Host ''

    Get-ClaudeLocation | Out-Null

    Write-Host ''
    Write-Host 'Select uninstall option:'
    Write-Host ''
    Write-Host '  1) FULL UNINSTALL     - Removes Claude Code and all config'
    Write-Host '  2) MiniMax Config Only - Keeps Claude Code installed'
    Write-Host '  3) Cancel'
    Write-Host ''

    $choice = Read-Host 'Enter choice (1, 2, or 3)'
    Write-Host ''

    switch ($choice) {
        '1' { Invoke-FullUninstall }
        '2' { Invoke-ConfigOnlyUninstall }
        '3' { Log-Info 'Cancelled.'; exit 0 }
        default {
            Log-Error 'Invalid choice. Please enter 1, 2, or 3.'
            exit 1
        }
    }
}

Main
