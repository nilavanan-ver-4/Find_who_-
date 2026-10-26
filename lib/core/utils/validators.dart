/// Input validation shared by forms. All return `null` when valid, otherwise
/// a short user-facing message.
class Validators {
  static const maxNameLength = 24;
  static const maxPlayers = 12;
  static const maxCaptionLength = 120;
  static const maxNotesLength = 200;

  static String? name(String? value, {Iterable<String> existing = const []}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Please enter a name';
    if (v.length > maxNameLength) return 'Keep it under $maxNameLength characters';
    if (RegExp(r'[<>{}]').hasMatch(v)) return 'Please avoid < > { } characters';
    final lower = v.toLowerCase();
    if (existing.any((e) => e.trim().toLowerCase() == lower)) {
      return '"$v" is already added';
    }
    return null;
  }

  static String? optionalName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return name(v);
  }

  static String? caption(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Text cannot be empty';
    if (v.length > maxCaptionLength) {
      return 'Keep it under $maxCaptionLength characters';
    }
    return null;
  }

  static String? notes(String? value) {
    if ((value ?? '').length > maxNotesLength) {
      return 'Keep it under $maxNotesLength characters';
    }
    return null;
  }

  /// Wheel options: 2 to 24 non-empty, distinct entries.
  static String? wheelOptions(List<String> options) {
    final cleaned = options.map((o) => o.trim()).where((o) => o.isNotEmpty);
    final distinct = cleaned.map((o) => o.toLowerCase()).toSet();
    if (distinct.length < 2) return 'Add at least 2 different options';
    if (cleaned.length > 24) return 'Maximum 24 options';
    return null;
  }

  static String? playerCount(int count, {required int min, int max = maxPlayers}) {
    if (count < min) {
      return min == 1 ? 'Add at least 1 player' : 'Add at least $min players';
    }
    if (count > max) return 'Maximum $max players';
    return null;
  }
}
