import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/studio_models.dart';

class ExportResult {
  const ExportResult({
    required this.file,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.format,
    this.fellBackToJpeg = false,
  });

  final File file;
  final int width;
  final int height;
  final int sizeBytes;
  final ExportFormat format;
  final bool fellBackToJpeg;

  double get sizeInKb => sizeBytes / 1024.0;
}

class ExportHandoffService {
  static const int targetSizePx = 1080;
  static const int maxBytesLimit = 2 * 1024 * 1024; // 2 MB

  Future<ExportResult> captureAndExportCanvas({
    required GlobalKey repaintBoundaryKey,
    required ExportFormat format,
  }) async {
    final RenderObject? renderObject =
        repaintBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Không tìm thấy khung vẽ để kết xuất.');
    }

    final double renderWidth = renderObject.size.width;
    if (renderWidth <= 0) {
      throw StateError('Kích thước khung vẽ chưa sẵn sàng.');
    }

    final double pixelRatio = targetSizePx / renderWidth;
    final ui.Image uiImage = await renderObject.toImage(pixelRatio: pixelRatio);
    final int capturedWidth = uiImage.width;
    final int capturedHeight = uiImage.height;

    final ByteData? byteData =
        await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    uiImage.dispose();

    if (byteData == null) {
      throw StateError('Không thể đọc dữ liệu pixel từ khung vẽ.');
    }

    img.Image imageBuffer = img.Image.fromBytes(
      width: capturedWidth,
      height: capturedHeight,
      bytes: byteData.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

    if (imageBuffer.width != targetSizePx || imageBuffer.height != targetSizePx) {
      imageBuffer = img.copyResize(
        imageBuffer,
        width: targetSizePx,
        height: targetSizePx,
        interpolation: img.Interpolation.cubic,
      );
    }

    ExportFormat effectiveFormat = format;
    bool fellBackToJpeg = false;
    late Uint8List encodedBytes;

    if (format == ExportFormat.png) {
      final Uint8List pngBytes =
          Uint8List.fromList(img.encodePng(imageBuffer, level: 6));
      if (pngBytes.length <= maxBytesLimit) {
        encodedBytes = pngBytes;
      } else {
        effectiveFormat = ExportFormat.jpeg;
        fellBackToJpeg = true;
        encodedBytes = _encodeJpegUnderLimit(imageBuffer);
      }
    } else {
      encodedBytes = _encodeJpegUnderLimit(imageBuffer);
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String ext = effectiveFormat == ExportFormat.png ? 'png' : 'jpg';
    final String filename =
        'locket_1080_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final File outFile = File('${tempDir.path}${Platform.pathSeparator}$filename');
    await outFile.writeAsBytes(encodedBytes, flush: true);

    return ExportResult(
      file: outFile,
      width: targetSizePx,
      height: targetSizePx,
      sizeBytes: encodedBytes.length,
      format: effectiveFormat,
      fellBackToJpeg: fellBackToJpeg,
    );
  }

  Uint8List _encodeJpegUnderLimit(img.Image imageBuffer) {
    const List<int> qualities = <int>[92, 86, 80, 72, 64, 55];
    Uint8List result = Uint8List.fromList(img.encodeJpg(imageBuffer, quality: 92));
    for (final int q in qualities) {
      result = Uint8List.fromList(img.encodeJpg(imageBuffer, quality: q));
      if (result.length <= maxBytesLimit) {
        return result;
      }
    }
    return result;
  }

  Future<void> saveToGallery(File file) async {
    bool hasPermission = await Gal.hasPermission(toAlbum: true);
    if (!hasPermission) {
      hasPermission = await Gal.requestPermission(toAlbum: true);
    }
    if (!hasPermission) {
      throw StateError('Chưa được cấp quyền lưu ảnh vào Album điện thoại.');
    }
    await Gal.putImage(file.path, album: 'Locket Studio');
  }

  Future<void> shareViaSystemSheet(
    File file, {
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'Locket Studio 1080x1080',
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100),
      ),
    );
  }

  Future<bool> openLocketApp() async {
    final Uri deepLink = Uri.parse('locket://');
    try {
      final bool launched = await launchUrl(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (_) {
      // Fallback to store link below.
    }

    final Uri storeUri = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/vn/app/locket-widget/id1600525061'
          : 'https://play.google.com/store/apps/details?id=com.locket.Locket',
    );
    await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    return false;
  }
}
