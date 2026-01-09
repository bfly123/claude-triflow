#Requires -Version 5.1

# UTF-8 encoding initialization (PowerShell 5.1 compatibility)
# Keep this near the top so Chinese/emoji output is rendered correctly.
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

# cca - Claude Code AutoFlow CLI (PowerShell)
# Manage AutoFlow skill installations across projects

$VERSION = '1.0.0'
$GIT_COMMIT = ''
$GIT_DATE = ''

$CCA_REPO_GIT = 'https://github.com/bfly123/claude_code_autoflow.git'
$CCA_REPO_URL = $CCA_REPO_GIT -replace '\.git$', ''
$CCA_REPO_API = 'https://api.github.com/repos/bfly123/claude_code_autoflow/commits/main'

function Get-EnvOrDefault {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Default
    )
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($null -ne $value -and $value -ne '') { return $value }
    return $Default
}

function Get-UserProfileDir {
    try {
        $p = [Environment]::GetFolderPath('UserProfile')
        if ($p) { return $p }
    } catch { }
    return $HOME
}

function Join-PathSafe {
    param([Parameter(Mandatory = $true)][string]$Base, [Parameter(Mandatory = $true)][string]$Child)
    if (-not $Base) { return $Child }
    return (Join-Path -Path $Base -ChildPath $Child)
}

$UserHome = Get-UserProfileDir
$DefaultCcaHome = if ($env:APPDATA) { Join-PathSafe $env:APPDATA 'cca' } else { Join-PathSafe $UserHome '.config\cca' }
$DefaultCcaCache = if ($env:LOCALAPPDATA) { Join-PathSafe $env:LOCALAPPDATA 'cca\cache' } else { Join-PathSafe $UserHome '.cache\cca' }
$DefaultInstallPrefix = if ($env:LOCALAPPDATA) { Join-PathSafe $env:LOCALAPPDATA 'cca' } else { Join-PathSafe $UserHome '.local\share\cca' }
$DefaultBinDir = if ($env:LOCALAPPDATA) { Join-PathSafe $env:LOCALAPPDATA 'Microsoft\WindowsApps' } else { Join-PathSafe $UserHome 'bin' }

$CCA_HOME = Get-EnvOrDefault 'CCA_HOME' $DefaultCcaHome
$CCA_CACHE = Get-EnvOrDefault 'CCA_CACHE' $DefaultCcaCache
$CCA_INSTALL_PREFIX = Get-EnvOrDefault 'CCA_INSTALL_PREFIX' $DefaultInstallPrefix
$CCA_BIN_DIR = Get-EnvOrDefault 'CCA_BIN_DIR' $DefaultBinDir

function Get-ScriptPath {
    $p = $PSCommandPath
    if (-not $p) { $p = $MyInvocation.MyCommand.Path }
    if (-not $p) { return $null }
    try { return (Resolve-Path -LiteralPath $p).ProviderPath } catch { return $p }
}

$CCA_SCRIPT_PATH = Get-ScriptPath
$CCA_SCRIPT_ROOT = if ($CCA_SCRIPT_PATH) { Split-Path -Parent $CCA_SCRIPT_PATH } else { (Get-Location).Path }
$CCA_SOURCE = if ($env:CCA_SOURCE) { $env:CCA_SOURCE } else { $CCA_SCRIPT_ROOT }

$INSTALLATIONS_FILE = Join-PathSafe $CCA_HOME 'installations.csv'
$LEGACY_INSTALLATIONS_FILE = Join-PathSafe $CCA_HOME 'installations'

$AUTOFLOW_SKILLS = @('tr', 'tp', 'dual-design', 'file-op', 'ask-codex', 'ask-gemini', 'roles', 'review', 'mode-switch', 'docs')
$AUTOFLOW_COMMANDS = @('tr.md', 'tp.md', 'dual-design.md', 'file-op.md', 'ask-codex.md', 'ask-gemini.md', 'roles.md', 'review.md', 'mode-switch.md', 'auto.md')

function Write-Info { param([string]$Message) Write-Host ("[+] {0}" -f $Message) -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host ("[!] {0}" -f $Message) -ForegroundColor Yellow }
function Write-Err  { param([string]$Message) Write-Host ("[-] {0}" -f $Message) -ForegroundColor Red }
function Write-Blue { param([string]$Message) Write-Host ("[*] {0}" -f $Message) -ForegroundColor Cyan }

function Write-AllLinesUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string[]]$Lines)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Write-AllTextUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Ensure-Directories {
    New-Item -ItemType Directory -Path $CCA_HOME -Force | Out-Null
    New-Item -ItemType Directory -Path $CCA_CACHE -Force | Out-Null
}

function Ensure-InstallationsFile {
    if (Test-Path -LiteralPath $INSTALLATIONS_FILE) {
        try {
            $first = Get-Content -LiteralPath $INSTALLATIONS_FILE -TotalCount 1 -ErrorAction Stop
            if ($first -and $first.Trim() -eq 'Path,Type,InstallDate') { return }
        } catch { }
    }
    Write-AllLinesUtf8NoBom -Path $INSTALLATIONS_FILE -Lines @('Path,Type,InstallDate')
}

