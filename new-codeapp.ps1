#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive quickstart wizard for a new Power Apps Code App.
.DESCRIPTION
    Scaffolds, installs dependencies, authenticates, selects environment,
    registers the app, and optionally wires up a Dataverse data source —
    all in one shot.
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

# ── Locate PAC CLI ────────────────────────────────────────────────────────────
function Get-PacCli {
    # 1. System PATH
    $inPath = Get-Command pac -ErrorAction SilentlyContinue
    if ($inPath) { return 'pac' }

    # 2. VS Code Power Platform extension (common install location)
    $vscodePac = Join-Path $env:APPDATA `
        'Code\User\globalStorage\microsoft-isvexptools.powerplatform-vscode\pac\tools\pac.exe'
    if (Test-Path $vscodePac) { return $vscodePac }

    return $null
}

# ── 1. Prerequisite check ─────────────────────────────────────────────────────
Write-Step "Checking prerequisites..."

# Node.js
try {
    $nodeVer = node --version 2>&1
    Write-Ok "Node.js $nodeVer"
} catch {
    Write-Fail "Node.js not found."
    Write-Info "Install from https://nodejs.org and re-run this script."
    exit 1
}

# PAC CLI
$pac = Get-PacCli
if ($pac) {
    Write-Ok "PAC CLI found  →  $pac"
} else {
    Write-Fail "PAC CLI not found."
    Write-Info "Install option 1: winget install Microsoft.PowerPlatformCLI"
    Write-Info "Install option 2: VS Code → Power Platform Tools extension"
    exit 1
}

# ── 2. Gather inputs ──────────────────────────────────────────────────────────
Write-Step "Configure your new app"
Write-Host ""

# Folder / slug name
do {
    $folderName = (Read-Host "  Folder name  (e.g. my-app)").Trim()
} while (-not $folderName)

# Human-readable display name
$defaultDisplay = (Get-Culture).TextInfo.ToTitleCase(
    $folderName.Replace('-', ' ').Replace('_', ' ')
)
$displayInput  = (Read-Host "  Display name [$defaultDisplay]").Trim()
$displayName   = if ($displayInput) { $displayInput } else { $defaultDisplay }

# Environment ID
$defaultEnvId  = '2e4ff4ce-5107-eaa2-b6dd-a2832dee7708'
$envInput      = (Read-Host "  Environment ID [$defaultEnvId]").Trim()
$environmentId = if ($envInput) { $envInput } else { $defaultEnvId }

# Destination folder (sibling of wherever the script is run from)
$targetDir = Join-Path (Get-Location) $folderName

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

npx degit github:microsoft/PowerAppsCodeApps/templates/vite $folderName
if ($LASTEXITCODE -ne 0) { Write-Fail "Scaffold failed."; exit 1 }
Write-Ok "Project created at $folderName/"

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

# ── 8. Optional: Dataverse data source ───────────────────────────────────────
Write-Host ""
$addDs = (Read-Host "  Add a Dataverse data source now? (y/N)").Trim()

if ($addDs -match '^[Yy]') {
    Write-Host ""
    Write-Info "Run this in another terminal to find your connection ID:"
    Write-Info "  $pac connection list"
    Write-Host ""
    $connId = (Read-Host "  Paste your Connection ID").Trim()

    if ($connId) {
        Write-Step "Adding Dataverse data source..."
        & $pac code add-data-source -a "shared_commondataserviceforapps" -c $connId

        if ($LASTEXITCODE -ne 0) {
            Write-Warn "add-data-source failed — run it manually when ready."
        } else {
            Write-Ok "Data source added"

            # Fix known Microsoft bug: dot in TypeScript parameter name
            Write-Step "Patching generated service file (MSCRM dot-name bug)..."
            $svcFile = "src\generated\services\MicrosoftDataverseService.ts"

            if (Test-Path $svcFile) {
                $content = Get-Content $svcFile -Raw
                $patched = $content -replace 'MSCRM\.IncludeMipSensitivityLabel', 'MSCRM_IncludeMipSensitivityLabel'
                $patchCount = ([regex]::Matches($content, 'MSCRM\.IncludeMipSensitivityLabel')).Count
                Set-Content $svcFile $patched -NoNewline
                Write-Ok "Patched $patchCount occurrence(s) of MSCRM.IncludeMipSensitivityLabel"
            } else {
                Write-Warn "Service file not found — if the build fails, replace:"
                Write-Info "  MSCRM.IncludeMipSensitivityLabel  →  MSCRM_IncludeMipSensitivityLabel"
            }
        }
    } else {
        Write-Warn "No connection ID entered — skipping data source."
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
Write-Host "    npm run dev          " -NoNewline -ForegroundColor Yellow
Write-Host "# run locally" -ForegroundColor DarkGray
Write-Host "    npm run build        " -NoNewline -ForegroundColor Yellow
Write-Host "# build for production" -ForegroundColor DarkGray
Write-Host "    pac code push        " -NoNewline -ForegroundColor Yellow
Write-Host "# deploy to Power Platform" -ForegroundColor DarkGray
Write-Host ""

# Open in VS Code?
$openCode = (Read-Host "  Open in VS Code? (Y/n)").Trim()
if ($openCode -notmatch '^[Nn]') {
    code $targetDir
}

# Start dev server?
$startDev = (Read-Host "  Start dev server? (Y/n)").Trim()
if ($startDev -notmatch '^[Nn]') {
    Set-Location $targetDir
    npm run dev
}
