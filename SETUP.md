# CarlApp — Setup

## Prerequisites
- Xcode 15.3+ (iOS 17 SDK, Swift 5.10)
- macOS 14+
- [XcodeGen](https://github.com/yonoz/XcodeGen) (`brew install xcodegen`)

## Generate the Xcode project
```bash
xcodegen generate
open CarlApp.xcodeproj
```

`project.yml` is the source of truth for the project structure — never edit `CarlApp.xcodeproj` by hand. Add new files to the `CarlApp/` folders and re-run `xcodegen generate`.

## Run in the simulator (no hub needed)

The app launches in **Mock mode** by default — `MockHubClient` serves the JSON fixtures in `CarlApp/Resources/Mocks/` so you can develop the entire UI without a real hub on the network.

Hit ⌘R in Xcode against any iOS Simulator destination.

## Deploy to a real iPhone

### 1. Add your signing team

Open `CarlApp.xcodeproj` → select the `CarlApp` target → **Signing & Capabilities** → **Team**: pick your Apple ID (free personal team works; a paid Developer Program account gives wider entitlements).

> The team isn't checked in to `project.yml` — every developer fills in their own.

### 2. Build to device
- Plug the iPhone into your Mac via USB (or set up Wireless Debugging via Xcode → Window → Devices and Simulators).
- The first time, you'll need to **trust** the developer certificate on the phone: Settings → General → VPN & Device Management → tap your account → Trust.
- Pick the device in the destination dropdown and hit ⌘R.

### 3. Point the app at your hub

Once the app is running on the phone:
1. Tap the **gear** icon (top-left of My Plants).
2. Turn **Use mock data** off.
3. The footer line confirms the app will now talk to `http://carl-hub.local` on the local Wi-Fi.

Requirements for the phone:
- On the **same Wi-Fi network** as the Carl hub.
- Local Network permission granted (iOS prompts the first time the app tries to discover `_carl-hub._tcp`).

### 4. What you'll see

| Hub firmware phase | App behavior |
|---|---|
| **3a** (HTTP server only, empty `/api/nodes`) | "My Plants" loads with an empty list — confirms LAN connectivity. |
| **3b+** (BLE scanner + registry populated) | Real plant cards appear. The hub currently emits `last_seen` / `ts` as relative seconds-ago strings; the iOS decoder handles that until Phase 3d's SNTP adds ISO 8601 timestamps. |
| **3d+** (SNTP) | iOS automatically switches to ISO 8601 parsing — no app change needed. |
| **future** (`/api/stream` WebSocket) | Live updates without pull-to-refresh. The app silently falls back to pull-to-refresh when this endpoint isn't there. |

## Cross-repo coordination
- `api/openapi.yaml` in this repo is the **iOS-side mirror** of the Carl hub HTTP contract; authoritative copy lives in `Project-Carl/documents/api/openapi.yaml`.
- `docs/qr-format.md` is the same: mirror of the Carl-side spec.
- Plant profile picture upload (`PUT /v1/plants/{id}/profile-photo`) — Norman-side endpoint coordination.
