# Maintenance

Periodic manual tasks for `shrike`. These don't fit Ansible cleanly (most
need an interactive user session) and live here as the canonical checklist
so they can be rerun cold.

## NVIDIA driver updates

shrike runs an RTX 3070 Ti. NVIDIA driver updates matter for both gaming
performance and CUDA correctness in the homelab services (`homelab-demucs`
runs PyTorch CUDA kernels that occasionally break against older drivers).

We use [TinyNvidiaUpdateChecker](https://github.com/ElPumpo/TinyNvidiaUpdateChecker)
because the official GeForce Experience client requires an account and
adds telemetry; TNUC is a tiny standalone CLI/GUI that talks to the same
NVIDIA endpoint.

### Run it

On shrike, from an interactive PowerShell (does not have to be elevated;
the installer it spawns prompts for UAC):

```powershell
TinyNvidiaUpdateChecker --quiet --noprompt --confirm-dl
```

Flags:

- `--quiet` — suppress the "no update needed" splash
- `--noprompt` — do not pause for keypress on exit
- `--confirm-dl` — download and install without further interaction

If a driver update is found it downloads (~700 MB-1 GB) and runs NVIDIA's
silent installer. The installer briefly drops video while the driver
swaps; if you're streaming via Steam Remote Play, the client will
reconnect once the display comes back.

### Cadence

Run after a release cycle of any of:

- A Steam game posts driver-required notes
- `homelab-demucs` starts erroring on CUDA initialisation
- You're rebuilding shrike from a fresh install

There's no scheduled trigger and that's deliberate — a driver swap mid
gaming session or mid CUDA workload is destructive, so you want to
choose when it runs.

### Why this isn't in the playbook

TNUC the binary _is_ installed by the `desktop_apps` role (via winget
over the SSH-as-mail transport), but the actual `--confirm-dl` run is
left manual on purpose: a driver swap kills any in-flight gaming
session or CUDA workload, so you choose when it runs. See README
"Platform limitations".
