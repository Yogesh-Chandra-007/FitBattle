# FitBattle — Project AI Context

## Project purpose
Real-time 1v1 fitness battle app.

Flow: **Login → Battle Zone → Exercise → Custom Timer → Matchmaking → Camera → Pose Tracking → Rep Detection → Live Score → Battle Completion → Result → Exit/Rematch**.

## Tech stack
- **Flutter (Dart)** UI
- **Provider** (`ChangeNotifier`, `context.read/watch`) for app state
- **Firebase Auth** (`firebase_auth`) for identity
- **Firebase Realtime Database** (`firebase_database`) for battle presence/state/score + friends + invites
- **Camera** (`camera`) + **ML Kit Pose Detection** (`google_mlkit_pose_detection`) for pose landmarks

Important dependencies (from `pubspec.yaml`):
- `firebase_core`, `firebase_auth`, `firebase_database`
- `camera`, `google_mlkit_pose_detection`
- `provider`
- `wakelock_plus`, `shared_preferences`
- `flutter_animate`, `animate_do`, `lottie` (mostly UI effects)

## Architecture
- **State management:**
  - `ThemeNotifier` (theme mode + persistence via `SharedPreferences`).
  - `AuthService` (auth + user profile read/write + leaderboard updates).
  - `BattleService` (Firebase Realtime Database as the single source of truth for the battle room lifecycle + score transitions).
  - `FriendsService` (friends list + invites).
- **UI/navigation:**
  - `SplashScreen` → `HomeScreen` via auth state.
  - `HomeScreen` uses a `Navigator` with `onGenerateRoute` for `/lobby` and its tabbed scaffold.
  - `BattleZoneScreen` selects exercise/duration, creates or matchmaking-joins a room, then routes to `LobbyScreen`.
  - `LobbyScreen` navigates to `BattleScreen` when shared room state becomes `countdown`/`active`.
  - `BattleScreen` runs camera+pose+rep detection and drives score updates to Firebase; it navigates to `ResultScreen` when shared state becomes `result`.
  - `ResultScreen` records profile stats once per user via a transaction guard, then shows result UI.

## Important Modules
- `lib/services/auth_service.dart`: auth + profile/leaderboard updates in Realtime Database.
- `lib/services/battle_service.dart`: battle room creation/joining + lifecycle transitions + transactional score writes.
- `lib/services/pose_detector_service.dart`: camera frame → ML Kit pose → deterministic kinematics → analyzer.
- `lib/services/exercise_analyzers.dart`: deterministic rep state machines (pushups, squats).
- `lib/screens/battle_screen.dart`: camera streaming + overlay + per-frame rep counting + shared countdown.
- `lib/screens/lobby_screen.dart`: shared-state-driven navigation and host start logic.
- `lib/screens/result_screen.dart`: winner/draw display + one-time result recording.

## Data Flow
### Authentication/Profile
- `SplashScreen` listens to `FirebaseAuth.instance.authStateChanges()`.
- `AuthService.signIn/signUp` sets `users/{uid}` and updates `isOnline`.
- Profile UI reads from `AuthService.watchProfile(uid)` (Realtime listeners).

### Friends/Invites
- Friends UI reads `friends/{myUid}` and then loads each friend’s profile from `users/{friendUid}`.
- Invites use `invites/{toUid}/{roomId}`; accept flow: dismiss invite → `BattleService.joinRoom(roomId)` → push `/lobby`.

### Battle (authoritative by Firebase)
- `BattleService.createRoom` writes `rooms/{roomId}` with `status=waiting`.
- `BattleService.joinRoom` transactionally moves `waiting → matched` and sets presence for the joining user.
- `LobbyScreen` (host) calls `BattleService.startBattle` when `matched` is reached.
- `BattleScreen` and/or `LobbyScreen` then drive `matched → countdown → active` transitions based on shared timestamps.
- While `active`, `BattleScreen` sends rep count changes to Firebase via `BattleService.updateReps` (transactioned per room role).
- When end time is reached, both clients call `finishBattle` (transactioned) → `publishResult` → `ResultScreen`.