function ConvertFrom-LegacyInstallationsIfNeeded {
    if (Test-Path -LiteralPath $INSTALLATIONS_FILE) {
        try {
            $fi = Get-Item -LiteralPath $INSTALLATIONS_FILE -ErrorAction Stop
            if ($fi.Length -gt 0) { return }
        } catch { return }
    }
    if (-not (Test-Path -LiteralPath $LEGACY_INSTALLATIONS_FILE)) { return }

    $records = @()
    $lines = Get-Content -LiteralPath $LEGACY_INSTALLATIONS_FILE -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        $parts = $trimmed.Split('|')
        if ($parts.Count -lt 1) { continue }
        $path = $parts[0]
        if (-not $path) { continue }
        $type = if ($parts.Count -ge 2 -and $parts[1]) { $parts[1] } else { 'project' }
        $date = if ($parts.Count -ge 3 -and $parts[2]) { $parts[2] } else { '' }
        $records += [PSCustomObject]@{ Path = $path; Type = $type; InstallDate = $date }
    }

    $csvLines = $records | Select-Object Path, Type, InstallDate | ConvertTo-Csv -NoTypeInformation
    Write-AllLinesUtf8NoBom -Path $INSTALLATIONS_FILE -Lines $csvLines
}

function Ensure-SystemRolesConfig {
    $rolesPath = Join-PathSafe $CCA_HOME 'roles.json'
    if (Test-Path -LiteralPath $rolesPath) { return }
    $content = @"
{
  "schemaVersion": 1,
  "enabled": true,
  "executor": "codex",
  "reviewer": "codex",
  "documenter": "codex",
  "designer": ["claude", "codex"]
}
"@
    try {
        Write-AllTextUtf8NoBom -Path $rolesPath -Text $content
        Write-Info ("Created system roles config: {0}" -f $rolesPath)
    } catch { }
}

function Ensure-ProjectRolesConfig {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $targetDir = Join-PathSafe $ProjectRoot '.autoflow'
    $targetFile = Join-PathSafe $targetDir 'roles.json'
    if (Test-Path -LiteralPath $targetFile) {
        Write-Warn ("Project roles config already exists: {0}" -f $targetFile)
        return
    }
    try { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null } catch { }
    $template = Join-PathSafe $CCA_SOURCE 'claude_source\templates\roles.json'
    if (Test-Path -LiteralPath $template) {
        try {
            Copy-Item -LiteralPath $template -Destination $targetFile -Force
            Write-Info ("Installed project roles config: {0}" -f $targetFile)
        } catch {
            Write-Warn ("Failed to install project roles config: {0}" -f $targetFile)
        }
    } else {
        Write-Warn ("Roles template not found (skipping): {0}" -f $template)
    }
}

function Show-Usage {
@"
cca - Claude Code AutoFlow CLI v$VERSION

Usage: cca <command> [options]

Commands:
  add .          Configure Codex permissions for current project
  add <path>     Configure Codex permissions for a project

  delete .       Remove Codex permissions config for current project
  delete <path>  Remove Codex permissions config for a project

  update [--local]  Update cca and refresh ~/.claude/
  list           Show configured projects
  uninstall      Remove cca from system

  version        Show version and commit info
  help           Show this help

Examples:
  cca add .                  # Configure current project
  cca add ~/myproject        # Configure a project
  cca delete .               # Remove config from current project
  cca update                 # Update cca and refresh ~/.claude/
  cca update --local         # Refresh ~/.claude/ from current CCA_SOURCE

Config:
  CCA_HOME=$CCA_HOME
  CCA_INSTALL_PREFIX=$CCA_INSTALL_PREFIX
  CCA_SOURCE=$CCA_SOURCE
"@ | Write-Host
}

function ConvertTo-TomlBasicEscaped {
    param([Parameter(Mandatory = $true)][string]$Value)
    $s = $Value -replace '\\', '\\\\'
    $s = $s -replace '"', '\"'
    return $s
}

function Expand-UserPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path -eq '~') { return (Get-UserProfileDir) }
    if ($Path.StartsWith('~/') -or $Path.StartsWith('~\')) {
        $home = Get-UserProfileDir
        $rest = $Path.Substring(2)
        return (Join-PathSafe $home $rest)
    }
    return $Path
}

function Get-CodexConfigPath {
    $home = Get-UserProfileDir
    return (Join-PathSafe $home '.codex\config.toml')
}

function Get-CanonicalDirectoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $p = $Path
    if ($p -eq '.') { $p = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        throw ("Directory not found: {0}" -f $Path)
    }
    $resolved = (Resolve-Path -LiteralPath $p).ProviderPath
    $full = [System.IO.Path]::GetFullPath($resolved)
    $trimmed = $full.TrimEnd([char]'/', [char]'\')
    if ($trimmed -match '^[A-Za-z]:$') { $trimmed = $trimmed + '\' }
    return $trimmed
}

function Read-Installations {
    Ensure-InstallationsFile
    try {
        $rows = Import-Csv -LiteralPath $INSTALLATIONS_FILE
        if ($null -eq $rows) { return @() }
        return @($rows | Where-Object { $_.Path -and $_.Path.Trim() })
    } catch {
        Write-Warn ("Failed to read installations: {0}" -f $INSTALLATIONS_FILE)
        return @()
    }
}

function Write-Installations {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Records)
    $normalized = @($Records | Select-Object Path, Type, InstallDate)
    $lines = $normalized | ConvertTo-Csv -NoTypeInformation
    if (-not $lines -or $lines.Count -eq 0) { $lines = @('Path,Type,InstallDate') }
    Write-AllLinesUtf8NoBom -Path $INSTALLATIONS_FILE -Lines $lines
}

