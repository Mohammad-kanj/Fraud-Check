# Fraud Check — Flutter app

A genuine mobile app version of Fraud Check (the English برا السالفة game).
One phone, 3–10 players, one fraud per round. No login, no internet,
no account needed to play.

## What is in this version (v1.1.0)

- **Centred layout:** every screen is centred, with centred headings,
  text, and buttons.
- **Main menu:** text buttons only (Play / Settings / How to Play).
  No menu icons, no tip at the bottom, no tagline.
- **Setup is two pages:** first pick a category, then a separate
  players page for the player count (3–10) and names. No "Step 1" /
  "Step 2" labels.
- **Passing the phone:** each pass card shows progress like "1 of 5".
  A three-dot options menu in the top right while passing offers:
  Restart round, Change category, Change players, Back to main menu.
- **Reveal cards:** the fraud card shows "YOU ARE THE FRAUD!" plus
  the category. A player in the know sees "YOU ARE SAFE", then the
  category and the word.
- **Categories:** the category name is always bright yellow
  (#FFD23F) on the dark background, so it never blends into the card.
  Category icons are still shown on the category page only.
- **Sound effects:** short generated sounds for tapping, starting a
  round, revealing a card, voting, guessing, winning, and losing.
  They live in `assets/sounds/` and can be switched off in Settings.
  If a sound fails, the game still works.
- **Launcher icon:** the icon you see on the phone's home screen is
  now the app's own logo (`assets/launcher_icon.png`, full-bleed navy
  so there are no white corners), not the default Flutter icon. The
  GitHub workflow and the computer build both run
  `dart run flutter_launcher_icons` to generate it.
- **Background:** a Balatro-style animated background behind every
  screen — slow swirling blobs in deep red, teal, gold, and purple,
  with wavy rings rippling out from the centre, kept dark so text
  stays readable. It is drawn with plain CustomPaint, so the build
  needs no shader files.
- **Logo:** the user's own supplied logo — faceless silhouette with
  dark hair, high-collared coat with white and gold outline, gold
  magnifying glass, navy background. (Supplied 2026-10-29 as
  template_logo; converted to PNG for the app asset.)
- **Words:** same 20 categories (602 words). One fix: Clothing had
  "Shorts" twice; it is now listed once.

## How it plays

1. Pick one category, then set the player count (3–10) and edit names
   if you like.
2. Pass the phone. Each player taps to reveal their own card, then
   hides it. Players in the know are SAFE; the fraud sees only the
   category.
3. Discuss without saying the word.
4. Vote: every player, one at a time and in private, picks someone
   else. The fraud is only caught if MORE THAN HALF of all votes are
   for the fraud. If not, the fraud wins the round. The result screen
   shows the vote tally.
5. Last chance: if the fraud was caught by a majority, the fraud gets
   4 words from the same category to guess from. A right guess steals
   the round.
6. Scores are tracked for the session. Words do not repeat until a
   category runs out.
7. At the end of a round, only two buttons remain: "Start a new round"
   and "Return to main menu". Clearing scores is still available in
   Settings ("Reset scores and used words").

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
dart run flutter_launcher_icons
flutter build apk --release
```

The APK is then at `app/build/app/outputs/flutter-apk/app-release.apk`.
Copy it to your phone and open it to install.

## Updating the app later (no remake needed)

You never have to rebuild the app from scratch or redo the whole
process. Change only what you want changed, then build again:

- Logo only: replace `assets/logo.png` AND `assets/launcher_icon.png`
  with the new logo (the second one is the home-screen icon).
- Sounds only: replace a file in `assets/sounds/`.
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
  again, run `dart run flutter_launcher_icons` if the logo changed,
  and run `flutter build apk --release` again.

## Files in this folder

- `lib/main.dart` — the whole game (screens, rounds, voting, scoring,
  sounds, background).
- `lib/categories.dart` — the 20 categories, word lists, and category icons.
- `assets/logo.png` — the logo, shown on the main menu.
- `assets/launcher_icon.png` — the logo, used as the home-screen icon.
- `assets/sounds/` — the sound effects (tap, start, reveal, vote,
  guess, win, lose).
- `pubspec.yaml` — app name, version, assets, and the launcher-icon
  setup.
- `.github/workflows/build-apk.yml` — builds the APK automatically,
  including the launcher icon.
