#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('install', 'uninstall', 'help')]
    [string]$Action = 'help'
)

# UTF-8 encoding initialization (PowerShell 5.1 compatibility)
try {
  $script:utf8NoBom = [System.Text.UTF8Encoding]::new($false)
} catch {
  $script:utf8NoBom = [System.Text.Encoding]::UTF8
}
try { $OutputEncoding = $script:utf8NoBom } catch {}
try { [Console]::OutputEncoding = $script:utf8NoBom } catch {}
try { [Console]::InputEncoding = $script:utf8NoBom } catch {}
try { chcp 65001 | Out-Null } catch {}
$ErrorActionPreference = 'Stop'

# install.ps1 - CCA Windows Installation Script
# Automated installation for Claude Code AutoFlow on Windows

# Global Variables
$INSTALL_DIR = "$env:LOCALAPPDATA\cca"
$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$CONFIG_DIR = "$env:APPDATA\cca"
$SCRIPT_DIR = $PSScriptRoot

$AUTOFLOW_SKILLS = @('tr', 'tp', 'dual-design', 'file-op', 'ask-codex', 'ask-gemini', 'roles', 'review', 'mode-switch', 'docs')
$AUTOFLOW_COMMANDS = @('tr.md', 'tp.md', 'dual-design.md', 'file-op.md', 'ask-codex.md', 'ask-gemini.md', 'roles.md', 'review.md', 'mode-switch.md', 'auto.md')

# Helper Functions
function Write-Info { param([string]$Message) Write-Host "[+] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host "[-] $Message" -ForegroundColor Red }
function Write-Blue { param([string]$Message) Write-Host "[*] $Message" -ForegroundColor Cyan }

function Write-AllTextUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Show-Help {
@"
CCA Windows Installation Script

Usage:
  .\install.ps1 install      Install or update CCA
  .\install.ps1 uninstall    Uninstall CCA
  .\install.ps1 help         Show this help

Installation Directories:
  Install Dir:  $INSTALL_DIR
  Config Dir:   $CONFIG_DIR
  Claude Dir:   $CLAUDE_DIR

Examples:
  # Install CCA
  powershell -ExecutionPolicy Bypass -File .\install.ps1 install

  # Or simply
  .\install.ps1 install

  # Uninstall CCA
  .\install.ps1 uninstall
"@ | Write-Host
}

function Add-ToPath {
    param([string]$Directory)

    # Read current user PATH
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    # Check if already exists
    $paths = $userPath -split ';' | Where-Object { $_ }
    if ($paths -contains $Directory) {
        Write-Warn "Directory already in PATH: $Directory"
        return
    }

    # Add to PATH
    $newPath = if ($userPath) { "$userPath;$Directory" } else { $Directory }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

    # Update current session
    $env:Path = "$env:Path;$Directory"

    Write-Info "Added to PATH: $Directory"
}

function Remove-FromPath {
    param([string]$Directory)

    # Read current user PATH
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    # Remove target directory
    $paths = $userPath -split ';' | Where-Object { $_ -and $_ -ne $Directory }
    $newPath = $paths -join ';'

    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

    # Update current session
    $env:Path = ($env:Path -split ';' | Where-Object { $_ -ne $Directory }) -join ';'

    Write-Info "Removed from PATH: $Directory"
}

function Get-VersionInfo {
    $version = @{
        Version = "1.7.0"
        Commit = "unknown"
        Date = (Get-Date -Format "yyyy-MM-dd")
    }

    # Method 1: From git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            Push-Location $SCRIPT_DIR
            $gitCommit = git rev-parse --short HEAD 2>$null
            $gitDate = git log -1 --format=%cd --date=short 2>$null

            if ($gitCommit) {
                $version.Commit = $gitCommit
                if ($gitDate) { $version.Date = $gitDate }
            }
            Pop-Location
        } catch {
            Pop-Location
        }
    }

    # Method 2: From environment variables
    if ($env:CCA_VERSION) { $version.Version = $env:CCA_VERSION }
    if ($env:CCA_COMMIT) { $version.Commit = $env:CCA_COMMIT }
    if ($env:CCA_DATE) { $version.Date = $env:CCA_DATE }

    # Method 3: From GitHub API (fallback)
    if ($version.Commit -eq "unknown") {
        try {
            $apiUrl = "https://api.github.com/repos/TachiKuma/claude_code_autoflow/commits/main"
            $ProgressPreference = 'SilentlyContinue'
            $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'cca-installer' } -ErrorAction Stop
            if ($response.sha) {
                $version.Commit = $response.sha.Substring(0, 7)
                if ($response.commit.committer.date) {
                    $version.Date = $response.commit.committer.date.Substring(0, 10)
                }
            }
        } catch {
            # Silent fail, use defaults
        }
    }

    return $version
}