function Record-Installation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Type,
        [string]$InstallDate
    )

    $date = if ($InstallDate) { $InstallDate } else { (Get-Date -Format 'yyyy-MM-dd') }
    $t = if ($Type -and $Type -eq 'system') { 'system' } else { 'project' }

    $existing = Read-Installations
    $filtered = @()
    foreach ($r in $existing) {
        if ($r.Path -and ($r.Path.ToLowerInvariant() -ne $Path.ToLowerInvariant())) { $filtered += $r }
    }
    $filtered += [PSCustomObject]@{ Path = $Path; Type = $t; InstallDate = $date }
    Write-Installations -Records $filtered
}

function Remove-Installation {
    param([Parameter(Mandatory = $true)][string]$Path)
    $existing = Read-Installations
    $filtered = @()
    foreach ($r in $existing) {
        if ($r.Path -and ($r.Path.ToLowerInvariant() -ne $Path.ToLowerInvariant())) { $filtered += $r }
    }
    Write-Installations -Records $filtered
}

function Test-CodexProjectConfigured {
    param([Parameter(Mandatory = $true)][string]$TargetPath)
    $cfg = Get-CodexConfigPath
    if (-not (Test-Path -LiteralPath $cfg)) { return $false }

    $escaped = ConvertTo-TomlBasicEscaped -Value $TargetPath
    $header = '[projects."' + $escaped + '"]'
    try {
        $lines = Get-Content -LiteralPath $cfg -ErrorAction Stop
        foreach ($line in $lines) {
            if ($line.Trim() -eq $header) { return $true }
        }
        return $false
    } catch {
        return $false
    }
}

function Update-CodexConfig {
    param([Parameter(Mandatory = $true)][string]$TargetPath)
    $cfg = Get-CodexConfigPath

    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Warn ("Codex config not found: {0} (skipping auto-approval setup)" -f $cfg)
        return
    }
    try {
        if ((Get-Item -LiteralPath $cfg -ErrorAction Stop).IsReadOnly) {
            Write-Warn ("Codex config not writable: {0} (skipping auto-approval setup)" -f $cfg)
            return
        }
    } catch { }

    $escaped = ConvertTo-TomlBasicEscaped -Value $TargetPath
    $header = '[projects."' + $escaped + '"]'

    $lines = @()
    try {
        $lines = Get-Content -LiteralPath $cfg -ErrorAction Stop
    } catch {
        Write-Warn ("Failed to read Codex config: {0}" -f $cfg)
        return
    }

    $hasHeader = $false
    foreach ($l in $lines) {
        if ($l.Trim() -eq $header) { $hasHeader = $true; break }
    }

    $out = New-Object System.Collections.Generic.List[string]

    if ($hasHeader) {
        $inSection = $false
        $foundApproval = $false
        foreach ($line in $lines) {
            $trim = $line.Trim()
            if ($trim -match '^\[[^]]+\]$') {
                if ($inSection -and -not $foundApproval) {
                    $out.Add('approval_policy = "never"')
                }
                $inSection = $false
                $foundApproval = $false
                if ($trim -eq $header) {
                    $inSection = $true
                    $out.Add($trim)
                    continue
                }
            }
            if ($inSection -and ($trim -match '^\s*approval_policy\s*=')) {
                $out.Add('approval_policy = "never"')
                $foundApproval = $true
                continue
            }
            $out.Add($line)
        }
        if ($inSection -and -not $foundApproval) {
            $out.Add('approval_policy = "never"')
        }
    } else {
        foreach ($line in $lines) { $out.Add($line) }
        $out.Add('')
        $out.Add($header)
        $out.Add('trust_level = "trusted"')
        $out.Add('approval_policy = "never"')
        $out.Add('sandbox_mode = "full-auto"')
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Write-AllLinesUtf8NoBom -Path $tmp -Lines $out.ToArray()
        try {
            [System.IO.File]::Copy($tmp, $cfg, $true)
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        } catch {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Write-Warn ("Failed to update Codex config (write denied): {0}" -f $cfg)
            return
        }
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Warn ("Failed to update Codex config (parse error): {0}" -f $cfg)
        return
    }

    if ($hasHeader) {
        Write-Info ("Codex auto-approval ensured (approval_policy=never): {0}" -f $TargetPath)
    } else {
        Write-Info ("Codex auto-approval configured for project: {0}" -f $TargetPath)
    }
}

