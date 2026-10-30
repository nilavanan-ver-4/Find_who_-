import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entry card for the Tamil Memes section.
class MemesBanner extends StatelessWidget {
  const MemesBanner({super.key, required this.count, this.compact = false});
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tamil Memes, $count templates',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9F1C), Color(0xFFE91E63), Color(0xFF7C4DFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 18 : 24),
            onTap: () => context.push('/memes'),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 16),
              child: Row(
                children: [
                  Text('🎬', style: TextStyle(fontSize: compact ? 28 : 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tamil Memes',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: compact ? 17 : 22)),
                        Text('$count blank templates · add Tamil or Tanglish captions',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
