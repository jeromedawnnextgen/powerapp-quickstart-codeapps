#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive quickstart wizard for a new Power Apps Code App.
.DESCRIPTION
    Scaffolds, installs dependencies, authenticates, selects environment,
    registers the app, and optionally wires up a Dataverse data source.
    Reads defaults from config.json if present — copy config.example.json
    to get started.
.EXAMPLE
    .\new-codeapp.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Output helpers ────────────────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "`n  ⚡ $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  ✓  $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠  $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗  $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "     $msg" -ForegroundColor DarkGray }

# ── Header ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║    Power Apps Code App  —  Quickstart Wizard     ║" -ForegroundColor Magenta
Write-Host "  ║                  NextGen PowerApps               ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# ── Load config.json ──────────────────────────────────────────────────────────
$cfg = $null
$configPath = Join-Path $PSScriptRoot 'config.json'

if (Test-Path $configPath) {
    try {
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Host "  ⚙  Loaded config.json" -ForegroundColor DarkGray
    } catch {
        Write-Warn "config.json found but could not be parsed — using defaults."
        $cfg = $null
    }
} else {
    Write-Info "No config.json found. Copy config.example.json to set defaults."
}

# Helper: get a config value or fall back to a default
function Get-CfgValue {
    param($property, $fallback = '')
    if ($cfg -and $cfg.PSObject.Properties[$property]) {
        $val = $cfg.$property
        if ($null -ne $val -and "$val".Trim() -ne '') { return "$val".Trim() }
    }
    return $fallback
}

function Get-CfgBool {
    param($property, $fallback = $false)
    if ($cfg -and $cfg.PSObject.Properties[$property]) {
        return [bool]$cfg.$property
    }
    return $fallback
}

# ── Locate PAC CLI ────────────────────────────────────────────────────────────
function Get-PacCli {
    # 1. config.json override
    $cfgPath = Get-CfgValue 'pacCliPath'
    if ($cfgPath -and (Test-Path $cfgPath)) { return $cfgPath }

    # 2. System PATH
    $inPath = Get-Command pac -ErrorAction SilentlyContinue
    if ($inPath) { return 'pac' }

    # 3. VS Code Power Platform extension
    $vscodePac = Join-Path $env:APPDATA `
        'Code\User\globalStorage\microsoft-isvexptools.powerplatform-vscode\pac\tools\pac.exe'
    if (Test-Path $vscodePac) { return $vscodePac }

    return $null
}

# ── 1. Prerequisite check ─────────────────────────────────────────────────────
Write-Step "Checking prerequisites..."

try {
    $nodeVer = node --version 2>&1
    Write-Ok "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js not found."
    Write-Info "Install from https://nodejs.org and re-run this script."
    exit 1
}

$pac = Get-PacCli
if ($pac) {
    Write-Ok "PAC CLI found  →  $pac"
} else {
    Write-Fail "PAC CLI not found."
    Write-Info "Install option 1: winget install Microsoft.PowerPlatformCLI"
    Write-Info "Install option 2: VS Code → Power Platform Tools extension"
    Write-Info "Install option 3: Set pacCliPath in config.json"
    exit 1
}

# ── 2. Gather inputs ──────────────────────────────────────────────────────────
Write-Step "Configure your new app"
Write-Host ""

# Folder name — always prompt (unique per app)
do {
    $folderName = (Read-Host "  Folder name  (e.g. my-app)").Trim()
} while (-not $folderName)

# Display name — derive from folder name
$defaultDisplay = (Get-Culture).TextInfo.ToTitleCase(
    $folderName.Replace('-', ' ').Replace('_', ' ')
)
$displayInput = (Read-Host "  Display name [$defaultDisplay]").Trim()
$displayName  = if ($displayInput) { $displayInput } else { $defaultDisplay }

# Environment ID — use config value if set
$cfgEnvId      = Get-CfgValue 'environmentId' '2e4ff4ce-5107-eaa2-b6dd-a2832dee7708'
$envInput      = (Read-Host "  Environment ID [$cfgEnvId]").Trim()
$environmentId = if ($envInput) { $envInput } else { $cfgEnvId }

# Output directory — config value, or default to parent of the quickstart repo
$cfgOutDir  = Get-CfgValue 'outputDirectory'
$outputBase = if ($cfgOutDir -and (Test-Path $cfgOutDir)) {
    $cfgOutDir
} else {
    Split-Path $PSScriptRoot -Parent
}
$targetDir = Join-Path $outputBase $folderName

Write-Host ""
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Folder:       $targetDir"
Write-Host "  Display name: $displayName"
Write-Host "  Environment:  $environmentId"
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $targetDir) {
    Write-Warn "Folder '$folderName' already exists."
    $overwrite = (Read-Host "  Continue anyway? (y/N)").Trim()
    if ($overwrite -notmatch '^[Yy]') { exit 0 }
}

$confirm = (Read-Host "  Ready to go? (Y/n)").Trim()
if ($confirm -match '^[Nn]') { exit 0 }

# ── 3. Scaffold ───────────────────────────────────────────────────────────────
Write-Step "Scaffolding from Microsoft template..."

npx degit github:microsoft/PowerAppsCodeApps/templates/vite $targetDir
if ($LASTEXITCODE -ne 0) { Write-Fail "Scaffold failed."; exit 1 }
Write-Ok "Project created at $targetDir"

# ── 4. Install dependencies ───────────────────────────────────────────────────
Write-Step "Installing npm dependencies..."
Push-Location $targetDir

npm install --silent
if ($LASTEXITCODE -ne 0) { Write-Fail "npm install failed."; Pop-Location; exit 1 }
Write-Ok "Dependencies installed"

# ── 5. Auth ───────────────────────────────────────────────────────────────────
Write-Step "Checking Power Platform authentication..."

$authOutput = & $pac auth list 2>&1
if ($authOutput -match 'No profiles') {
    Write-Warn "No auth profile found — starting device code flow..."
    Write-Host ""
    Write-Info "Go to https://microsoft.com/devicelogin and enter the code shown below."
    Write-Host ""
    & $pac auth create --deviceCode
    if ($LASTEXITCODE -ne 0) { Write-Fail "Authentication failed."; Pop-Location; exit 1 }
    Write-Ok "Authenticated"
} else {
    Write-Ok "Already authenticated"
}

# ── 6. Select environment ─────────────────────────────────────────────────────
Write-Step "Selecting environment..."

& $pac env select --environment $environmentId
if ($LASTEXITCODE -ne 0) { Write-Fail "Could not select environment."; Pop-Location; exit 1 }
Write-Ok "Environment set: $environmentId"

# ── 7. Initialize Code App ────────────────────────────────────────────────────
Write-Step "Registering app on Power Platform..."

& $pac code init --displayname $displayName
if ($LASTEXITCODE -ne 0) { Write-Fail "pac code init failed."; Pop-Location; exit 1 }
Write-Ok "App registered: '$displayName'"

# ── 8. Dataverse data source ──────────────────────────────────────────────────
$cfgConnId      = Get-CfgValue 'connectionId'
$autoAddDs      = Get-CfgBool  'autoAddDataSource'

# Decide whether to add data source
$doAddDs = $false
if ($cfgConnId -and $autoAddDs) {
    # Both set in config — run silently
    $doAddDs  = $true
    $connId   = $cfgConnId
    Write-Host ""
    Write-Info "Data source: using connectionId from config.json"
} else {
    Write-Host ""
    $dsPrompt = if ($cfgConnId) { "  Add Dataverse data source? (connection ID pre-filled) (Y/n)" } `
                else            { "  Add a Dataverse data source now? (y/N)" }
    $addDsAnswer = (Read-Host $dsPrompt).Trim()

    $defaultYes = [bool]$cfgConnId
    if ($defaultYes) {
        $doAddDs = $addDsAnswer -notmatch '^[Nn]'
    } else {
        $doAddDs = $addDsAnswer -match '^[Yy]'
    }

    if ($doAddDs) {
        if ($cfgConnId) {
            $connInput = (Read-Host "  Connection ID [$cfgConnId]").Trim()
            $connId    = if ($connInput) { $connInput } else { $cfgConnId }
        } else {
            Write-Host ""
            Write-Info "Run this in another terminal to find your connection ID:"
            Write-Info "  $pac connection list"
            Write-Host ""
            $connId = (Read-Host "  Paste your Connection ID").Trim()
        }
    }
}

