#requires -Version 5.1

<#
.SYNOPSIS
  Install shrike's canonical desktop app set via winget. Run once after a
  fresh install of Windows, and any time this list grows.

.DESCRIPTION
  Idempotent: each package is attempted via `winget install --exact`.
  winget itself returns exit code -1978335189 (PACKAGE_ALREADY_INSTALLED)
  when a package is already present; the script treats that as a no-op
  and continues. Re-running the script when everything is already
  installed will produce a summary of "already_present" entries and
  exit 0.

  Run this in an interactive PowerShell session on shrike (does not need
  to be elevated; individual installers will prompt for UAC as needed).
  It cannot be invoked from Ansible over WinRM because the
  Microsoft.DesktopAppInstaller AppX package's WindowsApps directory
  denies execute access to non-interactively-provisioned users. See
  README "Platform limitations".

.NOTES
  If you add or remove an entry from $packages, update the
  "Adding a new desktop app" section in AGENTS.md so future contributors
  know this is the canonical list.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Canonical desktop app list for shrike. Keep alphabetised within each
# source group for diff-friendliness. Comments call out anything non-
# obvious from the package id.
$packages = @(
    # winget community / publisher repo
    @{ Id = 'AgileBits.1Password';                  Source = 'winget' }
    @{ Id = 'Discord.Discord';                      Source = 'winget' }
    @{ Id = 'Dropbox.Dropbox';                      Source = 'winget' }
    @{ Id = 'Hawaii_Beach.TinyNvidiaUpdateChecker'; Source = 'winget' }
    @{ Id = 'ImageMagick.Q16';                      Source = 'winget' }
    @{ Id = 'Microsoft.GamingApp';                  Source = 'winget' }  # Xbox app
    @{ Id = 'Microsoft.Git';                        Source = 'winget' }
    @{ Id = 'Mozilla.Firefox';                      Source = 'winget' }
    @{ Id = 'Obsidian.Obsidian';                    Source = 'winget' }
    @{ Id = 'Valve.Steam';                          Source = 'winget' }

    # Microsoft Store (msstore source uses opaque package ids)
    @{ Id = '9NKSQGP7F2NH';                         Source = 'msstore' } # WhatsApp
)

# winget exit codes (subset we care about)
# https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
$WINGET_ALREADY_INSTALLED = -1978335189   # 0x8A15002B
$WINGET_NO_APPLICABLE     = -1978335212   # 0x8A150014 (used by uninstall too)

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'winget is not on PATH. Open a fresh PowerShell session, or install "App Installer" from the Microsoft Store.'
}

$installed       = @()
$alreadyPresent  = @()
$errored         = @()

foreach ($p in $packages) {
    Write-Host "==> $($p.Id) [$($p.Source)]"
    $argList = @(
        'install',
        '--exact',
        '--id', $p.Id,
        '--source', $p.Source,
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements'
    )
    $out = & winget @argList 2>&1 | Out-String
    $rc  = $LASTEXITCODE

    if ($rc -eq 0) {
        $installed += $p.Id
        Write-Host "    installed" -ForegroundColor Green
    } elseif ($rc -eq $WINGET_ALREADY_INSTALLED -or $out -match 'already installed') {
        $alreadyPresent += $p.Id
        Write-Host "    already present" -ForegroundColor DarkGray
    } else {
        $errored += [pscustomobject]@{ Id = $p.Id; ExitCode = $rc; Output = $out.Trim() }
        Write-Host "    failed (rc=$rc)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host 'Summary:' -ForegroundColor Cyan
Write-Host "  installed       : $($installed.Count)"
Write-Host "  already present : $($alreadyPresent.Count)"
Write-Host "  errored         : $($errored.Count)"

if ($errored.Count -gt 0) {
    Write-Host ''
    Write-Host 'Errors:' -ForegroundColor Red
    foreach ($e in $errored) {
        Write-Host "  $($e.Id) (rc=$($e.ExitCode))"
        Write-Host ($e.Output -split "`n" | ForEach-Object { "    $_" }) -ForegroundColor DarkRed
    }
    exit 1
}

exit 0
