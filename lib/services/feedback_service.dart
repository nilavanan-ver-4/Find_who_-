import 'package:flutter/services.dart';

/// Sound and haptic feedback, honouring the user's settings.
class FeedbackService {
  FeedbackService({required this.soundOn, required this.hapticsOn});
  final bool soundOn;
  final bool hapticsOn;

  void tap() {
    if (hapticsOn) HapticFeedback.selectionClick();
    if (soundOn) SystemSound.play(SystemSoundType.click);
  }

  void success() {
    if (hapticsOn) HapticFeedback.mediumImpact();
    if (soundOn) SystemSound.play(SystemSoundType.click);
  }

  void tick() {
    if (hapticsOn) HapticFeedback.lightImpact();
  }
}
