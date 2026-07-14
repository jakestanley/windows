# Beat Saber backup — mirrors user content dirs from BSManager into Dropbox.
# Invoked interactively via the "Backup Beat Saber" desktop shortcut.
# Robocopy exit codes 0-7 are normal (nothing/changes/extras/mismatch);
# 8+ indicates failure.
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Dest,
    [Parameter(Mandatory)][string[]]$ExcludeDirs,
    [Parameter(Mandatory)][string]$LogPath
)

$ErrorActionPreference = 'Continue'
function Stamp { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }

New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null

Write-Host ""
Write-Host "Backing up Beat Saber content"
Write-Host "  source: $Source"
Write-Host "  dest:   $Dest"
Write-Host "  skip:   $($ExcludeDirs -join ', ')"
Write-Host ""

if (-not (Test-Path $Source)) {
    Write-Host "ERROR: source path does not exist" -ForegroundColor Red
    "$(Stamp) source missing: $Source" | Out-File $LogPath -Append
    Read-Host "Press Enter to close"
    exit 1
}
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

"$(Stamp) === starting backup ===" | Out-File $LogPath -Append

$overall = 0
Get-ChildItem -Path $Source -Directory |
    Where-Object { $ExcludeDirs -notcontains $_.Name } |
    ForEach-Object {
        Write-Host "-> $($_.Name)"
        robocopy $_.FullName (Join-Path $Dest $_.Name) /MIR /R:2 /W:5 /NFL /NDL /NP /LOG+:$LogPath
        "$(Stamp) $($_.Name) exit=$LASTEXITCODE" | Out-File $LogPath -Append
        if ($LASTEXITCODE -ge 8) { $overall = $LASTEXITCODE }
    }

Get-ChildItem -Path $Source -File | ForEach-Object {
    Copy-Item $_.FullName -Destination $Dest -Force
}

"$(Stamp) === done (overall=$overall) ===" | Out-File $LogPath -Append

Write-Host ""
if ($overall -ge 8) {
    Write-Host "Backup finished with errors (exit=$overall). See $LogPath" -ForegroundColor Red
} else {
    Write-Host "Backup complete." -ForegroundColor Green
}
Read-Host "Press Enter to close"
