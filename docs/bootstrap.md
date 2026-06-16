# Bootstrap

End-to-end provisioning of the `shrike` Windows host from a fresh install.

## Prerequisites

- Windows 10/11 installed with a local admin account
- D:\ data drive present (used for homelab state, e.g. `D:\demucs`)
- Ansible 2.16+ on the controller with collections:
  - `ansible.windows`
  - `community.windows`
  - `chocolatey.chocolatey`

### Controller setup with Nix

`shell.nix` at the repo root provisions `ansible-core`, `pywinrm`, and the
collections listed in `ansible/requirements.yml` on shell entry. Collections
land in repo-local `.ansible/collections` (gitignored).

```sh
nix-shell
```

### Controller setup without Nix

```sh
pip install ansible-core pywinrm
ansible-galaxy collection install -r ansible/requirements.yml
```

## One-time setup on shrike

Run from an elevated PowerShell session on `shrike`.

### Create a dedicated local admin for Ansible

Do **not** authenticate as a Microsoft-account-linked user. MSA accounts on
Windows 10/11 default to "passwordless" mode (the "improved security" toggle
under Sign-in options), which rejects NTLM password auth even with the
correct password. MFA on the MSA breaks it further. A plain local admin
sidesteps all of it.

```powershell
$pw = Read-Host -AsSecureString "ansible password"
New-LocalUser -Name ansible -Password $pw -PasswordNeverExpires:$true -AccountNeverExpires
Add-LocalGroupMember -Group Administrators -Member ansible
```

Inventory ships with `ansible_user=ansible`. If you choose a different name,
update `ansible/inventory.ini` to match.

### Enable WinRM

```powershell
winrm quickconfig -q
Set-Item WSMan:\localhost\Service\Auth\Basic $false
Set-Item WSMan:\localhost\Service\AllowUnencrypted $true
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -Profile Domain,Private
```

NTLM over HTTP on 5985 is the default in `inventory.ini`. For HTTPS, configure
a self-signed cert on 5986 and update the inventory accordingly.

## Configure inventory

Edit `ansible/inventory.ini`:

- `ansible_host` — resolvable hostname or IP
- `ansible_user` — the local admin you created above (default: `ansible`)

The password is not stored in inventory. Ansible prompts for it on stdin via
`--ask-pass`. To switch to vaulted credentials later, see
`ansible-vault encrypt_string`.

## Run

```sh
cd ansible
ansible -m win_ping windows --ask-pass            # connectivity smoke test
ansible-playbook playbooks/shrike-bootstrap.yml --ask-pass
```

## What the playbook does

1. **common** — host baseline: telemetry / search services disabled
   (`WSearch`, `DiagTrack`, `dmwappushservice`), networking block (Fast
   Startup off, ICMPv4 echo, NTP via `w32time`, NIC magic-packet on,
   Sleep-on-LAN NSSM service), Bing / Cortana registry tweaks,
   D:\Downloads + D:\Videos folder relocation.
2. **services** — clones `homelab-rtx`, `homelab-demucs`, `homelab-ollama`
   under `C:\homelab\`, seeds `.env` from `.env.example` on first clone, runs
   each repo's `scripts/up.ps1` to install the NSSM services.

## After first run

For each service under `C:\homelab\<repo>\.env`, replace placeholder values
(notably `*_PYTHON_EXE` and any service-specific paths) and re-run the
playbook — `up.ps1` is idempotent.

## Troubleshooting

### Time-windowed dashboards show no data (charts, history)

Symptom: a service is healthy, its API returns rows, but a UI that filters
to "last N minutes" (e.g. the rtx landing page chart) shows nothing.

Cause: `w32time` on shrike is not syncing. The wall clock drifts from real
time, so stored timestamps fall outside the browser's filter window.

Check:

```powershell
w32tm /query /status
```

`Stratum: 0` and `Leap Indicator: 3 (not synchronized)` mean NTP isn't
running. The `networking` role configures NTP (Cloudflare + uk.pool.ntp.org)
and forces a resync. Re-run:

```sh
ansible-playbook playbooks/shrike-bootstrap.yml --tags networking --ask-pass
```

After: stratum should be 2-3 and Source should name a peer. New samples
written by services from that point on are correctly timestamped; older
rows in CSVs / state stores remain skewed (use "All" range to see them, or
let new data accumulate).

## Re-running

The playbook is idempotent. Re-run any time to converge state.

### Running a slice with tags

| Tag | Tasks |
|---|---|
| `services-disable` | Stop and disable `WSearch`, `DiagTrack`, `dmwappushservice`. |
| `networking` | Fast Startup off, ICMPv4 echo allowed, NTP configured, NIC magic-packet on, Sleep-on-LAN installed. |
| `registry` | Bing / Cortana search off. |
| `folders` | D:\Downloads / D:\Videos relocation. |
| `services` | Choco prereqs (git, python312, nssm, ffmpeg, ollama), Ollama NSSM wrapper, clone + pull + seed `.env`, run each repo's `up.ps1`. |
| `clone` | Clone + pull + seed only (no `up.ps1`). |
| `up` | Pull latest + re-run each repo's `up.ps1`. |

```sh
ansible-playbook playbooks/shrike-bootstrap.yml --tags networking --ask-pass
ansible-playbook playbooks/shrike-bootstrap.yml --tags up --ask-pass
```

See all defined tags / tasks:

```sh
ansible-playbook playbooks/shrike-bootstrap.yml --list-tags
ansible-playbook playbooks/shrike-bootstrap.yml --list-tasks
```
