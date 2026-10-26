class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.nickname = '',
    this.photoPath,
    this.notes = '',
  });

  final String id;
  final String name;
  final String nickname;
  final String? photoPath;
  final String notes;

  /// What we show on posters and in games.
  String get displayName => nickname.trim().isNotEmpty ? nickname.trim() : name;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    String first(String s) => String.fromCharCode(s.runes.first);
    final second = parts.length > 1 && parts.last.isNotEmpty
        ? first(parts.last)
        : '';
    return (first(parts.first) + second).toUpperCase();
  }

  Friend copyWith({
    String? name,
    String? nickname,
    Object? photoPath = _unset,
    String? notes,
  }) =>
      Friend(
        id: id,
        name: name ?? this.name,
        nickname: nickname ?? this.nickname,
        photoPath: identical(photoPath, _unset)
            ? this.photoPath
            : photoPath as String?,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nickname': nickname,
        'photoPath': photoPath,
        'notes': notes,
      };

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        id: j['id'] as String,
        name: j['name'] as String,
        nickname: j['nickname'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        notes: j['notes'] as String? ?? '',
      );
}

const Object _unset = Object();
