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
- **Wakes immediately after shutdown**: stray broadcast traffic is matching
  the wake pattern. Disable `WakeOnPattern` and rely on `WakeOnMagicPacket`
  only.
