import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/studio_models.dart';
import '../utils/platform_helper.dart';

class StudioCanvas extends StatelessWidget {
  const StudioCanvas({
    super.key,
    required this.repaintBoundaryKey,
    required this.layoutMode,
    required this.singleImagePath,
    required this.photoboothPaths,
    required this.activePhotoboothSlot,
    required this.useDemoMode,
    required this.compositeColorMatrix,
    required this.photoboothBgColor,
    required this.selectedFrame,
    required this.stickers,
    required this.selectedStickerId,
    required this.captionConfig,
    required this.isExporting,
    required this.onCanvasBackgroundTap,
    required this.onSingleSlotTap,
    required this.onPhotoboothSlotTap,
    required this.onSelectSticker,
    required this.onUpdateSticker,
    required this.onDeleteSticker,
    required this.onUpdateCaptionOffset,
    required this.onEditCaptionTap,
  });

  final GlobalKey repaintBoundaryKey;
  final StudioLayoutMode layoutMode;
  final String? singleImagePath;
  final List<String?> photoboothPaths;
  final int activePhotoboothSlot;
  final bool useDemoMode;
  final List<double> compositeColorMatrix;
  final Color photoboothBgColor;
  final FrameAsset selectedFrame;
  final List<StickerItem> stickers;
  final String? selectedStickerId;
  final LocketCaptionConfig captionConfig;
  final bool isExporting;

