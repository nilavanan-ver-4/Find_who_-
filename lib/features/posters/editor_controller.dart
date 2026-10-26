import 'package:flutter/material.dart';

import '../../core/utils/validators.dart';
import '../../models/poster_doc.dart';
import '../../models/poster_models.dart';

class EditorArgs {
  const EditorArgs({required this.doc, required this.title});
  final PosterDoc doc;
  final String title;
}

/// Holds the poster being edited plus the undo history.
class EditorController extends ChangeNotifier {
  EditorController(PosterDoc initial)
      : _doc = initial,
        _initial = initial;

  static const maxUndo = 50;
  static const maxElements = 25;

  PosterDoc _doc;
  final PosterDoc _initial;
  final List<PosterDoc> _undo = [];
  String? _selectedId;
  bool _textUndoPushed = false;

  PosterDoc get doc => _doc;
  String? get selectedId => _selectedId;
  PosterElement? get selected => _doc.elementById(_selectedId);
  bool get canUndo => _undo.isNotEmpty;
  bool get isModified => !identical(_doc, _initial) && _undo.isNotEmpty;

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    _textUndoPushed = false;
    notifyListeners();
  }

  /// Call before a change (or at the start of a drag / slider interaction).
  void checkpoint() {
    _undo.add(_doc);
    if (_undo.length > maxUndo) _undo.removeAt(0);
  }

  void undo() {
    if (_undo.isEmpty) return;
    _doc = _undo.removeLast();
    if (_doc.elementById(_selectedId) == null) _selectedId = null;
    notifyListeners();
  }

  void reset() {
    if (identical(_doc, _initial)) return;
    checkpoint();
    _doc = _initial;
    _selectedId = null;
    notifyListeners();
  }

  void _set(PosterDoc d) {
    _doc = d;
    notifyListeners();
  }

  // --- elements ------------------------------------------------------------
  void updateSelected(PosterElement Function(PosterElement) f, {bool checkpointFirst = true}) {
    final e = selected;
    if (e == null) return;
    if (checkpointFirst) checkpoint();
    _set(_doc.updateElement(f(e)));
  }

  /// Live change (slider drag): no checkpoint, caller uses [checkpoint] on start.
  void liveUpdateSelected(PosterElement Function(PosterElement) f) {
    final e = selected;
    if (e == null) return;
    _set(_doc.updateElement(f(e)));
  }

  void editText(String text) {
    final e = selected;
    if (e == null || e.kind != ElementKind.text) return;
    if (!_textUndoPushed) {
      checkpoint();
      _textUndoPushed = true;
    }
    _set(_doc.updateElement(e.copyWith(text: text)));
  }

  void moveBy(String id, double dxFraction, double dyFraction) {
    final e = _doc.elementById(id);
    if (e == null) return;
    _set(_doc.updateElement(e.copyWith(dx: e.dx + dxFraction, dy: e.dy + dyFraction)));
  }

  /// Returns an error message when the element could not be added.
  String? addText(String text, {Color color = Colors.white, String font = 'sans-serif'}) {
    final err = Validators.caption(text);
    if (err != null) return err;
    return _add(PosterElement(
      id: PosterDoc.newId(),
      kind: ElementKind.text,
      text: text.trim(),
      dy: 0.5,
      size: 28,
      color: color,
      font: font,
    ));
  }

  String? addSticker(String emoji) => _add(PosterElement(
        id: PosterDoc.newId(),
        kind: ElementKind.sticker,
        text: emoji,
        dx: 0.2 + (_doc.elements.length % 4) * 0.2,
        dy: 0.15 + (_doc.elements.length % 5) * 0.15,
        size: 56,
      ));

  String? _add(PosterElement e) {
    if (_doc.elements.length >= maxElements) {
      return 'That is a lot of stuff! Remove something first.';
    }
    checkpoint();
    _doc = _doc.copyWith(elements: [..._doc.elements, e]);
    _selectedId = e.id;
    _textUndoPushed = false;
    notifyListeners();
    return null;
  }

  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    checkpoint();
    _selectedId = null;
    _set(_doc.removeElement(id));
  }

  // --- document -----------------------------------------------------------
  void setLayout(PosterLayout l) {
    if (l == _doc.layout) return;
    checkpoint();
    _set(_doc.copyWith(layout: l));
  }

  void setBackground(List<Color> colors) {
    checkpoint();
    _set(_doc.copyWith(colors: colors));
  }

  void setPattern(PosterPattern pattern) {
    checkpoint();
    _set(_doc.copyWith(pattern: pattern));
  }

  void setPhoto(String? path) {
    checkpoint();
    _set(_doc.copyWith(photoPath: path));
  }

  void setBorder(PosterBorder b) {
    checkpoint();
    _set(_doc.copyWith(border: b));
  }

  void setBorderColor(Color c) {
    checkpoint();
    _set(_doc.copyWith(borderColor: c, border: _doc.border == PosterBorder.none ? PosterBorder.solid : null));
  }
}
