# Gaming

> **Status:** unreviewed. Not yet executed on `shrike`. Lives on
> branch `unreviewed/desktop-and-gaming`. Verify each task interactively
> before promoting.

`shrike` is the at-the-desk gaming PC and the streaming host for Steam
Remote Play (headless via dummy plug). The `gaming` role keeps the
Remote Play surface consistent across rebuilds.

## What the role does

- **Steam Remote Play registry** — sets `EnableRemotePlay=1` under
  `HKCU:\Software\Valve\Steam` and pins the server port range to start
  at 27031 under `HKCU:\Software\Valve\Steam\Streaming`.
- **Firewall** — inbound UDP 27031-27036 allowed on domain and private
  profiles via `community.windows.win_firewall_rule`.

Windows handles real controllers (Xbox / DualSense / DualShock) natively.
A virtual-bus driver like ViGEmBus is only needed if you use shims
(DS4Windows, HidHide, reWASD) — install those manually if/when you need
them; they are not part of this role.

## After provisioning

Steam itself is installed by the `common` role (winget `Valve.Steam`).
After the playbook finishes:

1. Sign into Steam at least once interactively. Remote Play requires an
   active user session.
2. Pair the controlling device by clicking the Steam Link prompt on the
   client; the host's pairing code lives in **Settings → Remote Play**.

## Verifying Remote Play is reachable

From the controller host:

```sh
nc -zvu shrike.local 27031
```

`Connection successful` on UDP 27031 confirms the firewall rule is live.

## Troubleshooting

- **No video on client**: the host must be signed in and unlocked. Remote
  Play cannot wake the login screen. See `docs/unattended.md` for the
  autologon arrangement that keeps the session live across reboots.
- **Black frame on client with no monitor attached**: Steam Remote Play
  needs a real display target. `shrike` uses a hardware dummy HDMI plug
  for headless operation; if the plug is unseated, the GPU presents no
  display and Remote Play renders nothing.
