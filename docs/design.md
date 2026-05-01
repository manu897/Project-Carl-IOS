# Carl iOS — Design

This document is the shared reference for UI/UX collaboration on the Carl iOS app. It captures the design philosophy, the screen-by-screen breakdown with current screenshots, the underlying design system, and the open questions we'd want a designer's input on.

The screenshots are generated from the in-app `MockHubClient` (see [SETUP.md](../SETUP.md)) — they reflect what real plants will look like once the Carl hub HTTP API is live, just with fixture data.

---

## 1. Design philosophy

Carl's owners are plant lovers, not engineers. The interface should feel like **a friend who keeps an eye on your plants**, not a sensor dashboard.

Three rules shaping every decision:

1. **Words before numbers.** Default views say "Healthy", "Needs water", "Light: Good". Raw values (42 % soil, 22.4 °C, 312 lx) live behind an opt-in **Show advanced** disclosure for the curious.
2. **Action over diagnosis.** Tell the user *what to do* ("Soil is dry — time to water") before *what's wrong* ("Soil moisture below 25 %").
3. **Quiet when nothing's wrong.** A healthy plant should look calm — green pill, "Looking healthy" subtitle, and that's it. The interface only escalates colour and language when attention is needed.

System design notes:
- Uses **iOS semantic colours** (`secondarySystemBackground`, `tertiarySystemBackground`) so dark mode works automatically — no parallel palette to maintain.
- Status colour vocabulary is consistent across cards, pills, and the health table: **green = healthy**, **orange = needs attention**, **red = urgent (low battery)**, **gray = offline/unknown**.
- Apple Home / HomePod integration is intentionally **not** in the iOS app — it lives in the hub firmware (Matter bridge), so plants appear natively in the Home app and work even when the phone is asleep.

---

## 2. Screens

### 2.1 Home — *My Plants*

The first thing the user sees. A scrollable list of plant cards. Each card is a single tap target leading to detail.

| Light | Dark |
|---|---|
| ![Home — light](screenshots/01-home-light.png) | ![Home — dark](screenshots/04-home-dark.png) |

**What's on a card:**
- 56 × 56 photo placeholder (becomes the user-uploaded profile picture once the Norman photo endpoint ships).
- Plant name (bold).
- One-line, plain-language status subtitle that changes with the plant's condition:
  - *"Looking healthy"* (green-secondary)
  - *"Soil is dry — time to water"* (orange — calls action)
  - *"Sensor battery is low"* (red — urgent)
  - *"Hasn't reported recently"* (gray — quiet)
- Relative "Last seen" timestamp.
- Right-aligned **status pill** mirroring the subtitle's intent (Healthy / Needs water / Battery low / Offline).

**Interactions:**
- Pull-to-refresh.
- Tap card → Plant detail.
- `+` button (top-right): Add Plant — wired but disabled in this scaffold; lands in a follow-up commit.

**Empty/loading/error states** are handled by `ContentUnavailableView` and `ProgressView` (not shown in screenshots; covered in code at [HomeView.swift](../CarlApp/Features/Home/HomeView.swift)).

---

### 2.2 Plant detail — default health view

Tapping a card opens this. Photo header, then a single tidy table of plain-language health rows. **No numbers visible by default.**

| Light | Dark |
|---|---|
| ![Detail — light](screenshots/02-detail-light.png) | ![Detail — dark](screenshots/05-detail-dark.png) |

**Health rows in order:**

| Row | Possible values | Notes |
|---|---|---|
| **Status** | Healthy / Needs water / Battery low / Offline | Mirrors the home pill. |
| **Last watered** | "Today" / "Yesterday" / "*N* days ago" / "Not detected" | Detected as a soil-moisture rising edge (≥ +10 percentage points within ~1h). Falls back to "Not detected" when no event found in window — better honest than wrong. |
| **Water again** | "Now" / "Tomorrow" / "In *N* days" / "—" | Linear extrapolation from the last 12h drying rate to the dry threshold. "—" when soil isn't dropping. |
| **Light** | Good / Low / High / — | vs. generic indoor range 200–2000 lx. Will be per-species when catalogue lands. |
| **Temperature** | Good / Low / High / — | vs. 18–26 °C. |
| **Humidity** | Good / Low / High / — | vs. 40–70 %. |

The bottom **Show advanced** disclosure expands to the technical view (next screen).

---

### 2.3 Plant detail — advanced

For users who want the numbers. Disclosed by tapping **Show advanced**. Three sections, top to bottom:

| Light | Dark |
|---|---|
| ![Advanced — light](screenshots/03-detail-advanced-light.png) | ![Advanced — dark](screenshots/06-detail-advanced-dark.png) |

1. **Current readings grid** — Soil, Temperature, Humidity, Light, Battery, Pressure as labelled big numbers.
2. **24h / 7d / 30d** segmented picker — drives the chart and stats below.
3. **Chart cards**, one per metric (Soil moisture, Temperature, Humidity, Light):
   - Title + **Min · Avg · Max** for the selected period in the header.
   - Smooth-interpolated line plot (Swift Charts).
   - Faint dashed line at the average for visual anchoring.