  final VoidCallback onCanvasBackgroundTap;
  final VoidCallback onSingleSlotTap;
  final ValueChanged<int> onPhotoboothSlotTap;
  final ValueChanged<String> onSelectSticker;
  final ValueChanged<StickerItem> onUpdateSticker;
  final ValueChanged<String> onDeleteSticker;
  final ValueChanged<Offset> onUpdateCaptionOffset;
  final VoidCallback onEditCaptionTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isExporting ? 0 : 20),
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double canvasSide = constraints.maxWidth;
              final double scale = canvasSide / 1080.0;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onCanvasBackgroundTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Layer 1: Base Photo / 2x2 Photobooth + Color Matrix Filter
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(compositeColorMatrix),
                      child: layoutMode == StudioLayoutMode.single
                          ? _buildSinglePhotoLayer(scale)
                          : _buildPhotoboothLayer(canvasSide, scale),
                    ),

                    // Layer 2: 32-bit PNG Alpha Frame Overlay at (0, 0)
                    if (selectedFrame.hasFrame)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: true,
                          child: _buildFrameOverlay(),
                        ),
                      ),

                    // Layer 3A: Interactive Stickers
                    ...stickers.map(
                      (StickerItem item) => _InteractiveStickerWidget(
                        key: ValueKey<String>(item.id),
                        item: item,
                        canvasSide: canvasSide,
                        scale: scale,
                        isSelected: !isExporting && selectedStickerId == item.id,
                        onSelect: () => onSelectSticker(item.id),
                        onUpdate: onUpdateSticker,
                        onDelete: () => onDeleteSticker(item.id),
                      ),
                    ),

                    // Layer 3B: Simulated Locket Caption Bar
                    if (captionConfig.enabled)
                      _buildCaptionLayer(canvasSide, scale),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePhotoLayer(double scale) {
    if (singleImagePath != null) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.expand(
          child: buildPlatformImage(
            singleImagePath!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _DemoPhotoArtwork(
              slotIndex: 0,
              scale: scale,
              showLabel: false,
            ),
          ),
        ),
      );
    }

    if (useDemoMode) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.hardEdge,
        child: _DemoPhotoArtwork(
          slotIndex: 0,
          scale: scale,
          showLabel: false,
        ),
      );
    }

    return GestureDetector(
      onTap: onSingleSlotTap,
      child: Container(
        color: const Color(0xFF1A1A22),
        child: Center(
          child: isExporting
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: const Color(0xFFFFB800),
                      size: 110 * scale,
                    ),
                    SizedBox(height: 24 * scale),
                    Text(
                      'Chạm để chọn ảnh 1:1',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 34 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPhotoboothLayer(double canvasSide, double scale) {
    // Exact 2x2 grid: four 500x500 px cells inside 1080x1080 px
    final List<Rect> cellRects = <Rect>[
      Rect.fromLTWH(26 * scale, 26 * scale, 500 * scale, 500 * scale),
      Rect.fromLTWH(554 * scale, 26 * scale, 500 * scale, 500 * scale),
      Rect.fromLTWH(26 * scale, 554 * scale, 500 * scale, 500 * scale),
      Rect.fromLTWH(554 * scale, 554 * scale, 500 * scale, 500 * scale),
    ];

    return Container(
      width: canvasSide,
      height: canvasSide,
      color: photoboothBgColor,
      child: Stack(
        children: List<Widget>.generate(4, (int index) {
          final Rect rect = cellRects[index];
          final String? path =
              index < photoboothPaths.length ? photoboothPaths[index] : null;
          final bool isActive = !isExporting && activePhotoboothSlot == index;

          return Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              onTap: () => onPhotoboothSlotTap(index),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20 * scale),
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFFFFB800),
                          width: math.max(2.0, 5 * scale),
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18 * scale),
                  child: _buildPhotoboothCellContent(index, path, scale),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPhotoboothCellContent(int index, String? path, double scale) {
    if (path != null) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.hardEdge,
        child: SizedBox.expand(
          child: buildPlatformImage(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _DemoPhotoArtwork(
              slotIndex: index,
              scale: scale,
              showLabel: false,
            ),
          ),
        ),
      );
    }

    if (useDemoMode) {
      return InteractiveViewer(
        minScale: 1.0,
        maxScale: 4.0,
        clipBehavior: Clip.hardEdge,
        child: _DemoPhotoArtwork(
          slotIndex: index,
          scale: scale,
          showLabel: false,
        ),
      );
    }

    return Container(
      color: const Color(0xFF23232D),
      child: Center(
        child: isExporting
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white60,
                    size: 64 * scale,
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    'Ô ${index + 1}',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 28 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFrameOverlay() {
    if (selectedFrame.customFilePath != null) {
      return buildPlatformImage(
        selectedFrame.customFilePath!,
        fit: BoxFit.fill,
      );
    }
    if (selectedFrame.assetPath != null) {
      return Image.asset(
        selectedFrame.assetPath!,
        fit: BoxFit.fill,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCaptionLayer(double canvasSide, double scale) {
    final double alignX = (captionConfig.normalizedOffset.dx * 2) - 1.0;
    final double alignY = (captionConfig.normalizedOffset.dy * 2) - 1.0;

    return Align(
      alignment: Alignment(alignX, alignY),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 48 * scale),
        child: GestureDetector(
          onTap: onEditCaptionTap,
          onPanUpdate: (DragUpdateDetails details) {
            final Offset next = Offset(
              (captionConfig.normalizedOffset.dx +
                      details.delta.dx / canvasSide)
                  .clamp(0.15, 0.85),
              (captionConfig.normalizedOffset.dy +
                      details.delta.dy / canvasSide)
                  .clamp(0.12, 0.92),
            );
            onUpdateCaptionOffset(next);
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: canvasSide * 0.86),
            padding: EdgeInsets.symmetric(
              horizontal: 34 * scale,
              vertical: 18 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: captionConfig.backgroundOpacity,
              ),
              borderRadius: BorderRadius.circular(
                captionConfig.borderRadiusPx * scale,
              ),
              border: isExporting
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: math.max(1.0, 2.0 * scale),
                    ),
            ),
            child: Text(
              captionConfig.text.trim().isEmpty
                  ? 'Nhấn để nhập caption...'
                  : captionConfig.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _captionTextStyle(scale),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _captionTextStyle(double scale) {
    final double fontSize = math.max(10.0, 34 * scale);
    switch (captionConfig.fontStyle) {
      case FontFamilyStyle.roundedSans:
        return TextStyle(
          color: captionConfig.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.25,
        );
      case FontFamilyStyle.classicSerif:
        return TextStyle(
          color: captionConfig.textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'serif',
          height: 1.25,
        );
      case FontFamilyStyle.monoTech:
        return TextStyle(
          color: captionConfig.textColor,
          fontSize: fontSize * 0.92,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          letterSpacing: 0.8,
          height: 1.25,
        );
      case FontFamilyStyle.handwritten:
        return TextStyle(
          color: captionConfig.textColor,
          fontSize: fontSize * 1.04,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.25,
        );
    }
  }
}

class _InteractiveStickerWidget extends StatefulWidget {
  const _InteractiveStickerWidget({
    super.key,
    required this.item,
    required this.canvasSide,
    required this.scale,
    required this.isSelected,
    required this.onSelect,
    required this.onUpdate,
    required this.onDelete,
  });

  final StickerItem item;
  final double canvasSide;
  final double scale;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<StickerItem> onUpdate;
  final VoidCallback onDelete;

  @override
  State<_InteractiveStickerWidget> createState() =>
      _InteractiveStickerWidgetState();
}

class _InteractiveStickerWidgetState extends State<_InteractiveStickerWidget> {
  late Offset _initialPosition;
  late Offset _initialFocalPoint;
  late double _initialScale;
  late double _initialRotation;

  @override
  Widget build(BuildContext context) {
    final double baseWidgetSize = 170 * widget.scale;
    final double centerX = widget.item.position.dx * widget.canvasSide;
    final double centerY = widget.item.position.dy * widget.canvasSide;

    return Positioned(
      left: centerX - baseWidgetSize / 2,
      top: centerY - baseWidgetSize / 2,
      width: baseWidgetSize,
      height: baseWidgetSize,
      child: GestureDetector(
        onTap: widget.onSelect,
        onScaleStart: (ScaleStartDetails details) {
          widget.onSelect();
          _initialPosition = widget.item.position;
          _initialFocalPoint = details.focalPoint;
          _initialScale = widget.item.scale;
          _initialRotation = widget.item.rotation;
        },
        onScaleUpdate: (ScaleUpdateDetails details) {
          final Offset delta =
              (details.focalPoint - _initialFocalPoint) / widget.canvasSide;
          final Offset nextPos = Offset(
            (_initialPosition.dx + delta.dx).clamp(0.06, 0.94),
            (_initialPosition.dy + delta.dy).clamp(0.06, 0.94),
          );
          final double nextScale =
              (_initialScale * details.scale).clamp(0.45, 3.4);
          final double nextRotation = _initialRotation + details.rotation;

          widget.onUpdate(
            widget.item.copyWith(
              position: nextPos,
              scale: nextScale,
              rotation: nextRotation,
            ),
          );
        },
        child: Transform.rotate(
          angle: widget.item.rotation,
          child: Transform.scale(
            scale: widget.item.scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.all(10 * widget.scale),
                  decoration: widget.isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFFB800),
                            width: math.max(1.5, 4 * widget.scale),
                          ),
                          borderRadius: BorderRadius.circular(18 * widget.scale),
                          color: Colors.black.withValues(alpha: 0.16),
                        )
                      : null,
                  child: _buildStickerGraphic(),
                ),
                if (widget.isSelected)
                  Positioned(
                    top: -10 * widget.scale,
                    right: -10 * widget.scale,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: math.max(20.0, 44 * widget.scale),
                        height: math.max(20.0, 44 * widget.scale),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B5C),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: math.max(12.0, 26 * widget.scale),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerGraphic() {
    if (widget.item.imagePath != null) {
      return buildPlatformImage(
        widget.item.imagePath!,
        fit: BoxFit.contain,
      );
    }

    final String label = widget.item.text ?? '✨';
    final bool isWordBadge = label.runes.length > 2 &&
        RegExp(r'^[A-Za-z0-9\s!]+$').hasMatch(label);

    if (isWordBadge) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 18 * widget.scale,
          vertical: 10 * widget.scale,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFFB800), Color(0xFFFF5E7E)],
          ),
          borderRadius: BorderRadius.circular(24 * widget.scale),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12 * widget.scale,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36 * widget.scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.contain,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 108 * widget.scale,
          height: 1.0,
        ),
      ),
    );
  }
}

class _DemoPhotoArtwork extends StatelessWidget {
  const _DemoPhotoArtwork({
    required this.slotIndex,
    required this.scale,
    this.showLabel = true,
  });

  final int slotIndex;
  final double scale;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    const List<List<Color>> palettes = <List<Color>>[
      <Color>[Color(0xFFFF7A59), Color(0xFFFFB84D), Color(0xFF4B3F72)],
      <Color>[Color(0xFF00C9FF), Color(0xFF92FE9D), Color(0xFF2B2D42)],
      <Color>[Color(0xFFFF5F9E), Color(0xFFB388FF), Color(0xFF311B92)],
      <Color>[Color(0xFFFFD166), Color(0xFFEF476F), Color(0xFF118AB2)],
    ];
    final List<Color> colors = palettes[slotIndex % palettes.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _BokehArtPainter(slotIndex: slotIndex),
        child: showLabel
            ? Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(20 * scale),
                  child: Text(
                    'DEMO ${slotIndex + 1}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _BokehArtPainter extends CustomPainter {
  const _BokehArtPainter({required this.slotIndex});

  final int slotIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint sunPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * (0.28 + slotIndex * 0.12), size.height * 0.30),
      size.width * 0.18,
      sunPaint,
    );

    final Paint ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012;

    canvas.drawCircle(
      Offset(size.width * 0.70, size.height * 0.42),
      size.width * 0.14,
      ringPaint,
    );

    // Subtle mountain/horizon silhouette at bottom
    final Path hill = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.56,
        size.width * 0.62,
        size.height * 0.74,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.84,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      hill,
      Paint()..color = Colors.black.withValues(alpha: 0.24),
    );
  }

  @override
  bool shouldRepaint(covariant _BokehArtPainter oldDelegate) =>
      oldDelegate.slotIndex != slotIndex;
}
