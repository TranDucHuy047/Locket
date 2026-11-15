import 'dart:io';
import 'package:image/image.dart' as img;

const int canvasSize = 1080;

void main() {
  final outDir = Directory('assets/frames');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  _writePng('${outDir.path}/polaroid_classic.png', _buildPolaroidClassic());
  _writePng('${outDir.path}/y2k_cyber.png', _buildY2kCyber());
  _writePng('${outDir.path}/film_strip.png', _buildFilmStrip());
  _writePng('${outDir.path}/cute_pastel.png', _buildCutePastel());
  _writePng('${outDir.path}/photobooth_grid.png', _buildPhotoboothGrid());

  stdout.writeln('Generated 5 1080x1080 32-bit RGBA PNG frames in ${outDir.path}');
}

void _writePng(String path, img.Image image) {
  final bytes = img.encodePng(image);
  File(path).writeAsBytesSync(bytes);
  stdout.writeln('Wrote $path (${bytes.length} bytes)');
}

img.Image _newTransparentCanvas() {
  final image = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  return image;
}

void _punchHole(
  img.Image image, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  int radius = 0,
}) {
  final transparent = img.ColorRgba8(0, 0, 0, 0);
  if (radius <= 0) {
    img.fillRect(
      image,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: transparent,
    );
    return;
  }

  final r2 = radius * radius;
  for (int y = y1; y <= y2; y++) {
    for (int x = x1; x <= x2; x++) {
      bool inside = true;
      if (x < x1 + radius && y < y1 + radius) {
        final dx = (x1 + radius) - x;
        final dy = (y1 + radius) - y;
        inside = dx * dx + dy * dy <= r2;
      } else if (x > x2 - radius && y < y1 + radius) {
        final dx = x - (x2 - radius);
        final dy = (y1 + radius) - y;
        inside = dx * dx + dy * dy <= r2;
      } else if (x < x1 + radius && y > y2 - radius) {
        final dx = (x1 + radius) - x;
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= r2;
      } else if (x > x2 - radius && y > y2 - radius) {
        final dx = x - (x2 - radius);
        final dy = y - (y2 - radius);
        inside = dx * dx + dy * dy <= r2;
      }
      if (inside) {
        image.setPixel(x, y, transparent);
      }
    }
  }
}

void _drawRoundedBorder(
  img.Image image, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int thickness,
  required img.Color color,
  int radius = 0,
}) {
  // Draw outer rect with thickness around the cutout
  img.drawRect(
    image,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    color: color,
    thickness: thickness,
    radius: radius,
  );
}

img.Image _buildPolaroidClassic() {
  final image = _newTransparentCanvas();
  final warmWhite = img.ColorRgba8(250, 248, 245, 255);
  final innerShadow = img.ColorRgba8(215, 210, 202, 255);
  final accentDot = img.ColorRgba8(232, 184, 75, 255);

  img.fill(image, color: warmWhite);

  const left = 48;
  const top = 48;
  const right = canvasSize - 49;
  const bottom = canvasSize - 141;

  _punchHole(image, x1: left, y1: top, x2: right, y2: bottom, radius: 14);
  _drawRoundedBorder(
    image,
    x1: left - 2,
    y1: top - 2,
    x2: right + 2,
    y2: bottom + 2,
    thickness: 3,
    color: innerShadow,
    radius: 16,
  );

  // Decorative warm gold dot & subtle bottom bar accents on Polaroid chin
  img.fillCircle(image, x: 76, y: canvasSize - 70, radius: 9, color: accentDot);
  img.fillRect(
    image,
    x1: 100,
    y1: canvasSize - 74,
    x2: 240,
    y2: canvasSize - 66,
    color: img.ColorRgba8(210, 204, 196, 255),
  );
  return image;
}

