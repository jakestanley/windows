# AGENTS

Conventions for AI agents (and humans) working in this repo.

## Repo purpose

This repo is the canonical source of truth for provisioning the Windows
host `shrike`. It contains:

- An Ansible bootstrap (`ansible/`) for everything that can be managed
  cleanly over WinRM: services, registry, files, networking, scheduled
  tasks, AppX bloatware removal, and the homelab service clones.
- Scripts (`scripts/`) for things Ansible **cannot** do cleanly over
  WinRM and that a human must run interactively on the host.
- Docs (`docs/`) covering manual procedures that aren't worth coding.

Read `README.md` "Platform limitations" before assuming a task belongs
in Ansible. The boundary is enforced by Windows' AppX/Network-Logon
security model, not by preference, and several previous attempts to
push past it have failed expensively.

## Adding a new desktop app

Desktop GUI apps live in `scripts/install-desktop-apps.ps1`, **not** in
the Ansible `common` role. The script is the canonical list and is
idempotent — re-runs are safe.

To add a new app:

1. Find its winget id with `winget search <name>` on a Windows machine,
   or check https://winget.run / https://winstall.app.
2. Add an entry to the `$packages` array in
   `scripts/install-desktop-apps.ps1`, keeping the alphabetisation
   within its source group. Use `Source = 'winget'` for the community
   repo and `Source = 'msstore'` for Microsoft Store items.
3. Add a trailing `# Display name` comment if the package id is opaque
   (anything from `msstore` always needs one — they use numeric ids).
4. Do not add the package to `ansible/roles/common/tasks/main.yml`.
   winget over WinRM is broken; see README "Platform limitations".

The user re-runs the script on shrike interactively after the change.

## Removing a desktop app

Remove the entry from `$packages` in `scripts/install-desktop-apps.ps1`.
The script does not uninstall — uninstallation is a separate, manual
step (`winget uninstall --exact --id <id>` on shrike). Removing from
the script just stops re-installing it on a fresh rebuild.

If the app needs to be actively uninstalled from existing hosts (e.g.
because we no longer want it provisioned for new user accounts), do
**not** put that in this script either. The Ansible `common` role
already has a "Remove default Microsoft bloatware AppX packages" task
that uses native `Remove-AppxPackage` and works over WinRM — extend
that list instead. AppX-only path; for classic Win32 installers,
manual uninstall remains the answer.

## Adding a Chocolatey package used by the services role

`ansible/roles/services/tasks/main.yml` uses `chocolatey.chocolatey.win_chocolatey`
for packages the homelab services consume programmatically (git, python,
nssm, ffmpeg, ollama). New entries go there as a separate task block.
Keep Chocolatey usage confined to the `services` role — see README
roadmap for the unification follow-up.

## Adding a manual maintenance procedure

Periodic tasks the user runs by hand (driver updates, etc.) live in
`docs/maintenance.md`. First-time-only setup procedures live in
`docs/unattended.md` and similar focused docs. Do not mix the two.

## Conventional commits

Prefix commit messages with `feat:`, `fix:`, `refactor:`, `docs:`,
`chore:`, etc. Keep commits atomic where reasonable. Long fix-forward
debugging sessions may be squashed into a single commit once the run
succeeds — do not commit each attempted fix.
