import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Tiny document store. Every table has the same shape
/// (`id`, `created_at`, `json`), which keeps the schema stable while the
/// feature models evolve.
abstract class LocalDb {
  Future<List<Map<String, dynamic>>> all(String table);
  Future<void> put(String table, String id, Map<String, dynamic> json);
  Future<void> remove(String table, String id);
  Future<void> clear(String table);
  Future<void> clearAll();
}

class DbTables {
  static const friends = 'friends';
  static const savedPosters = 'saved_posters';
  static const favorites = 'favorites';
  static const history = 'history';
  static const userMemes = 'user_memes';
  static const values = [friends, savedPosters, favorites, history, userMemes];
}

class SqliteDb implements LocalDb {
  SqliteDb._(this._db);
  final Database _db;

  static Future<SqliteDb> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'find_who.db'),
      version: 2,
      onCreate: (db, _) async {
        for (final t in DbTables.values) {
          await _createTable(db, t);
        }
      },
      // v2 added the table for templates the user adds themselves.
      onUpgrade: (db, from, to) async {
        if (from < 2) await _createTable(db, DbTables.userMemes);
      },
    );
    return SqliteDb._(db);
  }

  static Future<void> _createTable(Database db, String t) => db.execute(
      'CREATE TABLE IF NOT EXISTS $t (id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, json TEXT NOT NULL)');

  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    final rows = await _db.query(table, orderBy: 'created_at DESC');
    return rows
        .map((r) => jsonDecode(r['json']! as String) as Map<String, dynamic>)
        .toList();
  }

  @override
  Future<void> put(String table, String id, Map<String, dynamic> json) async {
    final existing =
        await _db.query(table, columns: ['created_at'], where: 'id = ?', whereArgs: [id]);
    final created = existing.isEmpty
        ? DateTime.now().microsecondsSinceEpoch
        : existing.first['created_at']! as int;
    await _db.insert(
      table,
      {'id': id, 'created_at': created, 'json': jsonEncode(json)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String table, String id) =>
      _db.delete(table, where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> clear(String table) => _db.delete(table);

  @override
  Future<void> clearAll() async {
    for (final t in DbTables.values) {
      await _db.delete(t);
    }
  }
}

/// In-memory implementation used by tests.
class MemoryDb implements LocalDb {
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};
  int _clock = 0;
  final Map<String, int> _created = {};

  Map<String, Map<String, dynamic>> _t(String t) => _tables.putIfAbsent(t, () => {});

  @override
  Future<List<Map<String, dynamic>>> all(String table) async {
    final ids = _t(table).keys.toList()
      ..sort((a, b) => _created['$table/$b']!.compareTo(_created['$table/$a']!));
    return ids.map((i) => Map<String, dynamic>.from(_t(table)[i]!)).toList();
  }

  @override
  Future<void> put(String table, String id, Map<String, dynamic> json) async {
    _created.putIfAbsent('$table/$id', () => _clock++);
    _t(table)[id] = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }

  @override
  Future<void> remove(String table, String id) async {
    _t(table).remove(id);
    _created.remove('$table/$id');
  }

  @override
  Future<void> clear(String table) async {
    for (final id in _t(table).keys) {
      _created.remove('$table/$id');
    }
    _t(table).clear();
  }

  @override
  Future<void> clearAll() async {
    for (final t in DbTables.values) {
      await clear(t);
    }
  }
}