function Remove-CodexConfig {
    param([Parameter(Mandatory = $true)][string]$TargetPath)
    $cfg = Get-CodexConfigPath

    if (-not (Test-Path -LiteralPath $cfg)) {
        Write-Warn ("Codex config not found: {0} (skipping removal)" -f $cfg)
        return
    }
    try {
        if ((Get-Item -LiteralPath $cfg -ErrorAction Stop).IsReadOnly) {
            Write-Warn ("Codex config not writable: {0} (skipping removal)" -f $cfg)
            return
        }
    } catch { }

    $escaped = ConvertTo-TomlBasicEscaped -Value $TargetPath
    $header = '[projects."' + $escaped + '"]'

    $lines = @()
    try { $lines = Get-Content -LiteralPath $cfg -ErrorAction Stop } catch {
        Write-Warn ("Failed to read Codex config: {0}" -f $cfg)
        return
    }

    $hasHeader = $false
    foreach ($l in $lines) {
        if ($l.Trim() -eq $header) { $hasHeader = $true; break }
    }
    if (-not $hasHeader) {
        Write-Warn ("Codex project config not found (already removed): {0}" -f $TargetPath)
        return
    }

    $out = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^\[[^]]+\]$') {
            if ($skip) { $skip = $false }
            if ($trim -eq $header) { $skip = $true; continue }
        }
        if ($skip) { continue }
        $out.Add($line)
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Write-AllLinesUtf8NoBom -Path $tmp -Lines $out.ToArray()
        try {
            [System.IO.File]::Copy($tmp, $cfg, $true)
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        } catch {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Write-Warn ("Failed to update Codex config (write denied): {0}" -f $cfg)
            return
        }
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Warn ("Failed to update Codex config (parse error): {0}" -f $cfg)
        return
    }

    Write-Info ("Codex project config removed: {0}" -f $TargetPath)
}

function Check-SourceDir {
    param([string]$SourceRoot)
    $root = if ($SourceRoot) { $SourceRoot } else { $CCA_SOURCE }
    $skillsDir = Join-PathSafe $root 'claude_source\skills'
    $cmdsDir = Join-PathSafe $root 'claude_source\commands'

    if (-not (Test-Path -LiteralPath $skillsDir -PathType Container)) {
        Write-Err ("Skills not found in {0}" -f $skillsDir)
        Write-Err "Set CCA_SOURCE to your AutoFlow repository directory"
        exit 1
    }
    if (-not (Test-Path -LiteralPath $cmdsDir -PathType Container)) {
        Write-Err ("Commands not found in {0}" -f $cmdsDir)
        exit 1
    }

    foreach ($skill in $AUTOFLOW_SKILLS) {
        $sd = Join-PathSafe $skillsDir $skill
        if (-not (Test-Path -LiteralPath $sd -PathType Container)) {
            Write-Err ("Missing AutoFlow skill in source: {0}" -f $sd)
            exit 1
        }
    }
}

function Install-GlobalSkills {
    param([Parameter(Mandatory = $true)][string]$SourceRoot)
    Check-SourceDir -SourceRoot $SourceRoot

    $home = Get-UserProfileDir
    $target = Join-PathSafe $home '.claude'
    $targetSkills = Join-PathSafe $target 'skills'
    $targetCmds = Join-PathSafe $target 'commands'
    New-Item -ItemType Directory -Path $targetSkills -Force | Out-Null
    New-Item -ItemType Directory -Path $targetCmds -Force | Out-Null

    foreach ($skill in $AUTOFLOW_SKILLS) {
        $dest = Join-PathSafe $targetSkills $skill
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        $src = Join-PathSafe $SourceRoot ("claude_source\skills\{0}" -f $skill)
        Copy-Item -LiteralPath $src -Destination $targetSkills -Recurse -Force
    }

    foreach ($cmd in $AUTOFLOW_COMMANDS) {
        $src = Join-PathSafe $SourceRoot ("claude_source\commands\{0}" -f $cmd)
        Copy-Item -LiteralPath $src -Destination $targetCmds -Force
    }

    Write-Info "Installed skills/commands to ~/.claude/ (globally visible)"
}

function Invoke-Install {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Type = 'project',
        [string]$InstallDate = ''
    )
    try { Update-CodexConfig -TargetPath $Path } catch { }
    Record-Installation -Path $Path -Type $Type -InstallDate $InstallDate
    Write-Info ("Configured Codex permissions: {0}" -f $Path)
}

function Invoke-Remove {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { Remove-CodexConfig -TargetPath $Path } catch { }
    Remove-Installation -Path $Path
    Write-Info ("Removed Codex permissions config: {0}" -f $Path)
}

function Get-SystemInstallDir {
    if (-not (Test-Path -LiteralPath $CCA_INSTALL_PREFIX -PathType Container)) { return $null }
    $hasScript = (Test-Path -LiteralPath (Join-PathSafe $CCA_INSTALL_PREFIX 'cca.ps1')) -or (Test-Path -LiteralPath (Join-PathSafe $CCA_INSTALL_PREFIX 'cca'))
    $hasSource = Test-Path -LiteralPath (Join-PathSafe $CCA_INSTALL_PREFIX 'claude_source') -PathType Container
    if ($hasScript -and $hasSource) { return $CCA_INSTALL_PREFIX }
    return $null
}

