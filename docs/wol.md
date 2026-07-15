# Wake-on-LAN

Lets you boot `shrike` from another host on the LAN by sending a magic packet
to its MAC address. See also: [sleep-on-lan.md](sleep-on-lan.md) for the
reverse — putting `shrike` to sleep over the network.

## BIOS / UEFI prerequisites

The Ansible playbook cannot configure firmware. Manually enable in BIOS/UEFI:

- **Wake on LAN** (often under Power Management or Advanced)
- **Deep Sleep**: disabled (some boards require this for WoL after shutdown)
- **ErP / EuP Ready**: disabled (saves power but disables WoL)

## What the playbook configures

`roles/common/tasks/main.yml`:

- Disables Fast Startup (`HiberbootEnabled = 0`). Without this, Windows
  "shutdown" is actually hybrid hibernate and WoL only works from sleep,
  not from full power-off.
- Enables Wake-on-Magic-Packet and *disables* Wake-on-Pattern on every
  physical NIC that is up. Pattern-match wake fires on stray traffic
  (ARP-for-me, mDNS, broadcast chatter) which triggered spurious wakes
  from S3 on `shrike`; magic-packet-only means only deliberate WoL
  packets wake the box.
- Flips Realtek's `WolShutdownLinkSpeed` from its default `10 Mbps First`
  to `Not Speed Down`. The default renegotiates the link to 10Mbit
  half-duplex on sleep — many 1G switches drop the port during
  renegotiation and the magic packet never arrives. Symptom before this
  was fixed on `shrike`: the last-wake source always reported `Power
  Button` because the NIC never received a packet to log against.
- Strips wake capability from noisy USB host controllers via
  `powercfg /devicedisablewake`. USB xHCI wake propagates spontaneous
  device activity (mouse jitter, Oculus Link cable polling, wireless
  dongles) into a full platform wake. HID keyboard/mouse entries keep
  their individual wake capability so key presses at the desk still
  work — see `wake_disable_devices` in `roles/common/defaults/main.yml`.

## Why the link-speed setting matters

Ethernet link is a continuously-maintained physical layer state, not a
per-packet transaction. When `shrike` enters S3 with the default
`WolShutdownLinkSpeed = 10 Mbps First`, the Realtek PHY doesn't just
drop TX power — it initiates an IEEE 802.3 auto-negotiation cycle to
renegotiate down to 10Base-T half-duplex. That renegotiation takes
several hundred milliseconds during which the physical link is *down*:
the pilot signal disappears, the switch's port MAC transitions out of
the forwarding state, and any traffic destined for that port (unicast
or broadcast) is dropped by the switch's forwarding fabric, not by the
NIC. Magic packets sent from the controller during that window never
reach the PHY at all, so the NIC's WoL detection circuit — which is
fully powered and armed — has nothing to match against. Some switches
will also invalidate the port's MAC learning entry as soon as the link
drops, so subsequent unicast magic packets are treated as unknown and
get flooded (unmanaged switches) or dropped (managed switches with
strict learning). Setting the property to `Not Speed Down`
(`RegistryValue = 2`) instructs the driver to keep the link at native
1Gbit full-duplex through S3; the switch never sees a link-down event,
MAC learning stays valid, packet forwarding continues, the magic packet
lands, and the NIC's PME# / PWRBTN# assertion wakes the platform. The
trade-off is minor — the NIC keeps drawing ~1W of standby power instead
of ~0.2W — in exchange for WoL that actually works.

## Verify NIC settings

```powershell
Get-NetAdapter -Physical | ForEach-Object {
  $_ | Select-Object Name, Status
  Get-NetAdapterPowerManagement -Name $_.Name |
    Select-Object WakeOnMagicPacket, WakeOnPattern
}
```

`WakeOnMagicPacket` should be `Enabled`, `WakeOnPattern` should be
`Disabled` (see the pattern-wake note above).

## Find the MAC

```powershell
Get-NetAdapter -Physical | Where-Object Status -eq 'Up' |
  Select-Object Name, MacAddress
```

## Send a magic packet

From any Linux host on the same broadcast domain:

```sh
wakeonlan AA:BB:CC:DD:EE:FF
# or
etherwake AA:BB:CC:DD:EE:FF
```

From macOS:

```sh
brew install wakeonlan
wakeonlan AA:BB:CC:DD:EE:FF
```

## Troubleshooting

- **Wakes from sleep but not shutdown**: Fast Startup is still on, or BIOS is
  in deep sleep / ErP mode.
- **Doesn't wake at all**: NIC has no standby power. Check that the LAN LED
  on the NIC is still lit after shutdown. If not, BIOS WoL is off or the NIC
  doesn't support it.
- **Doesn't wake even though the LAN LED stays lit**: your switch is
  probably dropping the port when the NIC renegotiates to a lower speed on
  sleep. The `common` role flips `WolShutdownLinkSpeed = Not Speed Down`
  on Realtek NICs to keep the link at native speed through S3 — verify
  with `Get-NetAdapterAdvancedProperty -RegistryKeyword WolShutdownLinkSpeed`.
- **Windows reports "Power Button" for a real WoL wake**: on Realtek NICs
  the wake is signalled by pulling PWRBTN# rather than PME#, so ACPI logs
  it as the power button. Cross-check by pinging the host before/after
  sending the packet.
- **Wakes immediately after shutdown or from S3 without a magic packet**:
  either `WakeOnPattern` slipped back to `Enabled` (stray broadcast /
  ARP traffic matches), or a wake-armed device is signalling. Check
  `Get-NetAdapterPowerManagement` and `powercfg /devicequery wake_armed`
  respectively; the `common` role keeps `WakeOnPattern=Disabled` and
  removes known-noisy USB host controllers from the wake_armed list.
- **Persistent spurious wakes from S3**: pull `Get-WinEvent
  -FilterHashtable @{LogName='System'; Id=1; ProviderName='Microsoft-Windows-Power-Troubleshooter'}`
  for the last few days. If a device name keeps appearing as the wake
  source, add its exact `powercfg /devicequery wake_armed` name to
  `wake_disable_devices` in `roles/common/defaults/main.yml`.
