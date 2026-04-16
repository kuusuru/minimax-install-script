#Requires -Version 5.1
<#
.SYNOPSIS
    MiniMax Claude Code Installer (Token Plan Edition) - Windows

.DESCRIPTION
    Installs and configures Claude Code to use MiniMax models on Windows.
    Adapted from:
      - https://platform.minimax.io/docs/token-plan/claude-code
      - https://downloads.claude.ai/claude-code-releases/bootstrap.sh
      - Original script from Z.ai

.NOTES
    Prerequisites:
      - Windows 10/11 with PowerShell 5.1 or later
      - Node.js 18+ (script installs via nvm-windows if missing)
      - MiniMax Token Plan API Key

    Run with:
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
      .\install_minimax.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ========================
#     Define Constants
# ========================
$NODE_MIN_VERSION  = 18
$NODE_INSTALL_VERSION = '22'
$CLAUDE_PACKAGE    = '@anthropic-ai/claude-code'
$CONFIG_DIR        = Join-Path $env:USERPROFILE '.claude'
$TOKEN_PLAN_URL    = 'https://platform.minimax.io/user-center/payment/token-plan'
$PLATFORM_URL      = 'https://platform.minimax.io/user-center/basic-information/interface-key'
$NVM_WINDOWS_URL   = 'https://github.com/coreybutler/nvm-windows/releases/latest/download/nvm-setup.exe'

