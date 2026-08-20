# Hub City Transit — LLM Project Handover Context

## Project Overview
This project is a mobile companion app (Flutter/Dart) for the Hub City Transit web application. It tracks buses in Hattiesburg, MS in real-time, displays schedules, outlines fares, and offers step-by-step trip planning.

The project recently completed a major migration from a Next.js/React-Leaflet PWA into a native Flutter application built with Material 3.

## Architectural Intent & Conventions
- **Framework:** Flutter 3.x using `MaterialApp.router` (Material 3).
- **State Management:** Riverpod (`flutter_riverpod`). The app relies on providers like `StateNotifierProvider` and `FutureProvider` to handle routing state, theme persistence, and active bus polling.
- **Routing:** `go_router` with a `StatefulShellRoute` for the main bottom navigation (Map, Schedule, Fares). This ensures the map state is kept alive when navigating between tabs.
- **Map Engine:** `flutter_map` using CARTO raster tiles (with Dark Mode tile support). We render vector `Polyline`s for routes and custom `Marker`s for buses and stops.
- **Location & Permissions:** `geolocator` is used for GPS streams. The app includes a dedicated Settings page (`/settings`) that links directly to native OS App Settings and OS Location Settings.
- **Data Persistence:** `shared_preferences` is used to persist the `ThemeMode` (System, Light, Dark), the Onboarding 'seen' flag, and the user's preference for 'Dark Map Tiles'.

## Folder Structure
```text
lib/
├── main.dart
├── src/
│   ├── app/
│   │   ├── app.dart              // MaterialApp.router setup
│   │   ├── providers.dart        // Core Riverpod providers (theme, basemap, routes, stops, bus polling, geolocator stream)
│   │   └── router/               // GoRouter and ShellRoute definitions
│   ├── core/
│   │   └── constants/            // Route metadata, hex colors, transit IDs, etc.
│   ├── data/
│   │   └── models/               // Domain entities (StopModel, RoutePolylineModel, BusLocationModel)
│   ├── domain/                   // Use cases (ScheduleAdjustmentUseCase)
│   ├── features/
│   │   ├── about/                // Static about page / legend
│   │   ├── fares/                // Fares & ticket info tab
│   │   ├── map/                  // Map view, MapController, floating bottom sheets, TripPlanner
│   │   ├── onboarding/           // First-launch splash screens
│   │   ├── schedule/             // Timetables and route selection
│   │   └── settings/             // Appearance toggles, App/Location setting triggers
│   └── shared/
│       └── widgets/              // Global layout pieces (e.g. MainScaffold with BottomNavigationBar)
```

## Current Core Features
1. **Live Map (`map_page.dart`):**
   - Automatically switches map tile URLs based on system/user theme.
   - Slices JSON route polylines to only draw the segments requested by a `TripResult`.
   - Polls Bus GPS using Riverpod streams and automatically checks offline thresholds.
   - Provides live ETAs fetched from backend API based on user location.
2. **Onboarding Pipeline (`onboarding_page.dart`):**
   - First-run logic verified via `shared_preferences`. Sets `onboarding_seen` to true on completion.
3. **Settings (`settings_page.dart`):**
   - Theme Mode specific selectors mapping to Riverpod providers updating `MaterialApp.themeMode`.
   - Direct triggers for `Geolocator.openAppSettings()` and `Geolocator.openLocationSettings()` wrapped in an accessible UI.
4. **Three-Tab Shell (`main_scaffold.dart`):**
   - **Map:** Discovering nearby stops and live bus tracking.
   - **Schedule:** Formatted stop-by-stop timetables.
   - **Fares:** Standard, reduced, and free fare structures.

## Immediate Development Goals & TODOs
*When picking up the project, focus on these next targets:*
1. **Trip Planner (Walk+Ride Guidance):** We have existing code to plan optimal origin/destination trips by snapping to stops. Needs refinement on UI visualization (e.g., walking paths vs bus paths rendering on the map) and instructions UI inside `TripPlannerSheet`.
2. **Refining the "Delta Engine":** Use `ScheduleAdjustmentUseCase` to accurately offset future stop timings when a bus is running late based on its current GPS.
3. **Analytics & Performance:** Clean up any remaining static analyzer warnings (e.g., redundant null-checks `!`) and monitor raster performance heavily with `flutter_map`.

## Prompt for Future LLM Interactions
*You can literally copy-paste the text below to prime any LLM on a new thread:*

> **"I am working on a Flutter 3 application called 'Hub City Transit'. It tracks live buses and provides route scheduling. We use Riverpod for state management, go_router for a 3-tab StatefulShellRoute (Map, Schedule, Fares), flutter_map for raster/vector rendering, and geolocator for GPS. 
> 
> "Our codebase is structured strictly by feature under `lib/src/features/` with cross-domain providers rooted in `lib/src/app/providers.dart`. We support light/dark theme persistence and dark map tiles via shared_preferences.
> 
> "Please read `lib/src/features/map/presentation/map_page.dart` and `lib/src/app/providers.dart` to understand how we stream `BusLocationModel` and user `Position`. Keep all solutions stateless where possible, rely on Riverpod for shared state, and ensure high-performance rendering via `const` constructors and targeted widget rebuilds."**

---
*(Updated: May 2026)*