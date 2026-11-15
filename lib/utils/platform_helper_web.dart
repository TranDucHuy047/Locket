import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

bool get isApplePlatform =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

Widget buildPlatformImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  return Image.network(
    path,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

Future<String?> writeExportTempFile(Uint8List bytes, String filename) async {
  return null;
}

Future<void> saveExportToGallery({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? filePath,
  Rect? sharePositionOrigin,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile.fromData(
          bytes,
          name: filename,
          mimeType: mimeType,
        ),
      ],
      text: 'Locket Studio 1080x1080',
      sharePositionOrigin:
          sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100),
    ),
  );
}
