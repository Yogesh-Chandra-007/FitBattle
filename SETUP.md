# FitBattle — Setup Instructions

## 1. Flutter Installation
Install Flutter SDK: https://docs.flutter.dev/get-started/install/windows

## 2. Firebase Setup
1. Go to https://console.firebase.google.com
2. Create a new project called "FitBattle"
3. Enable **Authentication** → Email/Password
4. Enable **Realtime Database** → Start in test mode
5. Add Android app (package: com.fitbattle.fitness_battle) → Download `google-services.json` → place it in `android/app/`
6. Add iOS app → Download `GoogleService-Info.plist` → place it in `ios/Runner/`
7. Run: `flutterfire configure` (install flutterfire_cli first)

## 3. Run the app
```bash
flutter pub get
flutter run
```

## 4. Realtime Database Rules (for development)
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

## App Flow
1. **Auth** → Sign up / Log in
2. **Home** → Choose exercise → Create or Join battle
3. **Lobby** → Share 6-char room code → Wait for opponent → Host starts battle
4. **Battle** → Camera runs pose detection → Reps counted automatically → 60s timer
5. **Result** → Winner announced → Play again

## Supported Exercises
- Push-Ups (elbow angle tracking)
- Squats (knee angle tracking)
- Jumping Jacks (wrist elevation tracking)
