# Project-Carl-IOS

The iOS app for **Project Carl** — a home plant-monitoring system. Friendly dashboard on your phone for the plants Carl is watching, with a "non-techy by default" UI that hides raw sensor numbers behind an opt-in advanced view.

## What this repo is

Carl-IOS is the **user-facing app** in a three-repo system:

| Repo | Role |
|---|---|
| [`Project-Carl`](https://github.com/manu897/Project-Carl) | Zephyr / ESP-IDF firmware — BLE sensor nodes + ESP32 hub |
| `Project-Carl-IOS` | **iOS app — user-facing dashboard (this repo)** |
| [`Project-Norman`](https://github.com/manu897/Project-Norman) | Cloud — ingest, time-series storage, REST API, ML |

The app talks to the Carl hub over HTTP on the local Wi-Fi (live readings, history, plant onboarding) and falls back to Norman in the cloud when the phone is away from home.

```
                  ┌────────────────────┐
                  │   iPhone — Carl    │
                  │  (this repo's app) │
                  └────────┬───────────┘
                           │
        ┌──────────────────┴───────────────────┐
        │ on home Wi-Fi                        │ off home Wi-Fi
        ▼                                      ▼
┌──────────────────┐                  ┌────────────────────┐
│  carl-hub.local  │  MQTT / HTTPS    │   Project-Norman    │
│   (ESP32 hub)    │ ── batch ──────▶ │  (cloud / ML / DB)  │
└────────┬─────────┘                  └──────────┬─────────┘
         │                                        │
         │ BLE BTHome v2 (AES-CCM-128)            │ JWT-authed
         ▼                                        │ REST (/v1/…)
   [Sensor nodes × N]   [Room nodes × N]   iOS reads either side ──┘
                                            through the same models
```

Reads try the hub first (fast, LAN-only) and silently fall back to Norman when it's unreachable — see [Cloud account / off-LAN fallback](#cloud-account--off-lan-fallback) below. Writes (adding a plant, hub Wi-Fi setup) always go straight to the hub; those only make sense while actually near it.

## What's inside

- [`CarlApp/`](CarlApp/) — SwiftUI app (iOS 17+, Swift 5.10), organized by feature folder.
- [`CarlApp/ML/`](CarlApp/ML/) — on-device plant species classifier (Vision framework).
- [`CarlApp/Networking/`](CarlApp/Networking/) — `HTTPHubClient` (LAN), `NormanClient` (cloud), `CompositeHubClient` (LAN-first/cloud-fallback), Keychain-backed auth session.
- [`CarlApp/Features/Account/`](CarlApp/Features/Account/) — Norman sign-in / create-account UI.
- [`api/openapi.yaml`](api/openapi.yaml) — the hub HTTP contract this app consumes (mirror of the spec in `Project-Carl`, kept in sync — currently v0.3.0).
- [`docs/design.md`](docs/design.md) — design philosophy, screen-by-screen breakdown with screenshots (light + dark), design-system tokens, open questions for UI/UX collaboration.
- [`docs/qr-format.md`](docs/qr-format.md) — `carl://node?mac=…&key=…` provisioning URL spec used during plant onboarding.
- [`CarlApp/Resources/Mocks/`](CarlApp/Resources/Mocks/) — JSON fixtures that back `MockHubClient` so the UI works without a real hub.

## Stack

SwiftUI · Swift Concurrency (`async/await`) · Swift Charts · Vision / Core ML (on-device species ID) · CoreBluetooth · Network.framework (Bonjour discovery) · Keychain (cloud auth token) · Single app target, organized by feature folder.

## Quickstart

See [SETUP.md](SETUP.md) for the full instructions. Short version:

```bash
brew install xcodegen
xcodegen generate
open CarlApp.xcodeproj
```

The app boots against fixtures by default (`useMockHub = true` in [`AppEnvironment.swift`](CarlApp/App/AppEnvironment.swift)) — flip to `false` in Settings to drive a real hub over the local network.

## Status

Everything below is built and running end-to-end (mock fixtures + real hub), with a clean build on Xcode 15.3+ and passing unit tests.

**Core app**
- Home list, plant detail (health card + advanced Swift Charts, 24h/7d/30d), Settings — all in dark mode too.
- **Room nodes** (Carl API v0.3.0): plant vs. room node types render differently — room nodes skip soil/watering rows, show their own "Room environment" card, and read "Online" rather than "Healthy" (a room sensor has no plant to be healthy); plants sharing a `room_id` display that room's ambient readings automatically (`Plant.room`, grafted server-side).

**Onboarding (Add Plant)**
- QR scan or manual MAC/key entry, photo capture, hub provisioning.
- **On-device plant species detection** ([`PlantClassifier`](CarlApp/ML/PlantClassifier.swift)) — Vision's built-in classifier suggests a species from the photo (swappable for a custom Core ML model later); accepting a suggestion auto-fills the name and pre-selects per-species calibration thresholds from [`SpeciesCatalog`](CarlApp/Models/SpeciesCatalog.swift) (~20 common houseplants).

**Hub connectivity**
- Hub Wi-Fi onboarding via the captive-portal flow.
- Local push alerts (dry soil / low battery / offline), rate-limited per plant, with per-plant mute — foreground + `BGAppRefreshTask` background evaluation.
- Fixed a live bug where `/api/nodes/{id}/history?range=…` requests silently mangled the query string (`URL.appendingPathComponent` was percent-encoding `?`); real hub history charts now work.

**Cloud account / off-LAN fallback**
- Sign in or create a Norman account from Settings → *Away from home* ([`NormanAccountView`](CarlApp/Features/Account/NormanAccountView.swift)). JWT stored in Keychain.
- [`CompositeHubClient`](CarlApp/Networking/CompositeHubClient.swift): reads try the hub first (short-timeout LAN probe), fall back to Norman's `/v1/…` API when off-network. Writes always stay hub-only. Both legs race a hard wall-clock deadline independent of `URLSessionConfiguration` timeouts (mDNS resolution for `carl-hub.local` doesn't reliably honor those) — worst case ~17s before either data or a real error, never an indefinite spinner.
- One shared `URLSession` per client (LAN and Norman), reused across every screen — avoids paying a fresh TLS handshake to Norman on every navigation. Matters more than it sounds: Norman is US-hosted (GCP `us-central1`), so each handshake is real round-trip time.
- ⚠️ **Known gap:** claiming a hub under your Norman account (`POST /v1/hubs`) has no in-app flow — it's a one-time manual `curl` step today (see `Project-Carl`'s README, "Connecting a hub to Project-Norman"). Works once done; just not self-service yet. See Future plans.
- **Offline cache**: the plant list shows the last-known data instantly on launch ([`PlantCacheStore`](CarlApp/Persistence/PlantCacheStore.swift)), then replaces it with a live fetch. A quiet "Updated Xh ago" caption tracks freshness; past 24h with no successful refresh, an explicit "No recent data" banner replaces the quiet caption so stale numbers are never shown silently. Never reads/writes mock fixtures.

