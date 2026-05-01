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
│  carl-hub.local  │                  │   Project-Norman   │
│   (ESP32 hub)    │ ── daily POST ─▶ │  (cloud / ML / DB) │
└────────┬─────────┘                  └────────────────────┘
         │
         │ BLE BTHome v2 (AES-CCM-128)
         ▼
   [Sensor nodes × N]   [Camera node × 1]
```

## What's inside

- [`CarlApp/`](CarlApp/) — SwiftUI app (iOS 17+, Swift 5.10).
- [`api/openapi.yaml`](api/openapi.yaml) — the hub HTTP contract this app consumes (mirror of the spec to land in Project-Carl).
- [`docs/design.md`](docs/design.md) — design philosophy, screen-by-screen breakdown with screenshots (light + dark), design-system tokens, open questions for UI/UX collaboration.
- [`docs/qr-format.md`](docs/qr-format.md) — `carl://node?mac=…&key=…` provisioning URL spec used during plant onboarding.
- [`CarlApp/Resources/Mocks/`](CarlApp/Resources/Mocks/) — JSON fixtures that back `MockHubClient` so the UI works without a real hub.

## Stack

SwiftUI · Swift Concurrency (`async/await`) · Swift Charts · CoreBluetooth · Network.framework (Bonjour discovery) · Single app target, organised by feature folder.

## Quickstart

See [SETUP.md](SETUP.md) for the full instructions. Short version:

```bash
brew install xcodegen
xcodegen generate
open CarlApp.xcodeproj
```

The app boots against fixtures by default (`useMockHub = true` in [`AppEnvironment.swift`](CarlApp/App/AppEnvironment.swift)) — flip to `false` to drive a real hub via Bonjour discovery once Carl Phase 3 hub firmware is running on the LAN.

## Status

Scaffold + Home + Plant-detail screens running end-to-end against fixtures. Build clean on Xcode 15.3+. Add Plant flow, hub Wi-Fi onboarding, alert engine, Norman cloud failover, and SwiftData persistence are planned next — see [`docs/design.md`](docs/design.md) and the parent project plan.

## Author

[Manideep Reddy Tamma](https://www.linkedin.com/in/manideep-reddy-tamma/)
