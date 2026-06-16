# Unattended boot (manual setup)

> Not automated. `shrike` is currently configured for unattended boot
> manually; this doc exists so a future rebuild can recreate it. If you
> are reading this because shrike rebooted to a lock screen, this is the
> page to follow.

Goal: cold boot → desktop → ready for Steam Remote Play / SSH, no
intervention at the keyboard.

## Why this is manual

Encoding autologon in Ansible requires the MSA password at every
playbook run, even when the credential is already armed and stable. The
configuration doesn't drift in practice (the stored LSA secret is valid
until the MSA password rotates, which is rare), so the cost of keeping
it as code outweighs the rebuild convenience.

## Constraints

- **MSA login is preserved** for software entitlement (Office, Steam,
  Dropbox account state, etc.).
- The user is `mail` — the truncated local form of `mail@jakestanley.co.uk`.
  Confirm with `whoami` on shrike if unsure.

## One-time setup

Run from an elevated PowerShell on shrike:

```powershell
# 1. Re-allow MSA password sign-in. Windows defaults this to passwordless-only
#    after Hello enrollment, which blocks autologon. Setting it to 0 lets the
#    stored LSA secret be honoured at boot.
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" `
    /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f

# 2. Install Sysinternals Autologon (one-off tool, ~50KB).
winget install -e --id Microsoft.Sysinternals.Autologon

# 3. Arm autologon. Uses the same password you'd type at the MSA lock screen.
#    Stores it encrypted in LSA secrets, not plaintext in the registry.
autologon mail $env:COMPUTERNAME '<your-MSA-password>' /accepteula
```

Reboot to verify. If you land on the desktop, you're done.

## When you'll need to redo this

- **You change the MSA password.** Re-run step 3 with the new password.
- **A Windows update flips `DevicePasswordLessBuildVersion` back to 2.**
  Re-run step 1.

## Verifying it's armed

```powershell
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName
```

`AutoAdminLogon=1` and `DefaultUserName=mail` confirms autologon is armed.
The password lives in LSA secrets, not in the registry, so it won't show
up in a `reg query`.

## Undoing it

```powershell
autologon -d
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" `
    /v DevicePasswordLessBuildVersion /t REG_DWORD /d 2 /f
```
