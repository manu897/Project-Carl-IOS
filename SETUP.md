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

### 3. Point the app at your hub — and optionally the cloud

Once the app is running on the phone:
1. Tap the **gear** icon (top-left of My Plants).
2. Turn **Use mock data** off.
3. The footer line confirms the app will now talk to `http://carl-hub.local` on the local Wi-Fi.

Requirements for the phone:
- On the **same Wi-Fi network** as the Carl hub.
- Local Network permission granted (iOS prompts the first time the app tries to discover `_carl-hub._tcp`).

**Away from home?** Sign in under **Settings → Away from home → Cloud account** (creates/uses a Norman account). Once signed in, reads fall back to Norman's cloud API whenever the hub isn't reachable — no further app setup needed. This only works if your hub has already been *claimed* under that Norman account; that's currently a manual step, not an in-app one — see `Project-Carl`'s README, "Connecting a hub to Project-Norman."

### 4. What you'll see

The hub API is at **v0.3.0** ([`api/openapi.yaml`](api/openapi.yaml)) — `/api/health`, `/api/nodes` (list/create/update/delete), `/api/nodes/{id}/history`, `/api/setup/wifi` are all implemented, including `node_type` (plant/room) and `room_id`. `/api/stream` (WebSocket live updates) is specced but not implemented on the hub yet — the app always falls back to pull-to-refresh for that, no error shown.

Plant sensor nodes render as plant cards; room/ambient nodes (Thingy:53) render distinctly — a "Room" badge, no soil/watering rows, their own environment card. On first launch with no cached data you'll see a brief "Looking for plants…" spinner; after that, the app shows last-known data instantly and refreshes live in the background (see the offline-cache note in [docs/design.md](docs/design.md#21-home--my-plants)).

Provisioning a new sensor node: scan its QR code (format `CARL://<12-hex-MAC>/<32-hex-key>`, see [docs/qr-format.md](docs/qr-format.md)) or enter the MAC/key manually.

## Cross-repo coordination
- `api/openapi.yaml` in this repo is the **iOS-side mirror** of the Carl hub HTTP contract; authoritative copy lives in `Project-Carl/documents/api/openapi.yaml` — currently v0.3.0 on both sides.
- `docs/qr-format.md` is the same: mirror of the Carl-side spec (`CARL://<12-hex-MAC>/<32-hex-key>`, matching `Project-Carl/firmware/node-sensor/src/ui/oled.cpp`).
- Plant profile photos are stored **locally on-device only** (`PhotoStore`) — there's no Norman upload endpoint for them today, and per an earlier product decision camera-node imagery generally stays on the hub, not Norman. Revisit this line if that changes.
- Hub → Norman data flow is MQTT-only right now (Carl's `norman_uplink.c`); the HTTPS batch alternative (`POST /v1/hubs/{id}/batch`) exists on Norman's side but nothing currently uses it.
