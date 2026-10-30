# Find Who 🕵️

A fun, offline-first Flutter app for friends: browse and personalise funny posters, export them in high
resolution, and play 16 party games on one phone. No sign-in, no ads, no analytics, no network needed.

* **Posters** – 166 ready-made templates: 19 categories plus Tamil Memes with a sub-category for each actor, searchable, favourites, a live editor
  (drag to move, pinch or corner handle to resize and rotate, red button to delete; photos with shape, crop, flip, brightness and saturation; stickers you can tap or drag-and-drop onto the poster; fonts, colours, borders, backgrounds, patterns, undo/reset),
  square / portrait / story formats, export at 1080 px wide with no watermark.
* **Tamil Memes** – 20 blank meme templates (TM001–TM020) in a searchable iPhone-style grid with category
  filters, favourites and recently used. Opens a full-screen editor with Tamil Unicode fonts, caption
  suggestions (Tamil script and Tanglish), several text layers with font, size, colour, outline, alignment,
  rotation and position, emojis and stickers. Export 1:1, 4:5 or 9:16, save to the gallery or share.
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
flutter test                     # 99 unit + widget tests
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

**New category** – add `{ "id", "name", "emoji", "color" }` to `categories` in `posters.json`. Add `"parent": "<category id>"` to make it a sub-category (like the actors under `tamil_memes`); templates then use the sub-category id.

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

## Tamil Memes

### Templates and images
The 20 bundled templates live in `assets/data/tamil_memes.json` (ID, title, comedian/actor, source, category,
image, aspect, tags, suggested captions, default text layers, licence, reference). The pictures
(`assets/memes/tm001.png` … `tm020.png`) are **original cartoon illustrations** drawn by
`tool/generate_meme_templates.py`; they are not film stills and do not show any real person. The
"comedian / actor" and "source" fields describe the comedy style or scene that inspired the caption idea.

The reference links you collected are in `docs/tamil_meme_references.md` and as metadata only. **No image from
those sites is bundled.** Put third-party reference images in `reference_images/` (git-ignored, never listed in
`pubspec.yaml`) and only move one into a pack after you have verified you may distribute it.

### Fonts (all SIL Open Font License, licences in `assets/fonts/`)
Mukta Malar (Tamil + Latin, 3 weights), Baloo Thambi 2 (fun Tamil), Anton and Bangers (English meme/comic).
Every text style falls back to Mukta Malar, so Tamil renders correctly even if a Latin-only font is chosen.

### Adding templates without changing code
* **In the app:** Tamil Memes → *Add template*: pick an image, name it, choose a category. It is stored in
  SQLite plus a private copy of the image and works offline. You must confirm you have the right to use the image.
* **Template packs:** create `<app files folder>/meme_packs/<pack name>/pack.json` with the images next to it
  (Android: `/sdcard/Android/data/com.findwho.find_who/files/meme_packs/`, reachable with a file manager or
  `adb push`). The app reads packs at start-up; a broken pack or missing image is skipped, never fatal.

```json
{
  "pack": "my_pack",
  "categories": [{ "id": "fun", "name": "Fun", "emoji": "🎉" }],
  "templates": [{
    "id": "MY001", "title": "Surprised cat", "actor": "", "source": "My photo",
    "category": "fun", "image": "cat.png", "aspect": 1.0,
    "tags": ["cat"], "captions": ["Enna da idhu?", "என்னடா இது?"],
    "layers": [{ "role": "top", "text": "" }, { "role": "bottom", "text": "Enna da idhu?" }]
  }]
}
```

To add to the bundled set instead, append to `assets/data/tamil_memes.json` and drop the image in `assets/memes/`.

### Performance and offline
Bundled images and your own templates are read from local storage, so everything works offline. Grid thumbnails
are decoded at card size (`cacheWidth`), cards are repaint-isolated and the grid is a lazy sliver, which keeps
scrolling smooth on budget phones. The full 20-image set is about 0.6 MB.

### Sharing
Share opens Android's share sheet, where WhatsApp, Instagram, Telegram and others are listed. (A one-tap
WhatsApp-only button would need a native Android channel; it can be added later.)
