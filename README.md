# Find Who 🕵️

A fun, offline-first Flutter app for friends: browse and personalise funny posters, export them in high
resolution, and play 16 party games on one phone. No sign-in, no ads, no analytics, no network needed.

* **Posters** – 96 ready-made templates in 19 categories, searchable, favourites, a live editor
  (movable text, fonts, sizes, colours, stickers, borders, backgrounds, patterns, optional photo, undo/reset),
  square / portrait / story formats, export at 1080 px wide with no watermark.
* **Games** – Truth or Dare (3 levels, categories, skip), Would You Rather, Most Likely To (+ Reply Late Champion,
  Drama King/Queen, Always Hungry, Most Dramatic Friend), Never Have I Ever, Spin the Wheel (custom options),
  Friendship Quiz (playful titles), Who Knows Whom Best, Guess the Friend, Guess the Emoji, Complete the Sentence,
  Random Challenge, Funny Punishment. Solo, pass-the-phone and group play, scoreboards and result screens.
* **Friendship Awards** – assign funny awards and turn them into award posters.
* **Friends list** – nicknames, optional photos and notes, stored locally, reused by posters, awards and games.
* **Settings** – light/dark theme, sound and haptics, privacy info, per-category data clearing.

## Tech

Flutter / Dart · Riverpod (state) · go_router (navigation) · sqflite (SQLite: friends, saved posters, favourites,
history) · shared_preferences (settings) · image_picker · share_plus · gal (save to gallery).

```
lib/
  core/        providers, utils (validators, random picker, scoreboard, game logic)
  theme/       colours, spacing, light/dark themes
  navigation/  go_router config and bottom-navigation shell
  models/      poster template/doc, friend, records, content
  services/    sqlite store, file store, exporter, share/gallery, feedback
  widgets/     reusable UI (poster view, cards, chips, dialogs, photo picker)
  features/    home, posters, games, friends, awards, settings
assets/data/   all poster and game content as JSON
test/          unit and widget tests
prototype/     the original single-file HTML poster prototype
```

## Setup and run

```bash
flutter pub get
flutter run                      # on a connected Android device / emulator
```

## Tests

```bash
flutter analyze
flutter test                     # 56 unit + widget tests
```

## Android build

```bash
flutter build apk --release                 # universal APK
flutter build appbundle --release           # Play Store bundle
```

The release build is currently signed with the debug key. Before publishing, create a keystore and
configure `signingConfigs` in `android/app/build.gradle.kts`.
Permissions: none at runtime for photos (Android photo picker). `WRITE_EXTERNAL_STORAGE` (API ≤ 28 only) is
declared for saving to the gallery. The app declares no internet permission use of its own.

To regenerate the launcher icon after editing `assets/icon/*.png`: `dart run flutter_launcher_icons`.

## Adding content (no code changes)

All content lives in `assets/data/*.json`.

**New poster template** – append to `templates` in `posters.json`:

```json
{ "id": "birthday_6", "category": "birthday", "title": "Happy Birthday {a}!",
  "caption": "Cake first, questions later", "emoji": "🎂",
  "colors": ["#FF7043", "#B71C1C"], "pattern": "confetti",
  "textColor": "#FFFFFF", "font": "sans-serif", "trending": false }
```

`{a}` / `{b}` become the friends' names. `pattern` is one of `none dots stripes confetti grid rays`.
`font` is any id from `editor_assets.json` (`sans-serif`, `serif`, `cursive`, `sans-serif-condensed`, `monospace`).
IDs must be unique and `category` must exist.

**New category** – add `{ "id", "name", "emoji", "color" }` to `categories` in `posters.json`.

**New game questions** – append to the matching file:
`truth_dare.json` (`type` truth|dare, `level` easy|medium|spicy, `category`), `would_you_rather.json`,
`most_likely.json` (a deck's `items`), `never_have_i_ever.json`, `friendship_quiz.json` (`answer` is the
index of the correct option), `who_knows_whom.json`, `guess_emoji.json`, `complete_sentence.json`,
`challenges.json` (challenges / punishments / activities), `awards.json`, `friendship_titles.json`.
Stickers, background gradients, text colours and fonts are in `editor_assets.json`.

New *game types* need a small widget in `lib/features/games` and an entry in `game_registry.dart`.

## Privacy

Friends, photos and posters stay on the device. Nothing is uploaded; posters only leave the phone when you
share or save them. Cloud sync, accounts and online multiplayer are deliberately not part of v1.