img.Image _buildY2kCyber() {
  final image = _newTransparentCanvas();
  const border = 36;

  // Gradient border around all 4 sides
  for (int y = 0; y < canvasSize; y++) {
    for (int x = 0; x < canvasSize; x++) {
      final isBorder = x < border ||
          x >= canvasSize - border ||
          y < border ||
          y >= canvasSize - border;
      if (!isBorder) continue;

      final t = ((x + y) / (2.0 * canvasSize)).clamp(0.0, 1.0);
      final r = (255 * (1 - t) + 0 * t).round();
      final g = (58 * (1 - t) + 230 * t).round();
      final b = (180 * (1 - t) + 255 * t).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Inner thin glowing hairline
  _drawRoundedBorder(
    image,
    x1: border,
    y1: border,
    x2: canvasSize - border - 1,
    y2: canvasSize - border - 1,
    thickness: 3,
    color: img.ColorRgba8(255, 255, 255, 210),
  );

  // Corner viewfinder brackets inside the transparent window
  final bracketColor = img.ColorRgba8(0, 245, 255, 235);
  const offset = 68;
  const len = 56;
  const thick = 6;

  // Top-left
  img.fillRect(image, x1: offset, y1: offset, x2: offset + len, y2: offset + thick, color: bracketColor);
  img.fillRect(image, x1: offset, y1: offset, x2: offset + thick, y2: offset + len, color: bracketColor);
  // Top-right
  img.fillRect(image, x1: canvasSize - offset - len, y1: offset, x2: canvasSize - offset, y2: offset + thick, color: bracketColor);
  img.fillRect(image, x1: canvasSize - offset - thick, y1: offset, x2: canvasSize - offset, y2: offset + len, color: bracketColor);
  // Bottom-left
  img.fillRect(image, x1: offset, y1: canvasSize - offset - thick, x2: offset + len, y2: canvasSize - offset, color: bracketColor);
  img.fillRect(image, x1: offset, y1: canvasSize - offset - len, x2: offset + thick, y2: canvasSize - offset, color: bracketColor);
  // Bottom-right
  img.fillRect(image, x1: canvasSize - offset - len, y1: canvasSize - offset - thick, x2: canvasSize - offset, y2: canvasSize - offset, color: bracketColor);
  img.fillRect(image, x1: canvasSize - offset - thick, y1: canvasSize - offset - len, x2: canvasSize - offset, y2: canvasSize - offset, color: bracketColor);

  // Top-right REC indicator dot
  img.fillCircle(
    image,
    x: canvasSize - 98,
    y: 98,
    radius: 10,
    color: img.ColorRgba8(255, 65, 95, 240),
  );

  return image;
}

img.Image _buildFilmStrip() {
  final image = _newTransparentCanvas();
  final matteBlack = img.ColorRgba8(22, 22, 26, 255);
  final sprocketTransparent = img.ColorRgba8(245, 242, 235, 220);
  final amberLine = img.ColorRgba8(245, 166, 35, 220);

  // Left & Right film borders (64px) and slim top/bottom bars (28px)
  img.fillRect(image, x1: 0, y1: 0, x2: 63, y2: canvasSize - 1, color: matteBlack);
  img.fillRect(image, x1: canvasSize - 64, y1: 0, x2: canvasSize - 1, y2: canvasSize - 1, color: matteBlack);
  img.fillRect(image, x1: 64, y1: 0, x2: canvasSize - 65, y2: 27, color: matteBlack);
  img.fillRect(image, x1: 64, y1: canvasSize - 28, x2: canvasSize - 65, y2: canvasSize - 1, color: matteBlack);

  // Warm amber inner border
  _drawRoundedBorder(
    image,
    x1: 64,
    y1: 28,
    x2: canvasSize - 65,
    y2: canvasSize - 29,
    thickness: 3,
    color: amberLine,
  );

  // Film perforations along left and right edges
  const holeW = 24;
  const holeH = 36;
  const step = 72;
  for (int y = 36; y < canvasSize - 44; y += step) {
    img.fillRect(
      image,
      x1: 20,
      y1: y,
      x2: 20 + holeW,
      y2: y + holeH,
      color: sprocketTransparent,
      radius: 5,
    );
    img.fillRect(
      image,
      x1: canvasSize - 20 - holeW,
      y1: y,
      x2: canvasSize - 20,
      y2: y + holeH,
      color: sprocketTransparent,
      radius: 5,
    );
  }

  return image;
}

img.Image _buildCutePastel() {
  final image = _newTransparentCanvas();
  const border = 44;

  // Soft pastel lavender-to-peach border
  for (int y = 0; y < canvasSize; y++) {
    for (int x = 0; x < canvasSize; x++) {
      final t = (y / canvasSize).clamp(0.0, 1.0);
      final r = (255 * (1 - t) + 236 * t).round();
      final g = (218 * (1 - t) + 214 * t).round();
      final b = (232 * (1 - t) + 255 * t).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  _punchHole(
    image,
    x1: border,
    y1: border,
    x2: canvasSize - border - 1,
    y2: canvasSize - border - 1,
    radius: 32,
  );

  _drawRoundedBorder(
    image,
    x1: border - 2,
    y1: border - 2,
    x2: canvasSize - border + 1,
    y2: canvasSize - border + 1,
    thickness: 4,
    color: img.ColorRgba8(255, 255, 255, 230),
    radius: 34,
  );

  // Cute pastel polka dots on corners
  final dotColors = [
    img.ColorRgba8(255, 148, 184, 255),
    img.ColorRgba8(178, 152, 255, 255),
    img.ColorRgba8(255, 206, 120, 255),
  ];
  final corners = [
    [22, 22],
    [canvasSize - 23, 22],
    [22, canvasSize - 23],
    [canvasSize - 23, canvasSize - 23],
  ];
  for (int i = 0; i < corners.length; i++) {
    img.fillCircle(
      image,
      x: corners[i][0],
      y: corners[i][1],
      radius: 10,
      color: dotColors[i % dotColors.length],
    );
  }

  return image;
}

img.Image _buildPhotoboothGrid() {
  final image = _newTransparentCanvas();
  final frameColor = img.ColorRgba8(24, 24, 29, 255);
  final cellOutline = img.ColorRgba8(255, 255, 255, 180);

  img.fill(image, color: frameColor);

  // Exact 4 cells of 500x500 px inside 1080x1080 px:
  // (26, 26), (554, 26), (26, 554), (554, 554)
  final cells = [
    [26, 26, 525, 525],
    [554, 26, 1053, 525],
    [26, 554, 525, 1053],
    [554, 554, 1053, 1053],
  ];

  for (final c in cells) {
    _punchHole(
      image,
      x1: c[0],
      y1: c[1],
      x2: c[2],
      y2: c[3],
      radius: 20,
    );
    _drawRoundedBorder(
      image,
      x1: c[0] - 1,
      y1: c[1] - 1,
      x2: c[2] + 1,
      y2: c[3] + 1,
      thickness: 2,
      color: cellOutline,
      radius: 21,
    );
  }

  // Subtle center badge dot
  img.fillCircle(
    image,
    x: canvasSize ~/ 2,
    y: canvasSize ~/ 2,
    radius: 8,
    color: img.ColorRgba8(255, 196, 68, 255),
  );

  return image;
}
