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
