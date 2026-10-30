# Fraud Check — Flutter app

A genuine mobile app version of Fraud Check (the English برا السالفة game).
One phone, 3–10 players, no login, no internet, offline party gameplay.

## What is in this version (v1.2.0)

- **Game Modes (Configurable in code):**
  - **Classic:** 1 fraud who only knows the category. Pure deduction (3–10 players).
  - **Two Frauds:** 2 players are chosen as frauds. Double the deception and chaos (4–10 players).
  - **Undercover:** 1 fraud + 1 undercover agent. The undercover agent is explicitly informed of their role and given a different decoy word from the same category to blend in (4–10 players).
  - Modes are defined cleanly in code (`availableGameModes` in `lib/main.dart`), making it easy to add or customize modes directly in Dart.
- **Main Menu Setup Flow (Option C):**
  - Mode selection is integrated into the setup flow directly from the **Main Menu** (Play $\rightarrow$ Select Mode $\rightarrow$ Pick Category $\rightarrow$ Players).
  - The in-game three-dot options menu (`showPassOptions`) during card passing remains clean and restricted strictly to round management (`Restart round`, `Change category`, `Change players`, `Back to main menu`).
- **Authentic Barra El Salfa Scoring (+100 Party Points):**
  - **Caught Fraud misses guess:** Every player who personally voted for the caught fraud earns **+100 points**! Players who voted for an innocent player receive 0 points.
  - **Fraud Escapes or Guesses Right:** The fraud(s) earn **+100 points**! Safe players receive 0 points.
  - **Undercover Agent:** Earns **+100 points** if they vote for the fraud or survive unexposed.
  - The results screen details the complete breakdown: mode played, secret word, category, who the fraud(s) and undercover were, and a detailed round points log showing each player's action and points earned.
- **Centred layout & Balatro-style background:**
  - Responsive, centered layout with dark navy palette, gold/yellow accents, and smooth procedural swirling blobs and ripple rings.
- **Sound effects & Offline Play:**
  - Generated sounds for tapping, starting rounds, card reveals, voting, guessing, winning, and losing.
  - Can be toggled on/off in Settings.

## How it plays

1. Tap **Play** from the Main Menu, pick a **Game Mode** (Classic, Two Frauds, or Undercover), then choose a **Category** and configure your **Players** (3–10).
2. **Pass the phone:** Each player privately reveals their own card:
   - Safe players see `"YOU ARE SAFE"`, the category, and the secret word.
   - The fraud sees `"YOU ARE THE FRAUD!"` and only the category.
   - The undercover agent sees `"YOU ARE UNDERCOVER!"`, the category, and their secret decoy word.
3. **Discuss:** Players take turns asking questions and giving clues without saying their secret word.
4. **Vote:** Each player, one at a time and in private, votes for someone else.
5. **Last chance:** If a fraud is caught by majority vote (> 50%), they get 4 word options from the category to guess from. A correct guess steals the round!
6. **Scoring:** Points are awarded using authentic *Barra El Salfa* rules (+100 party points per correct vote or fraud escape).
7. Session scores are tracked on the Leaderboard across rounds.

## Adding or Editing Game Modes in Code

All game modes are declared in `lib/main.dart` in the `availableGameModes` list:

```dart
const List<GameMode> availableGameModes = [
  GameMode(
    id: GameModeId.classic,
    title: 'Classic',
    subtitle: '1 fraud who only knows the category. Pure deduction.',
    minPlayers: 3,
    fraudCount: 1,
    hasUndercover: false,
  ),
  GameMode(
    id: GameModeId.twoFrauds,
    title: 'Two Frauds',
    subtitle: '2 frauds in the mix. Double the chaos and deception!',
    minPlayers: 4,
    fraudCount: 2,
    hasUndercover: false,
  ),
  GameMode(
    id: GameModeId.undercover,
    title: 'Undercover',
    subtitle: '1 fraud + 1 undercover agent with a secret decoy word!',
    minPlayers: 4,
    fraudCount: 1,
    hasUndercover: true,
  ),
];
```

To add another mode (for example, 3 Frauds for larger parties), simply add another `GameMode` entry to `availableGameModes` and the app automatically displays it and enforces its rules!

## Building the App

### Option A — GitHub Actions (No local install needed)
1. Push this folder to a GitHub repository.
2. In the **Actions** tab, the `Build APK` workflow runs automatically.
3. Download the `fraud-check-apk` artifact and install the `.apk` on your Android phone.

### Option B — Local Flutter Build
```sh
cd fraud-check-flutter
flutter pub get
flutter build apk --release
```
The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.
