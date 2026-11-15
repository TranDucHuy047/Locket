import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/studio_models.dart';
import '../utils/platform_helper.dart' as platform;

class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.format,
    this.filePath,
    this.fellBackToJpeg = false,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final String? filePath;
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

    final bool isPng = effectiveFormat == ExportFormat.png;
    final String ext = isPng ? 'png' : 'jpg';
    final String mimeType = isPng ? 'image/png' : 'image/jpeg';
    final String filename =
        'locket_1080_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final String? filePath =
        await platform.writeExportTempFile(encodedBytes, filename);

    return ExportResult(
      bytes: encodedBytes,
      filename: filename,
      mimeType: mimeType,
      filePath: filePath,
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

  Future<void> saveToGallery(
    ExportResult result, {
    Rect? sharePositionOrigin,
  }) async {
    await platform.saveExportToGallery(
      bytes: result.bytes,
      filename: result.filename,
      mimeType: result.mimeType,
      filePath: result.filePath,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> shareViaSystemSheet(
    ExportResult result, {
    Rect? sharePositionOrigin,
  }) async {
    final XFile xfile = result.filePath != null
        ? XFile(result.filePath!)
        : XFile.fromData(
            result.bytes,
            name: result.filename,
            mimeType: result.mimeType,
          );
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[xfile],
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
      platform.isApplePlatform
          ? 'https://apps.apple.com/vn/app/locket-widget/id1600525061'
          : 'https://play.google.com/store/apps/details?id=com.locket.Locket',
    );
    await launchUrl(storeUri, mode: LaunchMode.externalApplication);
    return false;
  }
}