function Get-LocalVersionInfo {
    param([Parameter(Mandatory = $true)][string]$Dir)
    $commit = $GIT_COMMIT
    $date = $GIT_DATE

    if ((-not $commit) -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-PathSafe $Dir '.git') -PathType Container)) {
        try { $commit = (& git -C $Dir log -1 --format=%h 2>$null).Trim() } catch { }
        try { $date = (& git -C $Dir log -1 --format=%cs 2>$null).Trim() } catch { }
    }

    $commitOut = if ($commit) { $commit } else { '' }
    $dateOut = if ($date) { $date } else { '' }
    return [PSCustomObject]@{ Commit = $commitOut; Date = $dateOut }
}

function Get-RemoteVersionInfo {
    if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) { return $null }
    try {
        $ProgressPreference = 'SilentlyContinue'
        $resp = Invoke-RestMethod -Uri $CCA_REPO_API -Headers @{ 'User-Agent' = 'cca' } -Method Get
        if (-not $resp) { return $null }
        $sha = $resp.sha
        if (-not $sha) { return $null }
        $commit = $sha.Substring(0, [Math]::Min(7, $sha.Length))
        $rawDate = $null
        try { $rawDate = $resp.commit.committer.date } catch { }
        $date = ''
        if ($rawDate) { $date = $rawDate.ToString().Substring(0, 10) }
        return [PSCustomObject]@{ Commit = $commit; Date = $date }
    } catch {
        return $null
    }
}

function Set-VersionInfoInScriptFile {
    param([Parameter(Mandatory = $true)][string]$ScriptFile, [string]$Commit, [string]$Date)
    if (-not (Test-Path -LiteralPath $ScriptFile)) { return }
    if (-not $Commit) { return }
    try {
        $text = Get-Content -LiteralPath $ScriptFile -Raw
        $text = $text -replace '(?m)^\$GIT_COMMIT\s*=\s*''[^'']*''\s*$', ('$$GIT_COMMIT = ''{0}''' -f $Commit)
        $text = $text -replace '(?m)^\$GIT_DATE\s*=\s*''[^'']*''\s*$', ('$$GIT_DATE = ''{0}''' -f $Date)
        Write-AllTextUtf8NoBom -Path $ScriptFile -Text $text
    } catch { }
}

