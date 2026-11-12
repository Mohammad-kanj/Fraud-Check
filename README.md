# Fraud Check

A pass-and-play social deduction party game built with Flutter for **3 to 10 players** on a single phone — no accounts, no internet connection, and no setup hassle.

One secret word. At least one Fraud trying to blend in. Ask sharp questions, read the room, and vote out the impostor before they figure out the word.

---

## Download & Play

Ready to play on Android? Grab the latest release APK directly from GitHub:

1. Open the **[GitHub Releases](https://github.com/Mohammad-kanj/Fraud-Check/releases)** page and download the latest `app-release.apk` (under **Assets**).
2. Open the downloaded `.apk` file on your Android device.
3. If prompted, allow your browser or file manager to install apps from unknown sources.
4. Tap **Install**, launch **Fraud Check**, and pass the phone around.

> **Tip:** You can also download the latest automated APK build from the most recent successful workflow run on the **[GitHub Actions](https://github.com/Mohammad-kanj/Fraud-Check/actions)** tab (look for the `fraud-check-apk` artifact).

---

## Features

- **1,000 Secret Words Across 20 Categories:** Movies, TV Shows, Animals, Leaders, Sports, Clothing, Food, Drinks, Places, Professions, Video Games, Superheroes, Musical Artists, Brands, Household Items, Vehicles, Cartoons & Anime, Landmarks, Instruments, and Desserts — each paired with custom category artwork and tracked per session so words do not repeat.
- **Three Game Modes:**
  - **Classic** *(3–10 players)*: 1 Fraud who only knows the category.
  - **Two Frauds** *(4–10 players)*: 2 Frauds trying to blend in and outlast the group.
  - **Undercover** *(3–10 players)*: 1 Undercover agent who receives a closely related decoy word from the same category.
  - **Chaos** *(4–10 players)*: 1 Fraud who only knows the category plus 1 Undercover agent who receives a closely related decoy word from the same category.
- **Pass-and-Play Privacy:** Flip-card role reveals on a single device keep every player's role hidden while passing the phone around, with an optional discussion timer and guided questioning pairings.
- **Session Party Scoring:** Track scores across rounds without any accounts or external storage:
  - **Correct Voters:** Players who vote out a Fraud (or Undercover agent) earn **100 points** (plus a **50-point bonus** in two-target modes if both votes hit caught agents).
  - **Secret Word Guess:** If a caught Fraud or Undercover agent correctly guesses the secret word, they salvage **50 points**, while the group still wins the round.
  - **Uncaught Agents:** Any Fraud or Undercover agent who avoids a majority vote earns **100 points**.
- **Built-In Polish:** Procedural film-strip backdrop, end-of-round confetti celebration, custom sound effects with mute and volume controls, an in-app screen brightness slider, and a tabbed Rules guide.

---

## How it plays

1. **Choose a mode, category, and player lineup** (3–10 players, with customizable names).
2. **Pass the phone** around so each player can privately flip their card to see the secret word — or learn that they are the Fraud (or Undercover agent).
3. **Question and discuss:** Follow the randomized questioning prompts or discuss freely before moving to the vote.
4. **Vote privately:** Each player casts their vote(s) on the phone in turn.
5. **Final guess and results:** If a Fraud or Undercover agent is caught by majority vote, they get one chance to guess the secret word from category decoys before round points and the updated leaderboard are revealed.

---

## Building the App

### Option A — Build with GitHub Actions (No Local Android Studio Required)

1. **Fork this repository** on GitHub.
2. Open the **Actions** tab and run the **Build Android APK** workflow (`.github/workflows/build-apk.yml`), or trigger it automatically on push.
3. Download the compiled `fraud-check-apk` artifact from the finished workflow run.

### Option B — Build Locally with Flutter

```bash
flutter create --project-name fraud_check --org com.fraudcheck --platforms android app
cp -r lib assets pubspec.yaml app/
cd app
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

The release APK will be generated at `app/build/app/outputs/flutter-apk/app-release.apk`.
