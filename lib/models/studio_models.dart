import 'package:flutter/material.dart';

enum StudioLayoutMode { single, photobooth2x2 }

enum ExportFormat { jpeg, png }

enum CaptionPresetType { custom, time, location, music, weather }

enum FontFamilyStyle { roundedSans, classicSerif, monoTech, handwritten }

class ColorFilterPreset {
  const ColorFilterPreset({
    required this.id,
    required this.name,
    required this.matrix,
    required this.previewColor,
  });

  final String id;
  final String name;
  final List<double> matrix;
  final Color previewColor;

  static const List<double> identityMatrix = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<ColorFilterPreset> presets = <ColorFilterPreset>[
    ColorFilterPreset(
      id: 'original',
      name: 'Gốc',
      matrix: identityMatrix,
      previewColor: Color(0xFF9E9E9E),
    ),
    ColorFilterPreset(
      id: 'locket_warm',
      name: 'Locket Warm',
      matrix: <double>[
        1.10, 0.04, 0.00, 0, 8,
        0.02, 1.03, 0.00, 0, 4,
        0.00, 0.00, 0.90, 0, -4,
        0, 0, 0, 1, 0,
      ],
      previewColor: Color(0xFFFFB74D),
    ),
    ColorFilterPreset(
      id: 'vintage_film',
      name: 'Vintage Film',
      matrix: <double>[
        0.96, 0.14, 0.06, 0, 10,
        0.06, 0.92, 0.08, 0, 6,
        0.02, 0.08, 0.78, 0, 12,
        0, 0, 0, 1, 0,
      ],
      previewColor: Color(0xFFBC8A5F),
    ),
    ColorFilterPreset(
      id: 'cool_cinema',
      name: 'Cool Cinema',
      matrix: <double>[
        0.90, 0.00, 0.04, 0, -6,
        0.00, 1.00, 0.05, 0, 0,
        0.04, 0.08, 1.14, 0, 10,
        0, 0, 0, 1, 0,
      ],
      previewColor: Color(0xFF4FC3F7),
    ),
    ColorFilterPreset(
      id: 'soft_bw',
      name: 'Soft B&W',
      matrix: <double>[
        0.33, 0.59, 0.08, 0, 6,
        0.33, 0.59, 0.08, 0, 6,
        0.33, 0.59, 0.08, 0, 6,
        0, 0, 0, 1, 0,
      ],
      previewColor: Color(0xFF616161),
    ),
    ColorFilterPreset(
      id: 'vivid_pop',
      name: 'Vivid Pop',
      matrix: <double>[
        1.18, -0.06, -0.04, 0, -4,
        -0.05, 1.16, -0.04, 0, -4,
        -0.04, -0.06, 1.18, 0, -4,
        0, 0, 0, 1, 0,
      ],
      previewColor: Color(0xFFFF4081),
    ),
  ];
}

List<double> buildCompositeColorMatrix({
  required ColorFilterPreset preset,
  required double brightness,
  required double contrast,
  required double saturation,
}) {
  final List<double> bMat = _brightnessMatrix(brightness);
  final List<double> cMat = _contrastMatrix(contrast);
  final List<double> sMat = _saturationMatrix(saturation);

  // Combine: brightness -> contrast -> saturation -> preset
  var result = _multiplyColorMatrices(cMat, bMat);
  result = _multiplyColorMatrices(sMat, result);
  result = _multiplyColorMatrices(preset.matrix, result);
  return result;
}