The grid + charts cover the same ground the original "tech" view did, just one tap deeper.

---

## 3. Design system

### Typography
- All built-in iOS dynamic type. No custom fonts.
- **`.headline`** — plant name on cards.
- **`.subheadline.weight(.medium)`** — chart titles, advanced toggle label.
- **`.caption`** / **`.caption2.weight(.semibold)`** — chips, pills, secondary metadata.
- **`.title3.weight(.semibold)`** — big numbers in the metrics grid.

### Colour
| Token | Light | Dark | Used for |
|---|---|---|---|
| `secondarySystemBackground` | very-light gray | dark gray | All card surfaces |
| `tertiarySystemBackground` | white | near-black | Photo placeholder |
| `.green` (system) | system green | system green | Healthy / Good |
| `.orange` (system) | system orange | system orange | Needs water / High / Attention |
| `.red` (system) | system red | system red | Battery low |
| `.blue` (system) | system blue | system blue | Soil-moisture chart, "Low" markers |
| `.gray` / `.secondary` | system | system | Offline, secondary text |

We never specify hex colours — every surface adapts to dark mode for free.

### Components
- **`PlantCardView`** — the home-screen card. Composes a photo placeholder, name + summary line, and a `StatusPill`.
- **`StatusPill`** — coloured capsule used both on cards and in the Status row.
- **`HealthRow`** — label/value row in the detail health table.
- **`Metric`** — small "label over big number" cell in the advanced grid.
- **`ChartCard`** — title + Min/Avg/Max header + Swift Chart line + dashed average rule.

All components live as private structs inside their feature folder; promote to a shared `Components/` group only when reused across features.

### Spacing & shape
- 14–16 pt card corner radius.
- 12–14 pt internal card padding.
- 12 pt gap between vertically stacked cards.
- 16 pt screen-edge inset.

---

## 4. Information architecture

```
My Plants                            (HomeView)
 ├── Plant card × N                  (PlantCardView)
 │    └── Plant detail               (PlantDetailView)
 │         ├── Health card           (rows: status / watered / water-again / L / T / H)
 │         └── Advanced (toggle)
 │              ├── Metrics grid
 │              ├── Range picker  (24h / 7d / 30d)
 │              └── Chart cards × 4
 └── + Add plant                     (AddPlantView — TODO)
```

Future screens (planned, not built):
- **Add plant** — QR scan, plant photo capture, name, register with hub.
- **Hub Wi-Fi setup** — onboard the ESP32 hub onto home Wi-Fi via `Carl-Hub-Setup` SoftAP.
- **Settings** — Norman cloud account, notification preferences, hub info, about.

---

## 5. Open questions for design collaboration

These are the decisions where a designer's input would materially shift the product:

1. **Photo placeholder.** Right now it's an SF Symbol leaf. Once Norman's `/v1/plants/{id}/profile-photo` endpoint exists, we get user-uploaded photos. Do we want a more polished placeholder (rotating illustrations? Plant-type icons?) for plants without photos?
2. **Plant catalogue.** "Light: Good" vs. generic ranges is a stopgap. Real plant species have very different ranges (a fern wants different light than a succulent). Need: a plant-species selector at onboarding, plus per-species threshold defaults. Where in the onboarding flow does that fit, and how do we handle "I don't know the species"?
3. **Watering as an event.** "Last watered" is currently detected from soil-moisture rises. Should the user also be able to log a watering manually ("I just watered the basil")? If yes, where does that affordance live — a button on the detail screen, a swipe action on the card?
4. **Notifications.** Local push for dry soil, low battery, offline. What's the right default — silent, banner, or both? Quiet hours? Per-plant mute?
5. **Apple Home hand-off.** When the hub firmware exposes Matter, the iOS app will offer "Add to Apple Home". Where does that affordance sit — inside Settings, on each plant's detail screen, or as a one-time setup step after hub onboarding?
6. **Empty state for Home.** The very first launch (no plants paired yet) should feel inviting and lead clearly into onboarding the hub + first plant. Currently it just shows `ContentUnavailableView`.
7. **Camera-node imagery (long-term).** The Carl camera node feeds the Norman ML pipeline for plant-health analysis. There's no plan today to surface the camera images themselves in the iOS app, but if Norman returns a "your plant looks healthy / wilted" verdict, where does that show up?

---

## 6. Assets

- All screenshots in [screenshots/](screenshots/) are PNGs from the iPhone 17 Pro simulator (1206 × 2622 logical pixels).
- Regenerate via `xcrun simctl launch <device> com.projectcarl.CarlApp -screenshotEntry=<home|detail|detailAdvanced>` after wiring the screenshot shim back in (see commit history) and toggling appearance with `xcrun simctl ui <device> appearance light|dark`.

---

## 7. References

- App scaffold: [CarlApp/](../CarlApp/)
- Hub HTTP contract this UI consumes: [api/openapi.yaml](../api/openapi.yaml)
- High-level architecture across all three repos (Carl firmware, Norman cloud, this app): see the parent project plan in `~/.claude/plans/i-am-planning-to-pure-hamming.md`.