# ========================
#     Logging Helpers
# ========================
function Log-Info  { param([string]$Msg) Write-Host ">> $Msg" -ForegroundColor Cyan }
function Log-OK    { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Log-Error { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Log-Warn  { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

# ========================
#     Utility
# ========================
function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

# Download a file safely to a temp path, return the temp path
function Download-Temp {
    param([string]$Url, [string]$Ext = 'tmp')
    $tmp = [System.IO.Path]::GetTempFileName()
    $tmpRenamed = [System.IO.Path]::ChangeExtension($tmp, $Ext)
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmpRenamed -UseBasicParsing -TimeoutSec 120
    } catch {
        Remove-Item $tmpRenamed -ErrorAction SilentlyContinue
        throw "Download failed from $Url : $_"
    }
    return $tmpRenamed
}

# Refresh PATH in current session from registry
function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path    = "$machinePath;$userPath"
}

# ========================
#     Region Selection
# ========================
function Select-Region {
    while ($true) {
        Write-Host "Select your region:"
        Write-Host "  1) International (outside China) - uses api.minimax.io"
        Write-Host "  2) China (Mainland)              - uses api.minimaxi.com"
        Write-Host ''
        $choice = Read-Host 'Enter choice (1 or 2)'
        Write-Host ''
        switch ($choice) {
            '1' {
                $script:API_BASE_URL = 'https://api.minimax.io/anthropic'
                Log-Info "Selected International endpoint: $script:API_BASE_URL"
                return
            }
            '2' {
                $script:API_BASE_URL = 'https://api.minimaxi.com/anthropic'
                Log-Info "Selected China endpoint: $script:API_BASE_URL"
                return
            }
            default { Log-Error 'Invalid choice. Please enter 1 or 2.' }
        }
    }
}

# ========================
#     Model Selection
# ========================
function Select-Model {
    while ($true) {
        Write-Host 'Select your MiniMax model:'
        Write-Host '  1) MiniMax-M2.7           (~50 TPS normal, 100 TPS off-peak)'
        Write-Host '  2) MiniMax-M2.7-highspeed (~100 TPS sustained, HS plan only)'
        Write-Host '  3) MiniMax-M2.5'
        Write-Host '  4) MiniMax-M2.5-highspeed (HS plan only)'
        Write-Host '  5) MiniMax-M2.1'
        Write-Host '  6) MiniMax-M2'
        Write-Host '  7) Custom (enter manually)'
        Write-Host ''
        Write-Host "Note: '-highspeed' models require an HS-tier subscription."
        Write-Host '      Available only with: Plus-HS, Max-HS, or Ultra-HS.'
        Write-Host '      Standard plans (Starter, Plus, Max) use the base M2.7.'
        Write-Host ''
        $choice = Read-Host 'Enter choice (1-7)'
        Write-Host ''
        switch ($choice) {
            '1' { $script:MINIMAX_MODEL = 'MiniMax-M2.7';           Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '2' { $script:MINIMAX_MODEL = 'MiniMax-M2.7-highspeed'; Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '3' { $script:MINIMAX_MODEL = 'MiniMax-M2.5';           Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '4' { $script:MINIMAX_MODEL = 'MiniMax-M2.5-highspeed'; Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '5' { $script:MINIMAX_MODEL = 'MiniMax-M2.1';           Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '6' { $script:MINIMAX_MODEL = 'MiniMax-M2';             Log-Info "Selected model: $script:MINIMAX_MODEL"; return }
            '7' {
                $custom = Read-Host 'Enter custom model name'
                Write-Host ''
                if ([string]::IsNullOrWhiteSpace($custom)) {
                    Log-Error 'Model name cannot be empty.'
                } else {
                    $script:MINIMAX_MODEL = $custom
                    Log-Info "Selected custom model: $script:MINIMAX_MODEL"
                    return
                }
            }
            default { Log-Error 'Invalid choice. Please enter 1-7.' }
        }
    }
}

# ========================
#     Billing Type
# ========================
function Select-KeyType {
    while ($true) {
        Write-Host 'Select your MiniMax billing type:'
        Write-Host '  1) Token Plan (fixed monthly fee, includes usage)'
        Write-Host '  2) Pay-As-You-Go (pay per usage)'
        Write-Host ''
        $choice = Read-Host 'Enter choice (1 or 2)'
        Write-Host ''
        switch ($choice) {
            '1' {
                Write-Host "  Get your Token Plan API Key at: $TOKEN_PLAN_URL"
                $script:BILLING_TYPE = 'token'
                return
            }
            '2' {
                Write-Host "  Get your Platform API Key at: $PLATFORM_URL"
                $script:BILLING_TYPE = 'payg'
                return
            }
            default { Log-Error 'Invalid choice. Please enter 1 or 2.' }
        }
    }
}

# ========================
#     Node.js
# ========================
function Get-NodeMajorVersion {
    try {
        $ver = & node --version 2>$null
        if ($ver -match 'v(\d+)') { return [int]$Matches[1] }
    } catch {}
    return 0
}

function Install-NodeJS {
    Log-Info 'Node.js not found or outdated. Installing via nvm-windows...'
    Log-Warn 'nvm-windows requires a GUI installer. Downloading now...'

    try {
        $nvmInstaller = Download-Temp -Url $NVM_WINDOWS_URL -Ext 'exe'
        Log-Info 'Running nvm-windows installer (follow the prompts)...'
        Start-Process -FilePath $nvmInstaller -Wait
        Remove-Item $nvmInstaller -ErrorAction SilentlyContinue
    } catch {
        Log-Error "Failed to download/install nvm-windows: $_"
        Log-Warn 'Please install Node.js 18+ manually from https://nodejs.org and re-run this script.'
        exit 1
    }

    # Refresh PATH so nvm is available
    Refresh-Path

    if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
        Log-Warn 'nvm-windows installed but not yet in PATH.'
        Log-Warn 'Please open a NEW PowerShell window and re-run this script.'
        exit 1
    }

    Log-Info "Installing Node.js $NODE_INSTALL_VERSION via nvm..."
    & nvm install $NODE_INSTALL_VERSION
    & nvm use $NODE_INSTALL_VERSION
    Refresh-Path
}

function Check-NodeJS {
    Refresh-Path
    $major = Get-NodeMajorVersion
    if ($major -ge $NODE_MIN_VERSION) {
        Log-OK "Node.js v$(& node --version) detected."
        return
    }
    Install-NodeJS
    # Re-check after install
    Refresh-Path
    $major = Get-NodeMajorVersion
    if ($major -lt $NODE_MIN_VERSION) {
        Log-Error "Node.js $NODE_MIN_VERSION+ is required but could not be installed automatically."
        Log-Warn 'Please install Node.js manually from https://nodejs.org and re-run this script.'
        exit 1
    }
    Log-OK "Node.js v$(& node --version) is ready."
}

# ========================
#     Claude Code
# ========================
function Check-ClaudeCode {
    Refresh-Path
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $ver = & claude --version 2>$null
        Log-OK "Claude Code is already installed: $ver"
        return $true
    }
    return $false
}

function Install-ClaudeCode {
    Log-Info 'Installing Claude Code via npm...'
    try {
        & npm install -g $CLAUDE_PACKAGE
        Refresh-Path
        Log-OK 'Claude Code installed successfully.'
    } catch {
        Log-Error "Failed to install Claude Code: $_"
        exit 1
    }
}

function Configure-ClaudeJson {
    # Sets hasCompletedOnboarding so Claude Code skips the auth prompt
    $filePath = Join-Path $env:USERPROFILE '.claude.json'
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $nodeScript = @"
const fs = require('fs');
const filePath = process.env.CLAUDE_JSON_PATH;
const tmpPath  = process.env.CLAUDE_JSON_TMP;
let data = {};
try { data = JSON.parse(fs.readFileSync(filePath, 'utf-8')); } catch (e) {}
data.hasCompletedOnboarding = true;
fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
"@
        $env:CLAUDE_JSON_PATH = $filePath
        $env:CLAUDE_JSON_TMP  = $tmp
        & node -e $nodeScript
        Move-Item -Force $tmp $filePath
    } catch {
        Log-Error "Failed to configure .claude.json: $_"
        Remove-Item $tmp -ErrorAction SilentlyContinue
        # Non-fatal — continue
    } finally {
        Remove-Item env:CLAUDE_JSON_PATH -ErrorAction SilentlyContinue
        Remove-Item env:CLAUDE_JSON_TMP  -ErrorAction SilentlyContinue
    }
}

# ========================
#     API Configuration
# ========================
function Configure-Claude {
    Log-Info 'Configuring Claude Code for MiniMax...'
    Write-Host ''

    Select-Region
    Write-Host ''
    Select-Model
    Write-Host ''
    Select-KeyType
    Write-Host ''

    # Read API key without echoing it
    $secureKey = Read-Host '  Paste your MiniMax API Key' -AsSecureString
    $apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                  [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey))
    Write-Host ''

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Log-Error 'API key is required.'
        exit 1
    }

    Ensure-Dir $CONFIG_DIR

    # Pass all user values via environment variables — no shell injection risk
    $env:MINIMAX_API_KEY      = $apiKey
    $env:MINIMAX_API_BASE_URL = $script:API_BASE_URL
    $env:MINIMAX_MODEL_NAME   = $script:MINIMAX_MODEL
    $settingsPath = Join-Path $CONFIG_DIR 'settings.json'
    $env:MINIMAX_SETTINGS_FILE = $settingsPath

    $nodeScript = @"
const fs   = require('fs');
const path = require('path');

const filePath = process.env.MINIMAX_SETTINGS_FILE;
let config = {};
try {
    if (fs.existsSync(filePath)) {
        config = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    }
} catch (e) {
    console.error('Warning: could not parse existing settings.json:', e.message);
}

if (!config.env) config.env = {};

const model = process.env.MINIMAX_MODEL_NAME;
config.env.ANTHROPIC_AUTH_TOKEN                    = process.env.MINIMAX_API_KEY;
config.env.ANTHROPIC_BASE_URL                      = process.env.MINIMAX_API_BASE_URL;
config.env.API_TIMEOUT_MS                          = '3000000';
config.env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1';
config.env.ANTHROPIC_MODEL                         = model;
config.env.ANTHROPIC_SMALL_FAST_MODEL              = model;
config.env.ANTHROPIC_DEFAULT_SONNET_MODEL          = model;
config.env.ANTHROPIC_DEFAULT_OPUS_MODEL            = model;
config.env.ANTHROPIC_DEFAULT_HAIKU_MODEL           = model;

fs.writeFileSync(filePath, JSON.stringify(config, null, 2), 'utf-8');
"@

    try {
        & node -e $nodeScript
        Log-OK "Settings saved to $settingsPath"
    } catch {
        Log-Error "Failed to write settings.json: $_"
        exit 1
    } finally {
        # Always clear sensitive values from environment
        Remove-Item env:MINIMAX_API_KEY       -ErrorAction SilentlyContinue
        Remove-Item env:MINIMAX_API_BASE_URL  -ErrorAction SilentlyContinue
        Remove-Item env:MINIMAX_MODEL_NAME    -ErrorAction SilentlyContinue
        Remove-Item env:MINIMAX_SETTINGS_FILE -ErrorAction SilentlyContinue
    }
}

# ========================
#     MCP Server (Optional)
# ========================
function Configure-McpServers {
    Log-Info 'Configuring MiniMax MCP servers...'

    $settingsPath = Join-Path $CONFIG_DIR 'settings.json'

    # Determine API host from selected region
    if ($script:API_BASE_URL -like '*minimaxi.com*') {
        $apiHost = 'https://api.minimaxi.com'
    } else {
        $apiHost = 'https://api.minimax.io'
    }

    # Export settings path BEFORE the first Node call that reads it
    $env:MINIMAX_SETTINGS_FILE = $settingsPath

    # Read API key from settings.json
    $readKeyScript = @"
const fs = require('fs');
try {
    const s = JSON.parse(fs.readFileSync(process.env.MINIMAX_SETTINGS_FILE, 'utf-8'));
    process.stdout.write(s.env && s.env.ANTHROPIC_AUTH_TOKEN ? s.env.ANTHROPIC_AUTH_TOKEN : '');
} catch (e) { process.stdout.write(''); }
"@
    $apiKey = & node -e $readKeyScript 2>$null

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        Log-Info 'No API key found in settings. Skipping MCP server configuration.'
        Remove-Item env:MINIMAX_SETTINGS_FILE -ErrorAction SilentlyContinue
        return
    }

    $env:MINIMAX_API_KEY  = $apiKey
    $env:MINIMAX_API_HOST = $apiHost

    $mcpScript = @"
const fs = require('fs');
const settingsPath = process.env.MINIMAX_SETTINGS_FILE;

let settings = {};
try {
    if (fs.existsSync(settingsPath)) {
        settings = JSON.parse(fs.readFileSync(settingsPath, 'utf-8'));
    }
} catch (e) {
    console.error('Warning: could not parse settings.json:', e.message);
}

if (!settings.mcpServers) settings.mcpServers = {};
settings.mcpServers.MiniMax = {
    command: 'uvx',
    args: ['minimax-coding-plan-mcp'],
    env: {
        MINIMAX_API_KEY:  process.env.MINIMAX_API_KEY,
        MINIMAX_API_HOST: process.env.MINIMAX_API_HOST
    }
};

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf-8');
"@

    try {
        & node -e $mcpScript
        Log-OK 'MiniMax MCP server configured.'
    } catch {
        Log-Error "Failed to configure MCP server: $_"
    } finally {
        Remove-Item env:MINIMAX_API_KEY       -ErrorAction SilentlyContinue
        Remove-Item env:MINIMAX_API_HOST      -ErrorAction SilentlyContinue
        Remove-Item env:MINIMAX_SETTINGS_FILE -ErrorAction SilentlyContinue
    }
}