## Firebase/Battle State
### Room schema (Realtime Database)
- Path: `rooms/{roomId}`
- Core fields used by code:
  - `status`: `waiting | matched | countdown | active | finished | result | closed` (see `BattleStatus`)
  - `hostId`, `guestId`, `hostUsername`, `guestUsername`
  - `exercise`, `durationSeconds`
  - Timing: `startTime`, `endTime` (epoch ms)
  - Scores: `hostReps`, `guestReps`
  - Result: `winnerId`, `finishReason`
  - Presence: `presence/{uid}` with `{ connected, lastSeen }`

### Synchronization model
- **Firebase is the source of truth**.
- All battle lifecycle transitions and score updates use **Realtime Database transactions** in `BattleService`.
- Clients use **shared timestamps** (`startTime`, `endTime`) to locally compute countdown/remaining time, but the authoritative state is the `status` field.

## CV/Rep Detection
### Camera integration
- `BattleScreen` creates a `CameraController` (front camera preferred), starts `startImageStream`.
- Each frame is converted to `InputImage` with correct `InputImageRotation` and format requirements.

### Pose estimation
- `PoseDetectorService.processImage`:
  1. Runs ML Kit pose detection (`PoseDetectionMode.stream`).
  2. Extracts needed landmarks for the current exercise.
  3. Computes:
     - `jointAngle` (elbow angle for pushups; knee angle for squats)
     - `depth` (normalized ROM/depth cue)
     - `bodyAligned` (landmark-derived form gate)

### Exercise detection / rep counting
- Deterministic analyzers in `exercise_analyzers.dart` implement a stable-phase state machine:
  - `RepPhase`: `unknown | top | down | bottom | up`
  - Smoothed observation of `jointAngle`.
  - Minimum stable frames per phase transition.
  - Rep is counted only on the final transition (e.g., `up → top`).
- `PoseDetectorService` only increments rep count when analyzer indicates a valid `countedRep`.

## Timer/Matchmaking
- Custom duration selection is in minutes in `BattleZoneScreen`.
- `BattleService.startBattle` sets `status=countdown` and `startTime = now + 3000ms`.
- `BattleService.activateBattle` sets `status=active` once the shared `startTime` is reached.
- `BattleScreen` runs a periodic timer (250ms) to update UI `secondsLeft` and to trigger `finishBattle` exactly once per client at end time.
- Matchmaking:
  - `BattleService.findOrCreateMatchmakingRoom` searches `rooms` by `status=waiting` and `isMatchmaking=true`, joins the first compatible room, otherwise creates a matchmaking room.
  - `LobbyScreen` (host) starts the battle when guest is present and room status is `matched`.

## Theme/Design
- `ThemeNotifier` uses `ThemeMode.dark/light` with persistence in `SharedPreferences`.
- `MaterialApp` in `main.dart` uses `themeMode`, `buildLightTheme()`, `buildDarkTheme()`.

## Development Rules
- **Deterministic CV scoring:**
  - Keep rep counting logic inside `exercise_analyzers.dart` deterministic and testable.
  - Avoid “fake” rep counters or UI-only estimation.
- **Firebase transitions:**
  - Must remain transaction-based in `BattleService` for lifecycle + score.
  - Clients should navigate based on room `status`, not local-only state.
- **Resource lifecycle:**
  - Dispose camera streams/controllers and pose detector instances in `BattleScreen._cleanup/dispose`.
- **Schema coupling:**
  - Any change to `rooms/{roomId}` fields must be reflected in `BattleRoom.fromMap` and all lifecycle writers.

## Known Issues (current)
- Firebase security rules in `firebase_database_rules.json` are permissive for `rooms/$roomId` (`.read/.write: auth != null`). Tighten to host/guest ownership for production.
- CV currently uses **ML Kit Pose Detection only** (no OpenCV/MediaPipe pipeline exists in this repo).
- Exercise support in analyzers is currently **pushups + squats** (other exercises are not supported by pose analyzers).

- Battle join + rep counting reliability improvements were added, but they still need real-device end-to-end verification against the provided reference video/images to fully match the intended behavior (rep boundary/progress timing).
- Temporary CV debug logging exists behind a `_kCvDebug` flag in `BattleScreen` (currently off).
.