function Inject-Version {
    param(
        [string]$SourceFile,
        [string]$TargetFile
    )

    if (-not (Test-Path $SourceFile)) {
        Write-Warn "Source file not found: $SourceFile"
        return
    }

    # Get version info
    $versionInfo = Get-VersionInfo

    # Read source file
    $content = Get-Content $SourceFile -Raw -Encoding UTF8

    # Replace version placeholders
    $content = $content -replace '\$VERSION\s*=\s*''[^'']*''', "`$VERSION = '$($versionInfo.Version)'"
    $content = $content -replace '\$GIT_COMMIT\s*=\s*''[^'']*''', "`$GIT_COMMIT = '$($versionInfo.Commit)'"
    $content = $content -replace '\$GIT_DATE\s*=\s*''[^'']*''', "`$GIT_DATE = '$($versionInfo.Date)'"

    # Write to target file
    Write-AllTextUtf8NoBom -Path $TargetFile -Text $content

    Write-Info "Version injected: $($versionInfo.Version) ($($versionInfo.Commit))"
}

function Create-WrapperFiles {
    $batContent = @"
@echo off
setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"

REM Call PowerShell to execute cca.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%cca.ps1" %*

REM Pass exit code
exit /b %ERRORLEVEL%
"@

    $batPath = Join-Path $INSTALL_DIR "cca.bat"
    $cmdPath = Join-Path $INSTALL_DIR "cca.cmd"

    Write-AllTextUtf8NoBom -Path $batPath -Text $batContent
    Write-AllTextUtf8NoBom -Path $cmdPath -Text $batContent

    Write-Info "Created wrapper: cca.bat"
    Write-Info "Created wrapper: cca.cmd"
}

function Install-Skills {
    $skillsSource = Join-Path $SCRIPT_DIR "claude_source\skills"
    $skillsTarget = Join-Path $CLAUDE_DIR "skills"

    if (-not (Test-Path $skillsSource)) {
        Write-Warn "Skills source directory not found: $skillsSource"
        return
    }

    # Create target directory
    New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null

    $installedCount = 0
    foreach ($skill in $AUTOFLOW_SKILLS) {
        $sourcePath = Join-Path $skillsSource $skill
        $targetPath = Join-Path $skillsTarget $skill

        if (Test-Path $sourcePath) {
            # Remove existing and copy
            if (Test-Path $targetPath) {
                Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
            $installedCount++
            Write-Host "  [OK] $skill" -ForegroundColor Green
        } else {
            Write-Warn "  [SKIP] $skill (source not found)"
        }
    }

    Write-Blue "Installed $installedCount skills"
}

function Install-Commands {
    $commandsSource = Join-Path $SCRIPT_DIR "claude_source\commands"
    $commandsTarget = Join-Path $CLAUDE_DIR "commands"

    if (-not (Test-Path $commandsSource)) {
        Write-Warn "Commands source directory not found: $commandsSource"
        return
    }

    # Create target directory
    New-Item -ItemType Directory -Path $commandsTarget -Force | Out-Null

    $installedCount = 0
    foreach ($command in $AUTOFLOW_COMMANDS) {
        $sourcePath = Join-Path $commandsSource $command
        $targetPath = Join-Path $commandsTarget $command

        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $targetPath -Force
            $installedCount++
            Write-Host "  [OK] $command" -ForegroundColor Green
        } else {
            Write-Warn "  [SKIP] $command (source not found)"
        }
    }

    Write-Blue "Installed $installedCount commands"
}

function Initialize-RolesConfig {
    $configPath = Join-Path $CONFIG_DIR "roles.json"
    $templatePath = Join-Path $SCRIPT_DIR "claude_source\templates\roles.json"

    # Create config directory
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null

    # Check if config already exists
    if (Test-Path $configPath) {
        Write-Warn "System roles.json already exists: $configPath"
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
            Write-Blue "Keeping existing configuration"
            return
        }
    }

    # Copy template or create default
    if (Test-Path $templatePath) {
        Copy-Item -Path $templatePath -Destination $configPath -Force
        Write-Info "Initialized system roles.json: $configPath"
    } else {
        # Create default configuration
        $defaultRoles = @{
            executor = "codex"
            searcher = "codex"
            git_manager = "codex"
        }
        $defaultRoles | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
        Write-Info "Created default roles.json: $configPath"
    }
}

