# Carl Node Provisioning QR Format

`CARL://{MAC}/{KEY_HEX}`

| Component | Format | Notes |
|-------|--------|-------|
| Host (`MAC`) | 12-character lowercase hex, no separators | Sensor node BLE MAC. |
| Path (`KEY_HEX`) | 32-character lowercase hex | 16-byte AES-CCM-128 key generated at first boot. |

Example:
```
CARL://aabbccddeeff/4b1f9c8a3e2d6f70b15c4d8a9e3f2c10
```

Authoritative source: `Project-Carl/firmware/node-sensor/src/ui/oled.cpp` (renders the QR) and `Project-Carl/tools/provision.py` (bench provisioning). Keep this doc and `CarlNodeURL.swift`'s parser in sync with those.

**Display profile:** node renders this as a QR on its OLED at first boot (and on demand from the menu). The iOS app's "Add Plant" flow scans it via AVFoundation.

**Cheap profile:** no display. Two fallbacks:
1. App connects to the node's one-minute connectable BLE window after first boot, reads MAC + key from a custom GATT characteristic.
2. Manual hex entry (with paste-from-clipboard), used when the BLE handoff window has closed.

**Security:** the QR contains the AES key. Do not photograph and store; scan once during onboarding. The node should rotate its first-boot key after the first successful provisioning request lands at the hub (Carl-side TODO).
