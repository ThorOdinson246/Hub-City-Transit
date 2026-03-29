# Flutter Migration Implementation Todo

- [x] Create Flutter Android project scaffold
- [x] Add core dependencies and lint setup
- [x] Create modular architecture structure
- [x] Port core route/bus constants and metadata
- [x] Set up repository abstraction and initial API client
- [x] Wire Riverpod + go_router app shell
- [x] Implement flutter_map polylines and bus markers
- [x] Port schedule adjustment algorithm (`identifyTripByBusPosition`, GPS snap)
- [x] Implement tri-state bus status and stale UX labels
- [x] Build ETA card parity view with on-demand + periodic refresh
- [x] Build stop detail parity views
- [x] Add search + transfer chip behavior parity
- [x] Add search behavior parity on schedule page
- [x] Add unit tests for schedule math and mapping
- [ ] Add integration/golden tests for key screens
- [x] Harden Android config for release
- [ ] Analyze, test, and release build verification (build is environment-blocked by local NDK license acceptance)