**Reliability fixes from real-device testing**
- `Plant` decoding tolerates Norman's nullable `last_seen`/`latest` (a node that's never reported) — previously one bad node failed the whole list.
- Norman requests opt out of HTTP/3/QUIC (`assumesHTTP3Capable = false`) — some networks corrupt QUIC handshakes in ways that hang or fail a request while plain TLS-over-TCP works fine.
- `HubError` conforms to `LocalizedError` — errors used to surface as Swift's generic fallback text; now the real message shows.

## Future plans

Roughly in priority order:

1. **Hub-claiming flow** — replace the manual `curl POST /v1/hubs` step with an in-app setup screen (likely folded into Hub Wi-Fi setup) that surfaces the one-time hub API token and gets it onto the hub itself.
2. **Widgets** — home/lock-screen widget showing the worst-status plant (separate WidgetKit target sharing the existing models).
3. **Custom Core ML species model** — train on ~30–50 common houseplants in Create ML for real species accuracy, replacing/augmenting the built-in Vision classifier.
4. **Multi-hub support** — `HubDiscovery` currently resolves a single `carl-hub.local`; extend to NWBrowser-based discovery for multiple hubs (relevant once Norman's per-user multi-hub model is exercised from the app).
5. **Manual "I just watered" logging** — user-triggered watering events to complement/correct the soil-moisture-rising-edge detection.
6. **Apple Home hand-off** — once the hub firmware exposes Matter (no work started there yet), add an "Add to Apple Home" affordance.

Open UX questions (plant catalogue depth, room-vs-plant list presentation, notification defaults, etc.) are tracked in [`docs/design.md`](docs/design.md#5-open-questions-for-design-collaboration).

## Author

[Manideep Reddy Tamma](https://www.linkedin.com/in/manideep-reddy-tamma/)
