# Hub City Transit — Flutter App

A mobile companion to the [Hub City Transit web app](https://hubcitytransitv2.mukeshpoudel.com.np/), bringing real-time bus tracking for Hattiesburg, MS to Android (and eventually iOS).

> **Work in progress** — Play Store release coming soon.

---

## What is this

Hub City Transit is a community transit tracker for the Hattiesburg Metro Area. The web version has been live for a while now; this repo is the Flutter mobile port of that same experience.

Both apps share the same live data pipeline — ArcGIS for real-time GPS, and a locally bundled schedule that gets adjusted based on where the bus actually is.

---

## Features

- **Live bus tracking** on an interactive map (OpenStreetMap tiles via flutter_map)
- **Real-time arrival estimates** — not just the printed schedule. If the bus is running 4 minutes late, the arrivals reflect that
- **Trip planner** — type any address or landmark, and the app figures out which stop to walk to, which bus to take, and where to get off. Draws the full walk + ride route on the map
- **All 6 routes** — Blue, Green, Red, Orange, Purple, Brown
- **Transfer detection** at shared stops (tap the chip to switch routes)
- **Dark mode** + dark map basemap toggle
- **Schedule view** with live status badge
- Map state persists across tab switches — camera position, selected stop, active trip all stay put

---

## How the arrival estimates work

This is probably the most interesting part of the app.

The printed schedule tells you when a bus *should* be at each stop. But if the bus is running behind, all the future arrivals shift too. The app does this automatically:

1. Snaps the bus's current GPS position to the nearest stop on its route
2. Compares where the bus *is* vs where it *should be* at this time (based on the schedule)
3. Computes a time delta (e.g. +4 mins late)
4. Applies that delta to every upcoming stop on that trip

When the bus GPS goes offline, the delta drops to zero and it falls back to the printed schedule gracefully. This mirrors exactly what the web app does.

---

## Getting started

### Prerequisites

- Flutter 3.x
- Android SDK (for Android builds)
- A `.env` file in the project root (see below)

### Setup

```bash
git clone https://github.com/ThorOdinson246/hubcitytransit
cd hubcitytransit/flutter_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

Create a `.env` file in `flutter_app/`:

```
ARCGIS_URL=<your arcgis endpoint>
HCT_BASE_API_URL=<api base url>
GOOGLE_MAPS_API_KEY=<optional>
```

Then run:

```bash
flutter run
```

---

## Project structure

```
lib/
├── src/
│   ├── app/          providers (Riverpod), router (GoRouter)
│   ├── core/         constants, theme, network, utilities
│   ├── data/         models (Freezed), repository, services
│   ├── domain/       repository interface, schedule adjustment use case
│   └── features/     map, schedule, settings, fares, onboarding, about
```

State management is Riverpod. Navigation is GoRouter with `StatefulShellRoute` so the map keeps its state when you switch tabs.

---

## Notes

- The route/stop/schedule data files are not included in this repo — they're proprietary and bundled into the app binary at build time
- Generated Dart files (`*.freezed.dart`, `*.g.dart`) are gitignored — run `build_runner` to regenerate after cloning
- This is a solo project, built alongside a full-time grad program, so updates come in waves

---

## Related

- Web app: [hubcitytransitv2.mukeshpoudel.com.np](https://hubcitytransitv2.mukeshpoudel.com.np/)
