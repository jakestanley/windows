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
ansible-playbook playbooks/shrike-bootstrap.yml --ask-pass       # config baseline (WinRM)
ansible-playbook playbooks/shrike-ssh-bootstrap.yml --ask-pass   # one-time: OpenSSH + key
ansible-playbook playbooks/shrike-desktop-apps.yml               # desktop apps via SSH
```

The SSH bootstrap publishes your `~/.ssh/id_ed25519.pub` into shrike's
`administrators_authorized_keys`; if you don't have a keypair yet run
`ssh-keygen -t ed25519` first. See [docs/unattended.md](docs/unattended.md) for the full
transport rationale.

Non-Nix controllers need `ansible-core`, `pywinrm`, and the collections in
`ansible/requirements.yml` installed manually — see `docs/bootstrap.md`.

## Details

- [docs/bootstrap.md](docs/bootstrap.md) — Ansible-managed provisioning
- [docs/services.md](docs/services.md) — homelab services role
- [docs/wol.md](docs/wol.md) — Wake-on-LAN
- [docs/sleep-on-lan.md](docs/sleep-on-lan.md) — Sleep-on-LAN
- [docs/gaming.md](docs/gaming.md) — gaming role (Steam Remote Play)
- [docs/sunshine.md](docs/sunshine.md) — Sunshine (Moonlight stream host)
- [docs/unattended.md](docs/unattended.md) — first-time manual setup (autologon, SSH transport)
- [docs/maintenance.md](docs/maintenance.md) — periodic manual tasks (NVIDIA driver updates, etc.)

## Platform limitations

Some things on this host are handled outside the standard WinRM
bootstrap by design:

- **NVIDIA driver updates** — TinyNvidiaUpdateChecker itself is installed
  by the `desktop_apps` role, but actually *running* it to swap drivers
  is deliberately manual: the swap is destructive to in-flight gaming
  sessions and CUDA workloads, so you choose when it runs. See
  [docs/maintenance.md](docs/maintenance.md).
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
- `networking` — full networking block (Fast Startup, ICMP, NTP, WoL,
  Sleep-on-LAN). Useful as a one-shot when WoL or NTP stops behaving
  (we hit this once with the clock-drift bug).

### Secret injection into service `.env` files

The services role's "Seed .env from .env.example" task
(`ansible/roles/services/tasks/main.yml`) cannot currently deliver
secrets like `RTX_INFLUX_TOKEN`:

- It skips entirely if `.env` already exists on the host, so
  `env_overrides` only fires on a fresh clone.
- Its override regex only matches uncommented `KEY=` lines, so
  commented-out keys in `.env.example` (the InfluxDB block in
  `homelab-rtx` is the live example) can't be activated by an override.

To fix: (i) merge `env_overrides` into an existing `.env` instead of
short-circuiting, (ii) widen the regex to match an optional leading
`#\s*` so commented keys can be uncommented and set, (iii) move the
token itself into ansible-vault (e.g. `group_vars/windows/vault.yml`)
and reference it from `env_overrides`. Until this lands, the InfluxDB
token is set by hand on the host and is not reproducible from a clean
rebuild.