List<double> _brightnessMatrix(double brightness) {
  final double offset = brightness * 255.0;
  return <double>[
    1, 0, 0, 0, offset,
    0, 1, 0, 0, offset,
    0, 0, 1, 0, offset,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrastMatrix(double contrast) {
  final double t = (1.0 - contrast) * 127.5;
  return <double>[
    contrast, 0, 0, 0, t,
    0, contrast, 0, 0, t,
    0, 0, contrast, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _saturationMatrix(double saturation) {
  const double rw = 0.2126;
  const double gw = 0.7152;
  const double bw = 0.0722;
  final double invSat = 1.0 - saturation;
  final double r = invSat * rw;
  final double g = invSat * gw;
  final double b = invSat * bw;
  return <double>[
    r + saturation, g, b, 0, 0,
    r, g + saturation, b, 0, 0,
    r, g, b + saturation, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
  final List<double> out = List<double>.filled(20, 0.0);
  for (int row = 0; row < 4; row++) {
    final int rIdx = row * 5;
    for (int col = 0; col < 4; col++) {
      out[rIdx + col] = a[rIdx] * b[col] +
          a[rIdx + 1] * b[5 + col] +
          a[rIdx + 2] * b[10 + col] +
          a[rIdx + 3] * b[15 + col];
    }
    out[rIdx + 4] = a[rIdx] * b[4] +
        a[rIdx + 1] * b[9] +
        a[rIdx + 2] * b[14] +
        a[rIdx + 3] * b[19] +
        a[rIdx + 4];
  }
  return out;
}

class FrameAsset {
  const FrameAsset({
    required this.id,
    required this.name,
    this.assetPath,
    this.customFilePath,
    this.recommendedForPhotobooth = false,
  });

  final String id;
  final String name;
  final String? assetPath;
  final String? customFilePath;
  final bool recommendedForPhotobooth;

  bool get hasFrame => assetPath != null || customFilePath != null;

  static const FrameAsset none = FrameAsset(
    id: 'none',
    name: 'Không viền',
  );

  static const List<FrameAsset> builtInFrames = <FrameAsset>[
    none,
    FrameAsset(
      id: 'polaroid_classic',
      name: 'Polaroid',
      assetPath: 'assets/frames/polaroid_classic.png',
    ),
    FrameAsset(
      id: 'y2k_cyber',
      name: 'Y2K Cyber',
      assetPath: 'assets/frames/y2k_cyber.png',
    ),
    FrameAsset(
      id: 'film_strip',
      name: 'Film Strip',
      assetPath: 'assets/frames/film_strip.png',
    ),
    FrameAsset(
      id: 'cute_pastel',
      name: 'Cute Pastel',
      assetPath: 'assets/frames/cute_pastel.png',
    ),
    FrameAsset(
      id: 'photobooth_grid',
      name: 'Photobooth 2x2',
      assetPath: 'assets/frames/photobooth_grid.png',
      recommendedForPhotobooth: true,
    ),
  ];
}

class StickerItem {
  const StickerItem({
    required this.id,
    this.text,
    this.imagePath,
    this.position = const Offset(0.5, 0.45),
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  final String id;
  final String? text;
  final String? imagePath;
  final Offset position;
  final double scale;
  final double rotation;

  StickerItem copyWith({
    String? id,
    String? text,
    String? imagePath,
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return StickerItem(
      id: id ?? this.id,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}

class LocketCaptionConfig {
  const LocketCaptionConfig({
    this.enabled = true,
    this.text = '✨ Khoảnh khắc Locket hôm nay',
    this.presetType = CaptionPresetType.custom,
    this.fontStyle = FontFamilyStyle.roundedSans,
    this.normalizedOffset = const Offset(0.5, 0.80),
    this.backgroundOpacity = 0.50,
    this.borderRadiusPx = 20.0,
    this.textColor = Colors.white,
  });

  final bool enabled;
  final String text;
  final CaptionPresetType presetType;
  final FontFamilyStyle fontStyle;
  final Offset normalizedOffset;
  final double backgroundOpacity;
  final double borderRadiusPx;
  final Color textColor;

  LocketCaptionConfig copyWith({
    bool? enabled,
    String? text,
    CaptionPresetType? presetType,
    FontFamilyStyle? fontStyle,
    Offset? normalizedOffset,
    double? backgroundOpacity,
    double? borderRadiusPx,
    Color? textColor,
  }) {
    return LocketCaptionConfig(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      presetType: presetType ?? this.presetType,
      fontStyle: fontStyle ?? this.fontStyle,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      borderRadiusPx: borderRadiusPx ?? this.borderRadiusPx,
      textColor: textColor ?? this.textColor,
    );
  }

  static String defaultTextForPreset(CaptionPresetType preset) {
    final DateTime now = DateTime.now();
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    switch (preset) {
      case CaptionPresetType.custom:
        return '✨ Khoảnh khắc Locket hôm nay';
      case CaptionPresetType.time:
        return '🕒 $hh:$mm • Today';
      case CaptionPresetType.location:
        return '📍 TP. Hồ Chí Minh';
      case CaptionPresetType.music:
        return '🎵 Đang nghe nhạc chill';
      case CaptionPresetType.weather:
        return '🌙 26°C • Tối nay';
    }
  }
}
