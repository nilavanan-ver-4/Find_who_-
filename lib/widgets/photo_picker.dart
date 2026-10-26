import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/providers.dart';
import 'common.dart';

/// Lets the user choose a photo from the gallery and copies it into private
/// storage. Returns the stored path, or null if cancelled or failed (an
/// explanation is shown in that case).
Future<String?> pickPhoto(BuildContext context, WidgetRef ref,
    {ImageSource source = ImageSource.gallery}) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (picked == null) return null;
    return await ref.read(fileStoreProvider).importPhoto(picked.path);
  } on PlatformException catch (e) {
    if (context.mounted) {
      final denied = e.code.contains('denied') || e.code.contains('permission');
      showSnack(
        context,
        denied
            ? 'Photo access was denied. You can allow it in your phone settings.'
            : 'Could not open that photo. Please try another one.',
      );
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Could not load that photo. Please try another one.');
    }
    return null;
  }
}
