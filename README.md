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

- [docs/bootstrap.md](docs/bootstrap.md)
- [docs/services.md](docs/services.md)
- [docs/wol.md](docs/wol.md)
- [docs/sleep-on-lan.md](docs/sleep-on-lan.md)
- [docs/gaming.md](docs/gaming.md) (unreviewed)
- [docs/unattended.md](docs/unattended.md) — manual one-time setup, not in Ansible

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

Everything else (`desktop`, `bloatware`, `services-disable`, `registry`,
`folders`, `gaming`, `packages`, `clone`) was speculative — skip until a
real workflow demands them.

### Unify the package manager on winget

The `common` role uses winget; the `services` role still uses Chocolatey
for `git.portable`, `python312`, `nssm`, `ffmpeg`, and `ollama`. Working,
just inconsistent. Address on the next clean rebuild rather than now.

### Move the WinRM password out of `--ask-pass`

Currently typed at the prompt every run. An `ansible-vault` blob or a
1Password `op` lookup would let unattended re-runs happen without keyboard
involvement. Low priority while interactive runs are the norm.
