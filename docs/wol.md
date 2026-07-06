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
- Enables Wake-on-Magic-Packet on every physical NIC that is up
  (`Set-NetAdapterPowerManagement -WakeOnMagicPacket Enabled`).
- Flips Realtek's `WolShutdownLinkSpeed` from its default `10 Mbps First`
  to `Not Speed Down`. The default renegotiates the link to 10Mbit
  half-duplex on sleep — many 1G switches drop the port during
  renegotiation and the magic packet never arrives. Symptom before this
  was fixed on `shrike`: the last-wake source always reported `Power
  Button` because the NIC never received a packet to log against.

## Verify NIC settings

```powershell
Get-NetAdapter -Physical | ForEach-Object {
  $_ | Select-Object Name, Status
  Get-NetAdapterPowerManagement -Name $_.Name |
    Select-Object WakeOnMagicPacket, WakeOnPattern
}
```

Both `WakeOnMagicPacket` and `WakeOnPattern` should report `Enabled`.

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
- **Wakes immediately after shutdown**: stray broadcast traffic is matching
  the wake pattern. Disable `WakeOnPattern` and rely on `WakeOnMagicPacket`
  only.
