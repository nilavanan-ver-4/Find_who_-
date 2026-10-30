import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content.dart';
import '../models/friend.dart';
import '../models/meme_template.dart';
import '../models/records.dart';
import '../services/feedback_service.dart';
import '../services/file_store.dart';
import '../services/local_db.dart';
import '../services/share_service.dart';
import 'utils/random_picker.dart';

// ---- Overridden at start-up (see main.dart) --------------------------------
final contentProvider = Provider<AppContent>((ref) => throw UnimplementedError());
final dbProvider = Provider<LocalDb>((ref) => throw UnimplementedError());

/// Bundled + external-pack meme templates, loaded once at start-up.
final memeCatalogProvider = Provider<MemeCatalog>((ref) => MemeCatalog.empty);
final prefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final fileStoreProvider = Provider<FileStore>((ref) => FileStore());
final shareServiceProvider = Provider<ShareService>((ref) => ShareService());
final randomProvider = Provider<RandomPicker>((ref) => RandomPicker(Random()));

// ---- Settings ---------------------------------------------------------------
class Settings {
  const Settings({
    this.themeMode = ThemeMode.system,
    this.sound = true,
    this.haptics = true,
    this.userName = '',
  });
  final ThemeMode themeMode;
  final bool sound;
  final bool haptics;
  final String userName;

