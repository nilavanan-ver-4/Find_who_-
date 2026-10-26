import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'games_common.dart';

const _wheelColors = [
  Color(0xFFFF4F8B), Color(0xFF7C4DFF), Color(0xFFFF9F1C), Color(0xFF14B8A6),
  Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF84CC16), Color(0xFFA855F7),
];

class WheelPainter extends CustomPainter {
  WheelPainter(this.options, this.rotation, this.textColor);
  final List<String> options;
  final double rotation;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final n = options.length;
    final sweep = 2 * pi / n;
    for (var i = 0; i < n; i++) {
      final start = rotation + i * sweep - pi / 2 - sweep / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        true,
        Paint()..color = _wheelColors[i % _wheelColors.length],
      );
      final mid = start + sweep / 2;
      final label = options[i].length > 14 ? '${options[i].substring(0, 13)}…' : options[i];
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: n > 12 ? 10 : 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.62);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(mid);
      tp.paint(canvas, Offset(r * 0.32, -tp.height / 2));
      canvas.restore();
      tp.dispose();
    }
    canvas.drawCircle(c, 18, Paint()..color = Colors.white);
    canvas.drawCircle(c, r, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(WheelPainter old) => old.rotation != rotation || old.options != options;
}

class SpinWheelGame extends StatefulWidget {
  const SpinWheelGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<SpinWheelGame> createState() => _SpinWheelGameState();
}

class _SpinWheelGameState extends State<SpinWheelGame> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late List<String> _options = _initial();
  final _input = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _rotation = 0; // radians, rotation at rest
  double _from = 0;
  double _to = 0;
  String? _result;
  bool _removeAfter = false;

  List<String> _initial() {
    final p = widget.ctx.players;
    if (p.length >= 2) return List.of(p);
    return List.of(widget.ctx.content.challenges.take(6));
  }

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      setState(() {
        _rotation = _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value);
      });
    });
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _rotation = _to % (2 * pi);
        widget.ctx.tap();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _input.dispose();
    super.dispose();
  }

  void _spin() {
    final err = Validators.wheelOptions(_options);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    if (_anim.isAnimating) return;
    final n = _options.length;
    final index = widget.ctx.random.nextInt(n);
    final sweep = 2 * pi / n;
    // The pointer is at the top. Segment i is centred at angle rotation + i*sweep (from top).
    // We need rotation + index*sweep == 0 (mod 2pi), so rotation = -index*sweep.
    final target = -index * sweep;
    final current = _rotation % (2 * pi);
    var delta = (target - current) % (2 * pi);
    if (delta < 0) delta += 2 * pi;
    final jitter = (widget.ctx.random.nextInt(60) - 30) / 100 * sweep; // stay inside the segment
    _from = _rotation;
    _to = _rotation + delta + 2 * pi * (4 + widget.ctx.random.nextInt(3)) + jitter;
    setState(() => _result = null);
    _anim.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _result = _options[index];
        if (_removeAfter && _options.length > 2) {
          // keep the result visible, remove on next spin by rebuilding list now
          _options = List.of(_options)..removeAt(index);
          _rotation = 0;
        }
      });
    });
  }

  void _add() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _options = [..._options, _input.text.trim()];
      _input.clear();
      _result = null;
    });
  }

  void _preset(List<String> items) => setState(() {
        _options = List.of(items.take(24));
        _result = null;
        _rotation = 0;
      });

  @override
  Widget build(BuildContext context) {
    final c = widget.ctx.content;
    final spinning = _anim.isAnimating;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (widget.ctx.players.length >= 2)
                _PresetChip('Players', () => _preset(widget.ctx.players)),
              _PresetChip('Challenges', () => _preset(c.challenges)),
              _PresetChip('Punishments', () => _preset(c.punishments)),
              _PresetChip('Activities', () => _preset(c.activities)),
              _PresetChip('Yes / No', () => _preset(const ['Yes', 'No', 'Maybe', 'Ask again'])),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AspectRatio(
                aspectRatio: 1,
                child: RepaintBoundary(
                  child: CustomPaint(painter: WheelPainter(_options, _rotation, Colors.white)),
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 48, color: Color(0xFF212121)),
          ],
        ),
        const SizedBox(height: Spacing.md),
        if (_result != null)
          PromptCard(text: _result!, label: 'The wheel says', emoji: '🎉'),
        const SizedBox(height: Spacing.md),
        GradientButton(
          label: spinning ? 'Spinning...' : 'SPIN',
          icon: Icons.rotate_right,
          onPressed: spinning ? null : _spin,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remove winner after each spin'),
          value: _removeAfter,
          onChanged: (v) => setState(() => _removeAfter = v),
        ),
        Text('Options (${_options.length})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _input,
                  maxLength: 40,
                  decoration: const InputDecoration(hintText: 'Add an option', counterText: ''),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Type something first';
                    if (_options.any((o) => o.toLowerCase() == t.toLowerCase())) return 'Already on the wheel';
                    if (_options.length >= 24) return 'Maximum 24 options';
                    return null;
                  },
                  onFieldSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(height: 56, child: FilledButton(onPressed: _add, child: const Icon(Icons.add))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (var i = 0; i < _options.length; i++)
              InputChip(
                label: Text(_options[i], overflow: TextOverflow.ellipsis),
                onDeleted: spinning ? null : () => setState(() {
                  _options = List.of(_options)..removeAt(i);
                  _result = null;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(label: Text(label), onPressed: onTap),
      );
}
