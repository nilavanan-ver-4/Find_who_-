/// Keeps scores for a set of players, preserving the order they joined in.
class Scoreboard {
  Scoreboard(Iterable<String> players) {
    for (final p in players) {
      _scores[p] = 0;
    }
  }

  final Map<String, int> _scores = {};

  List<String> get players => _scores.keys.toList();

  int scoreOf(String player) => _scores[player] ?? 0;

  void add(String player, [int points = 1]) {
    if (!_scores.containsKey(player)) return;
    _scores[player] = _scores[player]! + points;
  }

  int get total => _scores.values.fold(0, (a, b) => a + b);

  /// Highest score first; ties keep joining order.
  List<MapEntry<String, int>> ranking() {
    final entries = _scores.entries.toList();
    final order = {for (var i = 0; i < entries.length; i++) entries[i].key: i};
    entries.sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : order[a.key]!.compareTo(order[b.key]!);
    });
    return entries;
  }

  /// Everyone sharing the top score (empty when nobody scored).
  List<String> winners() {
    final r = ranking();
    if (r.isEmpty || r.first.value <= 0) return const [];
    return r.where((e) => e.value == r.first.value).map((e) => e.key).toList();
  }

  List<String> losers() {
    final r = ranking();
    if (r.length < 2) return const [];
    final low = r.last.value;
    if (low == r.first.value) return const [];
    return r.where((e) => e.value == low).map((e) => e.key).toList();
  }
}