  Settings copyWith({ThemeMode? themeMode, bool? sound, bool? haptics, String? userName}) =>
      Settings(
        themeMode: themeMode ?? this.themeMode,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        userName: userName ?? this.userName,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _kTheme = 'theme_mode';
  static const _kSound = 'sound';
  static const _kHaptics = 'haptics';
  static const _kName = 'user_name';

  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Settings build() {
    final p = ref.read(prefsProvider);
    return Settings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == p.getString(_kTheme),
        orElse: () => ThemeMode.system,
      ),
      sound: p.getBool(_kSound) ?? true,
      haptics: p.getBool(_kHaptics) ?? true,
      userName: p.getString(_kName) ?? '',
    );
  }

  void setTheme(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _p.setString(_kTheme, m.name);
  }

  void setSound(bool v) {
    state = state.copyWith(sound: v);
    _p.setBool(_kSound, v);
  }

  void setHaptics(bool v) {
    state = state.copyWith(haptics: v);
    _p.setBool(_kHaptics, v);
  }

  void setUserName(String v) {
    state = state.copyWith(userName: v.trim());
    _p.setString(_kName, v.trim());
  }

  Future<void> reset() async {
    await _p.clear();
    state = const Settings();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

final feedbackProvider = Provider<FeedbackService>((ref) {
  final s = ref.watch(settingsProvider);
  return FeedbackService(soundOn: s.sound, hapticsOn: s.haptics);
});

// ---- Friends ------------------------------------------------------------------
class FriendsNotifier extends AsyncNotifier<List<Friend>> {
  LocalDb get _db => ref.read(dbProvider);

  @override
  Future<List<Friend>> build() async {
    final rows = await _db.all(DbTables.friends);
    return rows.map(Friend.fromJson).toList().reversed.toList();
  }

  List<Friend> get _current => state.value ?? const [];

  Future<void> save(Friend f) async {
    await _db.put(DbTables.friends, f.id, f.toJson());
    final list = [..._current];
    final i = list.indexWhere((x) => x.id == f.id);
    if (i >= 0) {
      list[i] = f;
    } else {
      list.add(f);
    }
    state = AsyncData(list);
  }

  Future<void> remove(Friend f) async {
    await _db.remove(DbTables.friends, f.id);
    await ref.read(fileStoreProvider).delete(f.photoPath);
    state = AsyncData(_current.where((x) => x.id != f.id).toList());
  }

  Future<void> clear() async {
    for (final f in _current) {
      await ref.read(fileStoreProvider).delete(f.photoPath);
    }
    await _db.clear(DbTables.friends);
    state = const AsyncData([]);
  }
}

final friendsProvider =
    AsyncNotifierProvider<FriendsNotifier, List<Friend>>(FriendsNotifier.new);

// ---- Favourites -----------------------------------------------------------------
class FavoritesNotifier extends AsyncNotifier<Set<String>> {
  LocalDb get _db => ref.read(dbProvider);

  static String posterKey(String id) => 'poster:$id';
  static String gameKey(String id) => 'game:$id';
  static String savedKey(String id) => 'saved:$id';

  @override
  Future<Set<String>> build() async {
    final rows = await _db.all(DbTables.favorites);
    return rows.map((r) => r['id'] as String).toSet();
  }

  Set<String> get _current => state.value ?? <String>{};

  bool isFavorite(String key) => _current.contains(key);

  Future<void> toggle(String key) async {
    final next = {..._current};
    if (next.remove(key)) {
      await _db.remove(DbTables.favorites, key);
    } else {
      next.add(key);
      await _db.put(DbTables.favorites, key, {'id': key});
    }
    state = AsyncData(next);
  }

  Future<void> clear() async {
    await _db.clear(DbTables.favorites);
    state = const AsyncData(<String>{});
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

bool isFav(WidgetRef ref, String key) =>
    ref.watch(favoritesProvider).value?.contains(key) ?? false;

// ---- Saved posters -----------------------------------------------------------------
class SavedPostersNotifier extends AsyncNotifier<List<SavedPoster>> {
  LocalDb get _db => ref.read(dbProvider);

  @override
  Future<List<SavedPoster>> build() async {
    final rows = await _db.all(DbTables.savedPosters);
    return rows.map(SavedPoster.fromJson).toList();
  }

  List<SavedPoster> get _current => state.value ?? const [];

  Future<void> add(SavedPoster p) async {
    await _db.put(DbTables.savedPosters, p.id, p.toJson());
    state = AsyncData([p, ..._current.where((x) => x.id != p.id)]);
  }

  Future<void> remove(SavedPoster p) async {
    await _db.remove(DbTables.savedPosters, p.id);
    await ref.read(fileStoreProvider).delete(p.imagePath);
    state = AsyncData(_current.where((x) => x.id != p.id).toList());
  }

  Future<void> clear() async {
    await _db.clear(DbTables.savedPosters);
    await ref.read(fileStoreProvider).clearPosters();
    state = const AsyncData([]);
  }
}

final savedPostersProvider =
    AsyncNotifierProvider<SavedPostersNotifier, List<SavedPoster>>(
        SavedPostersNotifier.new);

// ---- History (recent games / templates) ------------------------------------------
class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  static const maxEntries = 200;
  LocalDb get _db => ref.read(dbProvider);

  @override
  Future<List<HistoryEntry>> build() async {
    final rows = await _db.all(DbTables.history);
    return rows.map(HistoryEntry.fromJson).toList();
  }

  List<HistoryEntry> get _current => state.value ?? const [];

  Future<void> record(HistoryKind kind, String refId, String title,
      {String detail = ''}) async {
    final e = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      refId: refId,
      title: title,
      detail: detail,
      at: DateTime.now(),
    );
    await _db.put(DbTables.history, e.id, e.toJson());
    var list = [e, ..._current];
    if (list.length > maxEntries) {
      for (final old in list.sublist(maxEntries)) {
        await _db.remove(DbTables.history, old.id);
      }
      list = list.sublist(0, maxEntries);
    }
    state = AsyncData(list);
  }

  Future<void> clear() async {
    await _db.clear(DbTables.history);
    state = const AsyncData([]);
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

/// Most recent unique ids of the given kind.
List<HistoryEntry> recentUnique(List<HistoryEntry> all, HistoryKind kind,
    {int limit = 10}) {
  final seen = <String>{};
  final out = <HistoryEntry>[];
  for (final e in all) {
    if (e.kind == kind && seen.add(e.refId)) {
      out.add(e);
      if (out.length >= limit) break;
    }
  }
  return out;
}

// ---- Meme templates ---------------------------------------------------------------
String memeKey(String id) => 'meme:$id';

/// Templates the user added from their own images.
class UserMemesNotifier extends AsyncNotifier<List<MemeTemplate>> {
  LocalDb get _db => ref.read(dbProvider);

  MemeTemplate _parse(Map<String, dynamic> j) => MemeTemplate.fromJson(
        j,
        imageResolver: (img) => img,
        isUser: true,
        pack: 'mine',
      );

  @override
  Future<List<MemeTemplate>> build() async {
    final rows = await _db.all(DbTables.userMemes);
    final out = <MemeTemplate>[];
    for (final r in rows) {
      try {
        out.add(_parse(r));
      } catch (_) {
        // Skip rows that can't be read instead of failing the whole list.
      }
    }
    return out;
  }

  List<MemeTemplate> get _current => state.value ?? const [];

  Future<void> add(MemeTemplate t) async {
    await _db.put(DbTables.userMemes, t.id, t.toUserJson());
    state = AsyncData([t, ..._current.where((x) => x.id != t.id)]);
  }

  Future<void> remove(MemeTemplate t) async {
    await _db.remove(DbTables.userMemes, t.id);
    await ref.read(fileStoreProvider).delete(t.imageRef);
    state = AsyncData(_current.where((x) => x.id != t.id).toList());
  }

  Future<void> clear() async {
    for (final t in _current) {
      await ref.read(fileStoreProvider).delete(t.imageRef);
    }
    await _db.clear(DbTables.userMemes);
    state = const AsyncData([]);
  }
}

final userMemesProvider =
    AsyncNotifierProvider<UserMemesNotifier, List<MemeTemplate>>(UserMemesNotifier.new);

/// Everything the meme grid shows: packs first, then the user's own templates.
final allMemesProvider = Provider<MemeCatalog>((ref) {
  final base = ref.watch(memeCatalogProvider);
  final mine = ref.watch(userMemesProvider).value ?? const <MemeTemplate>[];
  return MemeCatalog(categories: base.categories, templates: [...base.templates, ...mine]);
});
