import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

Widget buildPlatformImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

Future<String?> writeExportTempFile(Uint8List bytes, String filename) async {
  final Directory tempDir = await getTemporaryDirectory();
  final File outFile = File('${tempDir.path}${Platform.pathSeparator}$filename');
  await outFile.writeAsBytes(bytes, flush: true);
  return outFile.path;
}

Future<void> saveExportToGallery({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? filePath,
  Rect? sharePositionOrigin,
}) async {
  if (filePath == null) {
    throw StateError('Không tìm thấy tệp ảnh tạm để lưu.');
  }
  bool hasPermission = await Gal.hasPermission(toAlbum: true);
  if (!hasPermission) {
    hasPermission = await Gal.requestPermission(toAlbum: true);
  }
  if (!hasPermission) {
    throw StateError('Chưa được cấp quyền lưu ảnh vào Album điện thoại.');
  }
  await Gal.putImage(filePath, album: 'Locket Studio');
}
