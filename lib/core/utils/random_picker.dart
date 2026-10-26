import 'dart:math';

/// Small helpers around [Random] so that game logic can be tested with a
/// seeded generator.
class RandomPicker {
  RandomPicker([Random? random]) : _random = random ?? Random();
  final Random _random;

  T pick<T>(List<T> items) {
    if (items.isEmpty) throw ArgumentError('Cannot pick from an empty list');
    return items[_random.nextInt(items.length)];
  }

  /// Picks something different from [previous] when possible.
  T pickExcluding<T>(List<T> items, T? previous) {
    if (items.length < 2) return pick(items);
    T next;
    do {
      next = pick(items);
    } while (next == previous);
    return next;
  }

  List<T> shuffled<T>(Iterable<T> items) => List<T>.of(items)..shuffle(_random);

  /// Picks [count] distinct items (or fewer if the list is shorter).
  List<T> pickMany<T>(List<T> items, int count) =>
      shuffled(items).take(count).toList();

  int nextInt(int max) => _random.nextInt(max);
}

/// Draws items in random order without repeating until all were seen,
/// then reshuffles (avoiding an immediate repeat across the boundary).
class Deck<T> {
  Deck(Iterable<T> items, [Random? random])
      : _picker = RandomPicker(random),
        _items = List<T>.of(items) {
    _refill();
  }

  final RandomPicker _picker;
  final List<T> _items;
  final List<T> _queue = [];
  T? _last;

  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  T draw() {
    if (_items.isEmpty) throw StateError('Deck is empty');
    if (_queue.isEmpty) {
      _refill();
      if (_queue.length > 1 && _queue.last == _last) {
        final first = _queue.removeLast();
        _queue.insert(0, first);
      }
    }
    return _last = _queue.removeLast();
  }

  void _refill() => _queue
    ..clear()
    ..addAll(_picker.shuffled(_items));
}