function Install-CCA {
    Write-Host "`n=== CCA Windows Installation ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if already installed
    $update = $false
    if (Test-Path $INSTALL_DIR) {
        Write-Warn "CCA is already installed, will update..."
        $update = $true
    } else {
        Write-Info "Installing CCA..."
    }

    # Step 1: Create installation directory
    Write-Host "`n[1/9] Creating installation directory..." -ForegroundColor Cyan
    try {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force -ErrorAction Stop | Out-Null
        Write-Info "Install directory: $INSTALL_DIR"
    } catch {
        Write-Err "Failed to create installation directory: $_"
        exit 1
    }

    # Step 2: Copy core files
    Write-Host "`n[2/9] Copying core files..." -ForegroundColor Cyan
    $coreFiles = @('cca.ps1', 'cca-roles-hook.ps1')
    foreach ($file in $coreFiles) {
        $sourcePath = Join-Path $SCRIPT_DIR $file
        $targetPath = Join-Path $INSTALL_DIR $file

        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $targetPath -Force
            Write-Info "Copied: $file"
        } else {
            Write-Warn "Source file not found: $file"
        }
    }

    # Step 3: Create wrapper files
    Write-Host "`n[3/9] Creating wrapper files..." -ForegroundColor Cyan
    Create-WrapperFiles

    # Step 4: Inject version info
    Write-Host "`n[4/9] Injecting version information..." -ForegroundColor Cyan
    $ccaSource = Join-Path $SCRIPT_DIR "cca.ps1"
    $ccaTarget = Join-Path $INSTALL_DIR "cca.ps1"
    Inject-Version -SourceFile $ccaSource -TargetFile $ccaTarget

    # Step 5: Install skills
    Write-Host "`n[5/9] Installing skills..." -ForegroundColor Cyan
    Install-Skills

    # Step 6: Install commands
    Write-Host "`n[6/9] Installing commands..." -ForegroundColor Cyan
    Install-Commands

    # Step 7: Configure PATH
    Write-Host "`n[7/9] Configuring environment variables..." -ForegroundColor Cyan
    Add-ToPath -Directory $INSTALL_DIR

    # Step 8: Initialize roles config
    Write-Host "`n[8/9] Initializing roles configuration..." -ForegroundColor Cyan
    Initialize-RolesConfig

    # Step 9: Done
    Write-Host "`n[9/9] Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Info "CCA has been successfully installed!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart your terminal or run:" -ForegroundColor Yellow
    Write-Host "     `$env:Path = [System.Environment]::GetEnvironmentVariable('Path','User')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Verify installation:" -ForegroundColor Yellow
    Write-Host "     cca --version" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Configure a project:" -ForegroundColor Yellow
    Write-Host "     cd your-project" -ForegroundColor Gray
    Write-Host "     cca add ." -ForegroundColor Gray
    Write-Host ""
}

function Uninstall-CCA {
    Write-Host "`n=== CCA Windows Uninstallation ===" -ForegroundColor Cyan
    Write-Host ""

    # Check if installed
    if (-not (Test-Path $INSTALL_DIR)) {
        Write-Warn "CCA is not installed at: $INSTALL_DIR"
        return
    }

    Write-Warn "This will remove CCA from your system."
    Write-Host ""

    # Step 1: Remove from PATH
    Write-Host "[1/3] Removing from PATH..." -ForegroundColor Cyan
    Remove-FromPath -Directory $INSTALL_DIR

    # Step 2: Ask about config deletion
    Write-Host "`n[2/3] Configuration cleanup..." -ForegroundColor Cyan
    Write-Host "Do you want to delete the following?" -ForegroundColor Yellow
    Write-Host "  - $CLAUDE_DIR (skills and commands)"
    Write-Host "  - $CONFIG_DIR (system configuration)"
    $deleteConfig = Read-Host "Delete configuration? (y/N)"

    if ($deleteConfig -eq 'y' -or $deleteConfig -eq 'Y') {
        if (Test-Path $CLAUDE_DIR) {
            Remove-Item -Path $CLAUDE_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "Deleted: $CLAUDE_DIR"
        }
        if (Test-Path $CONFIG_DIR) {
            Remove-Item -Path $CONFIG_DIR -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info "Deleted: $CONFIG_DIR"
        }
    } else {
        Write-Blue "Configuration preserved"
    }

    # Step 3: Remove installation directory
    Write-Host "`n[3/3] Removing installation directory..." -ForegroundColor Cyan
    try {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction Stop
        Write-Info "Deleted: $INSTALL_DIR"
    } catch {
        Write-Err "Failed to remove installation directory: $_"
    }

    Write-Host ""
    Write-Info "CCA has been uninstalled. Goodbye!"
    Write-Host ""
}

# Main Entry Point
try {
    switch ($Action) {
        'install' { Install-CCA }
        'uninstall' { Uninstall-CCA }
        'help' { Show-Help }
        default {
            Write-Err "Unknown action: $Action"
            Show-Help
            exit 1
        }
    }
} catch {
    Write-Err "Error: $($_.Exception.Message)"
    exit 1
}