if ($doAddDs -and $connId) {
    Write-Step "Adding Dataverse data source..."
    & $pac code add-data-source -a "shared_commondataserviceforapps" -c $connId

    if ($LASTEXITCODE -ne 0) {
        Write-Warn "add-data-source failed — run it manually when ready."
    } else {
        Write-Ok "Data source added"

        Write-Step "Patching generated service file (MSCRM dot-name bug)..."
        $svcFile = "src\generated\services\MicrosoftDataverseService.ts"

        if (Test-Path $svcFile) {
            $content    = Get-Content $svcFile -Raw
            $patchCount = ([regex]::Matches($content, 'MSCRM\.IncludeMipSensitivityLabel')).Count
            $patched    = $content -replace 'MSCRM\.IncludeMipSensitivityLabel', 'MSCRM_IncludeMipSensitivityLabel'
            Set-Content $svcFile $patched -NoNewline
            Write-Ok "Patched $patchCount occurrence(s) of MSCRM.IncludeMipSensitivityLabel"
        } else {
            Write-Warn "Service file not found — if the build fails, replace:"
            Write-Info "  MSCRM.IncludeMipSensitivityLabel  →  MSCRM_IncludeMipSensitivityLabel"
        }
    }
}

# ── 9. Success ────────────────────────────────────────────────────────────────
Pop-Location
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║                  You're all set!                 ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "    cd $folderName" -ForegroundColor Yellow
Write-Host "    npm run dev          " -NoNewline -ForegroundColor Yellow; Write-Host "# run locally" -ForegroundColor DarkGray
Write-Host "    npm run build        " -NoNewline -ForegroundColor Yellow; Write-Host "# build for production" -ForegroundColor DarkGray
Write-Host "    pac code push        " -NoNewline -ForegroundColor Yellow; Write-Host "# deploy to Power Platform" -ForegroundColor DarkGray
Write-Host ""

# Open in VS Code?
$autoVSCode  = Get-CfgBool 'autoOpenVSCode'
if ($autoVSCode) {
    Write-Info "Opening in VS Code (autoOpenVSCode = true)..."
    code $targetDir
} else {
    $openCode = (Read-Host "  Open in VS Code? (Y/n)").Trim()
    if ($openCode -notmatch '^[Nn]') { code $targetDir }
}

# Start dev server?
$autoDev = Get-CfgBool 'autoStartDev'
if ($autoDev) {
    Write-Info "Starting dev server (autoStartDev = true)..."
    Set-Location $targetDir
    npm run dev
} else {
    $startDev = (Read-Host "  Start dev server? (Y/n)").Trim()
    if ($startDev -notmatch '^[Nn]') {
        Set-Location $targetDir
        npm run dev
    }
}