function Sync-InstallTreeFromExtracted {
    param([Parameter(Mandatory = $true)][string]$ExtractedDir, [Parameter(Mandatory = $true)][string]$InstallDir)
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

    $excludes = @(
        '.git', 'tmp', '__pycache__', '.pytest_cache',
        '*.session', '*.lock', '*.log', '*.pid', 'settings.local.json'
    )

    $items = Get-ChildItem -LiteralPath $ExtractedDir -Force
    foreach ($item in $items) {
        $name = $item.Name
        if ($name -eq '.git' -or $name -eq 'tmp' -or $name -eq '__pycache__' -or $name -eq '.pytest_cache') { continue }
        if ($name -like '*.session' -or $name -like '*.lock' -or $name -like '*.log' -or $name -like '*.pid') { continue }
        if ($name -eq 'settings.local.json') { continue }

        $dest = Join-PathSafe $InstallDir $name
        if (Test-Path -LiteralPath $dest) {
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
        Copy-Item -LiteralPath $item.FullName -Destination $InstallDir -Recurse -Force
    }
}

function Cmd-Version {
    $installDir = Get-SystemInstallDir
    if (-not $installDir) { $installDir = $CCA_SOURCE }

    $local = Get-LocalVersionInfo -Dir $installDir
    $extra = @()
    if ($local.Commit) { $extra += $local.Commit }
    if ($local.Date) { $extra += $local.Date }

    $suffix = if ($extra.Count -gt 0) { ' ' + ($extra -join ' ') } else { '' }
    Write-Host ("cca v{0}{1}" -f $VERSION, $suffix)
    Write-Host ("Install/source: {0}" -f $installDir)

    $remote = Get-RemoteVersionInfo
    if (-not $remote) {
        Write-Host 'Status: unable to check updates (network/curl unavailable)'
        return
    }

    if ($local.Commit -and $remote.Commit) {
        if ($local.Commit -eq $remote.Commit) {
            Write-Host 'Status: up to date'
        } else {
            $rd = if ($remote.Date) { ' ' + $remote.Date } else { '' }
            Write-Host ("Status: update available ({0}{1})" -f $remote.Commit, $rd)
            Write-Host 'Run: cca update'
        }
    } else {
        Write-Host 'Status: unable to compare versions'
    }
}

function Ensure-HookInstalled {
    $binDir = $CCA_BIN_DIR
    try {
        $ccaCmd = Get-Command cca -ErrorAction SilentlyContinue
        if ($ccaCmd -and $ccaCmd.Path) { $binDir = Split-Path -Parent $ccaCmd.Path }
    } catch { }

    $srcPs1 = Join-PathSafe $CCA_SOURCE 'cca-roles-hook.ps1'
    $dstPs1 = Join-PathSafe $binDir 'cca-roles-hook.ps1'
    $dstCmd = Join-PathSafe $binDir 'cca-roles-hook.cmd'

    if (-not (Test-Path -LiteralPath $srcPs1)) {
        Write-Warn ("Hook script not found (skipping install): {0}" -f $srcPs1)
        return
    }
    try { New-Item -ItemType Directory -Path $binDir -Force | Out-Null } catch { }

    $copyNeeded = $true
    try {
        if ((Test-Path -LiteralPath $dstPs1) -and ((Resolve-Path -LiteralPath $srcPs1).ProviderPath -eq (Resolve-Path -LiteralPath $dstPs1).ProviderPath)) {
            $copyNeeded = $false
        }
    } catch { }

    try {
        if ($copyNeeded) {
            Copy-Item -LiteralPath $srcPs1 -Destination $dstPs1 -Force
        } else {
            Write-Info ("Hook script already present: {0}" -f $dstPs1)
        }
        $cmd = "@echo off`r`n" +
               "powershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0cca-roles-hook.ps1`" %*`r`n"
        Write-AllTextUtf8NoBom -Path $dstCmd -Text $cmd
        Write-Info ("Installed hook: {0}" -f $dstCmd)
    } catch {
        Write-Warn ("Failed to install hook to: {0} ({1})" -f $binDir, $_.Exception.Message)
    }
}

function Ensure-ClaudeSettingsHook {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)
    $claudeDir = Join-PathSafe $ProjectRoot '.claude'
    $settingsPath = Join-PathSafe $claudeDir 'settings.json'
    try { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null } catch { }

    $hookCommand = 'cca-roles-hook'
    $data = @{}
    if (Test-Path -LiteralPath $settingsPath) {
        try {
            $raw = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
            $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($parsed -and ($parsed -is [System.Collections.IDictionary] -or $parsed -is [PSCustomObject])) {
                $data = $parsed
            } else {
                throw 'settings.json must be a JSON object'
            }
        } catch {
            Write-Warn ("Invalid JSON (skipping): {0}" -f $settingsPath)
            return
        }
    }

    $getProp = {
        param($Obj, [string]$Name)
        if ($null -eq $Obj -or -not $Name) { return $null }
        if ($Obj -is [System.Collections.IDictionary]) {
            try {
                if ($Obj.Contains($Name)) { return $Obj[$Name] }
            } catch {
                try {
                    if ($Obj.ContainsKey($Name)) { return $Obj[$Name] }
                } catch { }
            }
            return $null
        }
        try {
            $prop = $Obj.PSObject.Properties[$Name]
            if ($prop) { return $prop.Value }
        } catch { }
        return $null
    }

    $setProp = {
        param($Obj, [string]$Name, $Value)
        if ($null -eq $Obj -or -not $Name) { return }
        if ($Obj -is [System.Collections.IDictionary]) {
            $Obj[$Name] = $Value
            return
        }
        try {
            $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
        } catch {
            try { $Obj.$Name = $Value } catch { }
        }
    }

    $hasProp = {
        param($Obj, [string]$Name)
        if ($null -eq $Obj -or -not $Name) { return $false }
        if ($Obj -is [System.Collections.IDictionary]) {
            try { if ($Obj.Contains($Name)) { return $true } } catch {
                try { if ($Obj.ContainsKey($Name)) { return $true } } catch { }
            }
            return $false
        }
        try {
            $prop = $Obj.PSObject.Properties[$Name]
            return $null -ne $prop
        } catch { return $false }
    }

    $matcherToString = {
        param($Matcher)
        if ($Matcher -is [string] -and $Matcher.Trim()) { return $Matcher.Trim() }
        $tools = & $getProp $Matcher 'tools'
        if ($tools -is [System.Collections.IEnumerable]) {
            foreach ($t in $tools) {
                if ($t -is [string] -and $t.Trim()) { return $t.Trim() }
            }
        }
        $tool = & $getProp $Matcher 'tool'
        if ($tool -is [string] -and $tool.Trim()) { return $tool.Trim() }
        return '.*'
    }

    $migrateLegacy = {
        param($Entry)
        $matcherValue = & $matcherToString (& $getProp $Entry 'matcher')
        $cmds = & $getProp $Entry 'commands'
        $hooksArr = New-Object System.Collections.ArrayList
        if ($cmds -is [System.Collections.IEnumerable]) {
            foreach ($cmd in $cmds) {
                if ($cmd -is [string] -and $cmd.Trim()) {
                    [void]$hooksArr.Add([ordered]@{ type = 'command'; command = $cmd.Trim() })
                }
            }
        }
        if ($hooksArr.Count -eq 0) {
            [void]$hooksArr.Add([ordered]@{ type = 'command'; command = $hookCommand })
        }
        $entryObj = [ordered]@{
            matcher = $matcherValue
            hooks   = $hooksArr
        }
        return $entryObj
    }

    $containsHook = {
        param($Entry)
        $hooks = & $getProp $Entry 'hooks'
        if (-not $hooks) { return $false }
        foreach ($h in $hooks) {
            $cmd = & $getProp $h 'command'
            $type = & $getProp $h 'type'
            if ([string]::Equals($type, 'command', [System.StringComparison]::OrdinalIgnoreCase) -and
                [string]::Equals($cmd, $hookCommand, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        return $false
    }

    $changed = $false
    $hooksContainer = & $getProp $data 'hooks'
    if (-not ($hooksContainer -is [System.Collections.IDictionary] -or $hooksContainer -is [PSCustomObject])) {
        $hooksContainer = @{}
        & $setProp $data 'hooks' $hooksContainer
        $changed = $true
    }

    $preHooks = & $getProp $hooksContainer 'PreToolUse'
    $preList = $null
    if ($preHooks -is [System.Collections.ArrayList]) {
        $preList = $preHooks
    } elseif ($preHooks -is [System.Collections.IEnumerable]) {
        $preList = New-Object System.Collections.ArrayList
        foreach ($item in $preHooks) { [void]$preList.Add($item) }
    } else {
        $preList = New-Object System.Collections.ArrayList
    }
    if ($preHooks -ne $preList) {
        & $setProp $hooksContainer 'PreToolUse' $preList
        if (-not $preHooks) { $changed = $true }
    }

    $hookExists = $false
    for ($i = 0; $i -lt $preList.Count; $i++) {
        $entry = $preList[$i]
        $isObject = $entry -is [System.Collections.IDictionary] -or $entry -is [PSCustomObject]
        if (-not $isObject) { continue }

        if (& $hasProp $entry 'commands') {
            $preList[$i] = & $migrateLegacy $entry
            $entry = $preList[$i]
            $changed = $true
        }

        if (& $containsHook $entry) {
            $hookExists = $true
            $matcherValue = & $getProp $entry 'matcher'
            $normalizedMatcher = & $matcherToString $matcherValue
            if ($normalizedMatcher -ne $matcherValue) {
                & $setProp $entry 'matcher' $normalizedMatcher
                $changed = $true
            }
        }
    }

    if (-not $hookExists) {
        $newEntry = [ordered]@{
            matcher = '.*'
            hooks   = @(
                [ordered]@{ type = 'command'; command = $hookCommand }
            )
        }
        [void]$preList.Add($newEntry)
        $changed = $true
    }

    try {
        if ($changed -or -not (Test-Path -LiteralPath $settingsPath)) {
            $json = $data | ConvertTo-Json -Depth 32
            Write-AllTextUtf8NoBom -Path $settingsPath -Text ($json + "`n")
        }
        Write-Info ("Configured PreToolUse hook: {0}" -f $settingsPath)
    } catch {
        Write-Warn ("Failed to update .claude/settings.json: {0}" -f $settingsPath)
    }
}

function Cmd-Add {
    param([string]$Target)
    if (-not $Target) {
        Write-Err 'Usage: cca add <.|path>'
        exit 1
    }

    if ($Target -eq '.') {
        $p = Get-CanonicalDirectoryPath -Path '.'
        Write-Blue ("Configuring current project: {0}" -f $p)
        Invoke-Install -Path $p -Type 'project'
        Ensure-SystemRolesConfig
        Ensure-ProjectRolesConfig -ProjectRoot $p
        Ensure-HookInstalled
        Ensure-ClaudeSettingsHook -ProjectRoot $p
    } else {
        $candidate = Expand-UserPath -Path $Target
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-PathSafe (Get-Location).Path $candidate
        }
        $p = Get-CanonicalDirectoryPath -Path $candidate
        Write-Blue ("Configuring: {0}" -f $p)
        Invoke-Install -Path $p -Type 'project'
        Ensure-SystemRolesConfig
        Ensure-ProjectRolesConfig -ProjectRoot $p
        Ensure-HookInstalled
        Ensure-ClaudeSettingsHook -ProjectRoot $p
    }

    Write-Host ''
    Write-Info 'Done! AutoFlow is available globally in ~/.claude/ (run ./install.sh install if needed).'
}

function Cmd-Delete {
    param([string]$Target)
    if (-not $Target) {
        Write-Err 'Usage: cca delete <.|path>'
        exit 1
    }

    if ($Target -eq '.') {
        $p = Get-CanonicalDirectoryPath -Path '.'
        Write-Blue ("Removing config from current project: {0}" -f $p)
        Invoke-Remove -Path $p
    } else {
        $candidate = Expand-UserPath -Path $Target
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-PathSafe (Get-Location).Path $candidate
        }
        $p = Get-CanonicalDirectoryPath -Path $candidate
        Write-Blue ("Removing config from: {0}" -f $p)
        Invoke-Remove -Path $p
    }
}

function Cmd-List {
    Write-Blue 'Configured projects:'
    Write-Host ''

    $rows = Read-Installations
    if (-not $rows -or $rows.Count -eq 0) {
        Write-Host '  (none)'
        return
    }

    Write-Host ('  {0,-50} {1,-10} {2}' -f 'PATH', 'TYPE', 'DATE')
    Write-Host ('  {0,-50} {1,-10} {2}' -f '----', '----', '----')

    foreach ($r in $rows) {
        $p = $r.Path
        if (-not $p) { continue }
        $t = if ($r.Type) { $r.Type } else { 'project' }
        $d = if ($r.InstallDate) { $r.InstallDate } else { '' }
        $ok = Test-CodexProjectConfigured -TargetPath $p
        # 使用字符代码而非直接写 Unicode（解析安全）
        $checkMark = [char]0x2713  # ✓
        $crossMark = [char]0x2717  # ✗
        $status = if ($ok) { $checkMark } else { $crossMark }
        $color = if ($ok) { 'Green' } else { 'Red' }
        $line = ('  {0,-50} {1,-10} {2} ' -f $p, $t, $d)
        Write-Host $line -NoNewline
        Write-Host $status -ForegroundColor $color
    }
}

function Cmd-Update {
    param([string]$Mode)

    $sourceRoot = ''
    if ($Mode -eq '--local') {
        $sourceRoot = $CCA_SOURCE
        Write-Blue ("Refreshing ~/.claude/ from local source: {0}" -f $sourceRoot)
    } else {
        $installDir = Get-SystemInstallDir
        if (-not $installDir) {
            Write-Err ("System installation not found: {0}" -f $CCA_INSTALL_PREFIX)
            Write-Err 'Run: ./install.sh install'
            exit 1
        }

        Write-Blue ("Updating system installation: {0}" -f $installDir)

        if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-PathSafe $installDir '.git') -PathType Container)) {
            Write-Blue 'Updating via git pull...'
            & git -C $installDir pull --ff-only
        } else {
            Write-Blue 'Updating via zipball...'
            $tempDir = Join-PathSafe ([System.IO.Path]::GetTempPath()) ('cca_update_' + [System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            try {
                $zipUrl = $CCA_REPO_URL + '/archive/refs/heads/main.zip'
                $zipPath = Join-PathSafe $tempDir 'main.zip'
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -Headers @{ 'User-Agent' = 'cca' } | Out-Null

                Expand-Archive -LiteralPath $zipPath -DestinationPath $tempDir -Force

                $extracted = Join-PathSafe $tempDir 'claude_code_autoflow-main'
                if (-not (Test-Path -LiteralPath $extracted -PathType Container)) {
                    $fallback = Get-ChildItem -LiteralPath $tempDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*-main' } | Select-Object -First 1
                    if ($fallback) { $extracted = $fallback.FullName }
                }
                if (-not (Test-Path -LiteralPath $extracted -PathType Container)) {
                    throw 'Failed to extract zipball'
                }

                $remote = Get-RemoteVersionInfo
                Sync-InstallTreeFromExtracted -ExtractedDir $extracted -InstallDir $installDir

                $scriptFile = Join-PathSafe $installDir 'cca.ps1'
                if ($remote) {
                    Set-VersionInfoInScriptFile -ScriptFile $scriptFile -Commit $remote.Commit -Date $remote.Date
                }
            } catch {
                Write-Err ("Update failed: {0}" -f $_.Exception.Message)
                exit 1
            } finally {
                Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        $script:CCA_SOURCE = $installDir
        $sourceRoot = $installDir
        Write-Info 'Updated system installation'
    }

    Install-GlobalSkills -SourceRoot $sourceRoot

    $rows = Read-Installations
    $count = 0
    foreach ($r in $rows) {
        $p = $r.Path
        if (-not $p) { continue }
        if (Test-Path -LiteralPath $p -PathType Container) {
            Write-Blue ("Refreshing Codex config: {0}" -f $p)
            Invoke-Install -Path $p -Type ($r.Type) -InstallDate ($r.InstallDate)
            $count += 1
        } else {
            Write-Warn ("Skipping (not found): {0}" -f $p)
            Remove-Installation -Path $p
        }
    }

    Write-Host ''
    Write-Info ("Updated {0} project(s)" -f $count)
}

function Cmd-Uninstall {
    Write-Warn 'This will remove cca from your system.'
    Write-Host ''
    Write-Host -NoNewline 'Remove all configured project entries from Codex config too? [y/N] '
    $reply = Read-Host

    if ($reply -match '^[Yy]') {
        $rows = Read-Installations
        foreach ($r in $rows) {
            if ($r.Path) { Invoke-Remove -Path $r.Path }
        }
    }

    $cmd = Get-Command cca -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Path -and (Test-Path -LiteralPath $cmd.Path)) {
        try {
            Remove-Item -LiteralPath $cmd.Path -Force
            Write-Info ("Removed: {0}" -f $cmd.Path)
        } catch { }
    }

    $installDir = Get-SystemInstallDir
    if ($installDir) {
        try {
            Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Info ("Removed: {0}" -f $installDir)
        } catch { }
    }

    try {
        Remove-Item -LiteralPath $CCA_HOME -Recurse -Force -ErrorAction SilentlyContinue
        Write-Info ("Removed: {0}" -f $CCA_HOME)
    } catch { }

    Write-Host ''
    Write-Info 'cca uninstalled. Goodbye!'
}

try {
    Ensure-Directories
    ConvertFrom-LegacyInstallationsIfNeeded
    Ensure-InstallationsFile

    $command = if ($args.Count -ge 1) { $args[0] } else { '' }
    $arg1 = if ($args.Count -ge 2) { $args[1] } else { '' }

    switch ($command) {
        'add' { Cmd-Add -Target $arg1 }
        { $_ -in @('delete', 'remove', 'rm') } { Cmd-Delete -Target $arg1 }
        { $_ -in @('update', 'upgrade') } { Cmd-Update -Mode $arg1 }
        { $_ -in @('list', 'ls') } { Cmd-List }
        'uninstall' { Cmd-Uninstall }
        { $_ -in @('version', '-v', '--version') } { Cmd-Version }
        { $_ -in @('help', '-h', '--help', '') } { Show-Usage }
        default {
            Write-Err ("Unknown command: {0}" -f $command)
            Write-Host "Run 'cca help' for usage."
            exit 1
        }
    }
} catch {
    Write-Err $_.Exception.Message
    exit 1
}
