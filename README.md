# shrike

Ansible bootstrap for the Windows host `shrike`.

## Quick start

On `shrike`, run these one-time steps from an elevated PowerShell:

```powershell
# 1. Dedicated local admin for Ansible (avoids MSA passwordless / MFA pain)
$pw = Read-Host -AsSecureString "ansible password"
New-LocalUser -Name ansible -Password $pw -PasswordNeverExpires:$true -AccountNeverExpires
Add-LocalGroupMember -Group Administrators -Member ansible

# 2. Enable WinRM
winrm quickconfig -q
Set-Item WSMan:\localhost\Service\Auth\Basic $false
Set-Item WSMan:\localhost\Service\AllowUnencrypted $true
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -Profile Domain,Private
```

Inventory uses `ansible_user=ansible`; supply the password via `--ask-pass`.

From the controller (Nix):

```sh
nix-shell                          # installs ansible, pywinrm, collections
cd ansible
# edit inventory.ini (host, user)
ansible-playbook playbooks/shrike-bootstrap.yml --ask-pass
```

Non-Nix controllers need `ansible-core`, `pywinrm`, and the collections in
`ansible/requirements.yml` installed manually — see `docs/bootstrap.md`.

## Details

- [docs/bootstrap.md](docs/bootstrap.md) — Ansible-managed provisioning
- [docs/services.md](docs/services.md) — homelab services role
- [docs/wol.md](docs/wol.md) — Wake-on-LAN
- [docs/sleep-on-lan.md](docs/sleep-on-lan.md) — Sleep-on-LAN
- [docs/gaming.md](docs/gaming.md) — gaming role (unreviewed)
- [docs/unattended.md](docs/unattended.md) — first-time manual setup: autologon
- [docs/maintenance.md](docs/maintenance.md) — periodic manual tasks (NVIDIA driver updates, etc.)

## Platform limitations

Some things on this host are handled outside Ansible by design:

- **Desktop GUI app installation** (Steam, Firefox, Discord, Dropbox,
  1Password, Obsidian, ImageMagick, TinyNvidiaUpdateChecker, etc.) is
  **not** automated. winget over WinRM hits a WindowsApps ACL deny (the
  `ansible` local admin has never logged in interactively, so
  `Microsoft.DesktopAppInstaller` is not provisioned for it), and
  Chocolatey duplicates anything already installed via winget. Run
  `scripts/install-desktop-apps.ps1` interactively on shrike — the
  canonical list lives there; the script is idempotent. See `AGENTS.md`
  for how to add or remove entries.
- **NVIDIA driver updates** — same WinRM/AppX boundary as above; the
  TinyNvidiaUpdateChecker binary installed by winget is unreachable
  from the playbook. Run manually from shrike; see
  `docs/maintenance.md`.
- **Unattended autologon** — see `docs/unattended.md`. Configured once
  via Sysinternals Autologon; LSA-stored credential, not re-applied
  per playbook run.

## Roadmap

Tracked here to keep them off the immediate critical path. Add as the need
arises, not pre-emptively.

### Reintroduce a small set of task-level tags

Tags were stripped from all roles to remove visual noise and a tag-table
that had to stay in sync with the code. The candidates worth reintroducing
when the need shows up:

- `up` — pull latest in each homelab repo + re-run their `scripts/up.ps1`.
  This is the regular "deploy new service code" workflow; doing the full
  playbook to roll service updates is wasteful.
- `nvidia` — TinyNvidiaUpdateChecker auto-install. Worth being skippable
  via `--skip-tags nvidia` because a driver swap kills in-flight gaming
  sessions and CUDA workloads.
- `networking` — full networking block (Fast Startup, ICMP, NTP, WoL,
  Sleep-on-LAN). Useful as a one-shot when WoL or NTP stops behaving
  (we hit this once with the clock-drift bug).

### Unify the package manager used by the services role

The `services` role uses Chocolatey for `git.portable`, `python312`,
`nssm`, `ffmpeg`, and `ollama`. The `common` role uses neither winget
nor choco for end-user apps (see Platform limitations). Worth flattening
to a single manager on the next clean rebuild — preference still being
worked out.

