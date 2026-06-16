# SSH-based winget management (experimental)

> **Status:** unreviewed. Lives on branch `unreviewed/ssh-winget`. Smoke
> test only — installs `TinyNvidiaUpdateChecker` via `winget` over SSH
> as the `mail` user, to validate that this transport actually works.
> If it does, the desktop-app surface can move into Ansible properly.

## Why SSH instead of WinRM

WinRM as the `ansible` local admin can't execute `winget` — the
`Microsoft.DesktopAppInstaller` AppX package's WindowsApps directory
denies execute access to users who have never logged in interactively
(see `README.md` "Platform limitations").

OpenSSH on Windows runs sessions in interactive(-equivalent) context,
so a user that has logged in once on the desktop will have AppX
provisioned and can invoke `winget`. The `mail` user has already done
that, so it is the natural target.

The MSA passwordless setting on `mail` doesn't matter for SSH **key
auth**. Keys are validated by `sshd` and the session token is built
via Win32 APIs without consulting Windows password authentication. The
same MSA setting that breaks WinRM/NTLM does not block SSH keys.

## One-time setup

### On shrike (interactive elevated PowerShell)

```powershell
# 1. Install OpenSSH Server and start it
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

# 2. Open the firewall for SSH on the private profile
New-NetFirewallRule -DisplayName 'OpenSSH' -Direction Inbound `
    -Protocol TCP -LocalPort 22 -Action Allow -Profile Domain,Private

# 3. Default the SSH shell to PowerShell. The default cmd.exe shell
#    works but PS gives readable winget output.
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -PropertyType String -Force

# 4. Create the .ssh dir under mail's profile (run as mail, or fix
#    ACLs manually). Note: %USERPROFILE% must resolve to mail's
#    profile when this runs.
$auth = Join-Path $env:USERPROFILE '.ssh\authorized_keys'
New-Item -ItemType File -Path $auth -Force | Out-Null
```

### On the controller (Nix / macOS)

```sh
# Generate a dedicated key for shrike. Pick a strong passphrase if
# you want; ansible can use ssh-agent.
ssh-keygen -t ed25519 -f ~/.ssh/shrike_ed25519 -C "ansible-controller@shrike"

# Copy the public key to shrike.
cat ~/.ssh/shrike_ed25519.pub
# Paste the line into mail's authorized_keys on shrike (created above).
```

### Verify

```sh
ssh -i ~/.ssh/shrike_ed25519 mail@shrike.stanley.arpa whoami
```

Should print `shrike\mail` (or `mail`) without a password prompt.

## Run the smoke test

From the controller:

```sh
nix-shell
cd ansible
ansible-playbook playbooks/shrike-ssh-test.yml
```

Expected: TinyNvidiaUpdateChecker is installed (or already-installed
detected, exit 0). No prompts. If you see a UAC prompt on shrike, the
winget invocation needed elevation that SSH doesn't carry — flag that.

## If this works

Move the desktop-app install surface from
`scripts/install-desktop-apps.ps1` to a new Ansible role driven over
SSH-as-`mail`, and delete the script. AGENTS.md needs to be updated to
point at the role instead of the script.

If it doesn't work, write up the failure mode and we go back to the
script.
