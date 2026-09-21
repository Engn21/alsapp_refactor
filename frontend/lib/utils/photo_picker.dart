import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';

// image_picker's macOS/desktop/web implementations throw for
// ImageSource.camera, so live capture is only offered on phones.
bool get _hasCamera =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Lets the farmer take or choose a photo. Returns null if they cancel or the
/// picker fails. On desktop there's no camera, so it opens the file chooser
/// directly.
Future<XFile?> pickPhoto(BuildContext context) async {
  ImageSource? source = ImageSource.gallery;
  if (_hasCamera) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ctx.tr('Take a photo')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(ctx.tr('Choose from gallery')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
  if (source == null) return null;

  try {
    return await ImagePicker().pickImage(source: source, maxWidth: 1024);
  } catch (e) {
    debugPrint('[photo_picker] pickImage failed: $e');
    return null;
  }
}