function Install-McpServers {
    Write-Host ''
    Write-Host '=============================================='
    Write-Host '   MiniMax MCP Server (web_search, understand_image)'
    Write-Host '=============================================='
    Write-Host ''
    Write-Host 'Token Plan MCP provides two exclusive tools for coding:'
    Write-Host '  - web_search:      Search the web for current information'
    Write-Host '  - understand_image: Analyze and understand image content'
    Write-Host ''
    Write-Host 'The MCP server requires uv (Python package manager).'
    Write-Host ''

    $installMcp = Read-Host 'Install MiniMax MCP server? (y/N)'
    Write-Host ''

    if ($installMcp -notmatch '^[Yy]$') {
        Log-Info 'Skipping MCP server installation.'
        return
    }

    # Check for uv
    Refresh-Path
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Log-Info 'Installing uv (Python package manager)...'
        try {
            # Official uv Windows installer
            $uvInstallScript = (Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -UseBasicParsing).Content
            Invoke-Expression $uvInstallScript
            Refresh-Path
            # uv installs to %USERPROFILE%\.local\bin or %USERPROFILE%\.cargo\bin
            $env:Path = "$env:USERPROFILE\.local\bin;$env:USERPROFILE\.cargo\bin;$env:Path"
        } catch {
            Log-Error "Failed to install uv: $_"
            Log-Warn 'Please install uv manually from https://astral.sh/uv and re-run.'
            return
        }
    }

    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Log-Error 'uv was installed but is not in PATH. Please open a new terminal and re-run.'
        return
    }

    Log-OK 'uv is available.'

    # uvx runs packages on-the-fly; no separate install step needed.
    # The settings.json mcpServers entry tells Claude Code to launch it.
    Configure-McpServers
    Log-OK 'MiniMax MCP server ready (configured in settings.json).'
    Write-Host ''
    Write-Host 'Note: Restart Claude Code for MCP tools to appear.'
}

