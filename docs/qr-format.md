# Carl Node Provisioning QR Format

`carl://node?mac={MAC}&key={KEY_HEX}`

| Param | Format | Notes |
|-------|--------|-------|
| `mac` | `AA:BB:CC:DD:EE:FF` (uppercase, colon-separated) | Sensor node BLE MAC. URL-encode the colons (`%3A`). |
| `key` | 32-character lowercase hex | 16-byte AES-CCM-128 key generated at first boot. |

Example:
```
carl://node?mac=AA%3ABB%3ACC%3ADD%3AEE%3AFF&key=4b1f9c8a3e2d6f70b15c4d8a9e3f2c10
```

**Display profile:** node renders this as a QR on its OLED at first boot (and on demand from the menu). The iOS app's "Add Plant" flow scans it via AVFoundation.

**Cheap profile:** no display. Two fallbacks:
1. App connects to the node's one-minute connectable BLE window after first boot, reads MAC + key from a custom GATT characteristic.
2. Manual hex entry (with paste-from-clipboard), used when the BLE handoff window has closed.

**Security:** the QR contains the AES key. Do not photograph and store; scan once during onboarding. The node should rotate its first-boot key after the first successful provisioning request lands at the hub (Carl-side TODO).
