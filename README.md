# Fraud Check — Flutter app

A genuine mobile app version of Fraud Check (the English برا السالفة game).
One phone, 3–10 players, one fraud per round. No login, no internet,
no account needed to play.

## What changed from the web version

- **Main menu:** text buttons only (Play / Settings / How to Play).
  No menu icons, no tip at the bottom, no tagline.
- **Reveal cards, trimmed:** the fraud card shows only
  "YOU ARE THE FRAUD!" plus the category. The in-the-know card shows
  only the category and the word — no role label, because if you can
  see a word, you are in.
- **Categories:** the category name is always bright yellow
  (#FFD23F) on the dark background, so it never blends into the card.
  Category icons are still shown on the Play screen only.
- **Logo:** the user's own supplied logo — faceless silhouette with
  dark hair, high-collared coat with white and gold outline, gold
  magnifying glass, navy background. (Supplied 2026-10-29 as
  template_logo; converted to PNG for the app asset.)
- **Words:** same 20 categories (602 words). One fix: Clothing had
  "Shorts" twice; it is now listed once.

## How it plays

1. Pick one category, set the player count (3–10), edit names if you like.
2. Pass the phone. Each player taps to reveal their own card, then hides it.
3. Discuss without saying the word, then vote for the fraud.
4. If the vote is right, the fraud gets 4 words from the same category
   to guess from. A right guess steals the round.
5. Scores are tracked for the session. Words do not repeat until a
   category runs out.

## Getting it onto your phone

A Flutter folder cannot be opened directly on a phone — Dart code has
to be built once into an installable app. There are two ways to do that
build. The APK route below is for **Android**. If you are on an iPhone,
tell me and I will give you the Xcode route instead.

### Option A — easiest, no software to install (GitHub Actions)

1. Create a **public** GitHub repo (email signup is fine) and upload
   everything in this folder, keeping the folder structure as it is
   (`lib/`, `assets/`, `pubspec.yaml`, `.github/workflows/`).
2. Go to the repo's **Actions** tab. The "Build APK" workflow runs
   automatically (or press Run workflow).
3. When it finishes with a green tick, open the run, download the
   **fraud-check-apk** artifact, unzip it on your phone, and open the
   `.apk` file. Your phone will ask you to allow installing from that
   source — allow it once for this file.
4. Fraud Check appears on your phone like any other app, and then
   works fully offline.

### Option B — on a computer with Flutter installed

```sh
flutter create --project-name fraud_check --org com.fraudcheck app
cp lib/main.dart lib/categories.dart app/lib/
cp -r assets app/assets
cp pubspec.yaml app/pubspec.yaml
cd app
flutter pub get
flutter build apk --release
```

The APK is then at `app/build/app/outputs/flutter-apk/app-release.apk`.
Copy it to your phone and open it to install.

## Updating the app later (no remake needed)

You never have to rebuild the app from scratch or redo the whole
process. Change only what you want changed, then build again:

- Logo only: replace `assets/logo.png`.
- Wording, rules, screens, or scoring: edit `lib/main.dart`.
- Words or categories: edit `lib/categories.dart`.

Then, using the same repo/project as before:

- **GitHub route:** replace just the changed file(s) in the same repo
  and push. Actions builds a new APK automatically. Download it and
  install it over the old app — same name, same app, it replaces it.
  Scores are session-only, so there is nothing saved to lose. If a
  phone ever refuses to install over the old version, uninstall the
  old one first and then install the new one.
- **Computer route:** copy the changed file(s) into the `app/` folder
  again and run `flutter build apk --release` again.

## Files in this folder

- `lib/main.dart` — the whole game (screens, rounds, voting, scoring).
- `lib/categories.dart` — the 20 categories, word lists, and category icons.
- `assets/logo.png` — the new logo, also used on the main menu.
- `pubspec.yaml` — app name, version, and the logo asset.
- `.github/workflows/build-apk.yml` — builds the APK automatically.