# ========================
#     Main
# ========================
function Main {
    Write-Host ''
    Write-Host '=============================================='
    Write-Host '   MiniMax Claude Code Installer'
    Write-Host '   (Token Plan Edition - Windows)'
    Write-Host '=============================================='
    Write-Host ''

    $script:SKIP_INSTALL = $false
    $script:API_BASE_URL  = ''
    $script:MINIMAX_MODEL = ''
    $script:BILLING_TYPE  = ''

    # Check if Claude Code is already installed
    if (Check-ClaudeCode) {
        Write-Host ''
        Log-Info 'Claude Code is already installed on this system.'
        Write-Host ''
        Write-Host 'Do you want to configure your existing installation for MiniMax?'
        Write-Host ''
        Write-Host '  1) Yes - Configure MiniMax (keeps Claude Code, updates settings)'
        Write-Host '  2) No  - Exit (use uninstall_minimax.ps1 for full removal)'
        Write-Host ''
        $choice = Read-Host 'Enter choice (1 or 2)'
        Write-Host ''

        if ($choice -ne '1') {
            Log-Info 'Exiting. Run .\uninstall_minimax.ps1 if you want to remove Claude Code.'
            exit 0
        }

        Log-Info 'Configuring your existing Claude Code for MiniMax...'
        $script:SKIP_INSTALL = $true
    }

    Check-NodeJS

    if (-not $script:SKIP_INSTALL) {
        Refresh-Path
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Install-ClaudeCode
        }
    }

    Configure-ClaudeJson
    Configure-Claude

    # MCP is offered only after Claude Code is fully installed and configured
    Install-McpServers

    Write-Host ''
    Log-OK 'MiniMax is ready!'
    Write-Host ''
    Write-Host 'IMPORTANT:'
    Write-Host '  - Open a NEW terminal window for PATH changes to take effect'
    Write-Host '  - Navigate to your project folder before running claude'
    Write-Host ''
    Write-Host 'To start Claude Code:'
    Write-Host '  cd C:\your\project'
    Write-Host '  claude'
    Write-Host ''
}

Main
