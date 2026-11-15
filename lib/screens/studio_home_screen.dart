import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/studio_models.dart';
import '../services/export_handoff_service.dart';
import '../services/image_input_service.dart';
import '../widgets/studio_canvas.dart';

class StudioHomeScreen extends StatefulWidget {
  const StudioHomeScreen({
    super.key,
    this.inputService,
    this.exportService,
  });

  final ImageInputService? inputService;
  final ExportHandoffService? exportService;

  @override
  State<StudioHomeScreen> createState() => _StudioHomeScreenState();
}

class _StudioHomeScreenState extends State<StudioHomeScreen> {
  late final ImageInputService _inputService;
  late final ExportHandoffService _exportService;
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Pipeline tab (0..3)
  int _activeStep = 0;

  // Step 1: Input & 1:1 Layout State
  StudioLayoutMode _layoutMode = StudioLayoutMode.single;
  String? _singleImagePath;
  final List<String?> _photoboothPaths = List<String?>.filled(4, null);
  int _activePhotoboothSlot = 0;
  bool _useDemoMode = true;
  Color _photoboothBgColor = const Color(0xFF18181D);

  // Step 2: Color Matrix & 32-bit PNG Frame State
  ColorFilterPreset _selectedPreset = ColorFilterPreset.presets.first;
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  final List<FrameAsset> _availableFrames =
      List<FrameAsset>.from(FrameAsset.builtInFrames);
  FrameAsset _selectedFrame = FrameAsset.builtInFrames[1]; // Polaroid default

  // Step 3: Stickers & Simulated Locket Caption Bar State
  final List<StickerItem> _stickers = <StickerItem>[];
  String? _selectedStickerId;
  LocketCaptionConfig _captionConfig = const LocketCaptionConfig();

  // Step 4: Export & Handoff State
  ExportFormat _exportFormat = ExportFormat.jpeg;
  bool _isExporting = false;
  bool _isBusy = false;
  ExportResult? _lastExportResult;

  static const List<String> _quickStickers = <String>[
    '✨',
    '❤️',
    '🔥',
    '📸',
    '🧸',
    '🎀',
    '⭐',
    '💿',
    'LOVE',
    'LOCKET',
  ];

  static const List<Color> _photoboothBgOptions = <Color>[
    Color(0xFF18181D),
    Color(0xFFFAF8F5),
    Color(0xFFFFD6E8),
    Color(0xFFD6ECFF),
    Color(0xFF241C3A),
  ];

  @override
  void initState() {
    super.initState();
    _inputService = widget.inputService ?? ImageInputService();
    _exportService = widget.exportService ?? ExportHandoffService();
  }

  List<double> get _compositeMatrix => buildCompositeColorMatrix(
        preset: _selectedPreset,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
      );

  StickerItem? get _selectedSticker {
    if (_selectedStickerId == null) return null;
    for (final StickerItem s in _stickers) {
      if (s.id == _selectedStickerId) return s;
    }
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF2A2A35),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Step 1 Actions ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final String? path =
          await _inputService.pickAndCropSingleImage(source: source);
      if (path == null) return;
      setState(() {
        _useDemoMode = false;
        if (_layoutMode == StudioLayoutMode.single) {
          _singleImagePath = path;
        } else {
          _photoboothPaths[_activePhotoboothSlot] = path;
        }
      });
    } catch (e) {
      _showSnack('Không thể chọn ảnh: $e', isError: true);
    }
  }

  Future<void> _cropCurrentSlot() async {
    final String? targetPath = _layoutMode == StudioLayoutMode.single
        ? _singleImagePath
        : _photoboothPaths[_activePhotoboothSlot];

    if (targetPath == null) {
      _showSnack('Hãy chọn ảnh từ Thư viện hoặc Camera trước khi cắt.');
      return;
    }

    try {
      final String? cropped = await _inputService.cropToSquare(targetPath);
      if (cropped == null) return;
      setState(() {
        if (_layoutMode == StudioLayoutMode.single) {
          _singleImagePath = cropped;
        } else {
          _photoboothPaths[_activePhotoboothSlot] = cropped;
        }
      });
    } catch (e) {
      _showSnack('Lỗi khi cắt ảnh 1:1: $e', isError: true);
    }
  }

  Future<void> _pickFourPhotoboothImages() async {
    try {
      final List<String> paths = await _inputService.pickPhotoboothImages();
      if (paths.isEmpty) return;
      setState(() {
        _useDemoMode = false;
        for (int i = 0; i < paths.length && i < 4; i++) {
          _photoboothPaths[i] = paths[i];
        }
      });
      _showSnack('Đã nạp ${paths.length} ảnh vào lưới Photobooth 2x2.');
    } catch (e) {
      _showSnack('Không thể chọn nhiều ảnh: $e', isError: true);
    }
  }

  void _setLayoutMode(StudioLayoutMode mode) {
    if (_layoutMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _layoutMode = mode;
      if (mode == StudioLayoutMode.photobooth2x2 &&
          (_selectedFrame.id == 'none' ||
              _selectedFrame.id == 'polaroid_classic')) {
        _selectedFrame = _availableFrames.firstWhere(
          (FrameAsset f) => f.id == 'photobooth_grid',
          orElse: () => _selectedFrame,
        );
      } else if (mode == StudioLayoutMode.single &&
          _selectedFrame.id == 'photobooth_grid') {
        _selectedFrame = _availableFrames.firstWhere(
          (FrameAsset f) => f.id == 'polaroid_classic',
          orElse: () => FrameAsset.none,
        );
      }
    });
  }

  // --- Step 2 Actions ---
  Future<void> _importCustomFramePng() async {
    try {
      final String? path = await _inputService.pickCustomPngFromGallery();
      if (path == null) return;
      final FrameAsset custom = FrameAsset(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: 'PNG của bạn',
        customFilePath: path,
      );
      setState(() {
        _availableFrames.add(custom);
        _selectedFrame = custom;
      });
      _showSnack('Đã thêm khung PNG từ máy vào lớp phủ 1080×1080.');
    } catch (e) {
      _showSnack('Không thể nạp khung PNG: $e', isError: true);
    }
  }

  // --- Step 3 Actions ---
  void _addTextOrEmojiSticker(String label) {
    final String id = 'stk_${DateTime.now().microsecondsSinceEpoch}';
    final int count = _stickers.length;
    final Offset initialPos = Offset(
      0.35 + ((count * 0.11) % 0.35),
      0.32 + ((count * 0.09) % 0.30),
    );
    setState(() {
      _stickers.add(
        StickerItem(
          id: id,
          text: label,
          position: initialPos,
          scale: 1.0,
          rotation: 0.0,
        ),
      );
      _selectedStickerId = id;
    });
  }

  Future<void> _importCustomStickerPng() async {
    try {
      final String? path = await _inputService.pickCustomPngFromGallery();
      if (path == null) return;
      final String id = 'stk_img_${DateTime.now().microsecondsSinceEpoch}';
      setState(() {
        _stickers.add(
          StickerItem(
            id: id,
            imagePath: path,
            position: const Offset(0.5, 0.45),
            scale: 1.15,
            rotation: 0.0,
          ),
        );
        _selectedStickerId = id;
      });
      _showSnack('Đã chèn Sticker PNG từ thư viện.');
    } catch (e) {
      _showSnack('Không thể chèn Sticker PNG: $e', isError: true);
    }
  }

  Future<void> _openCaptionEditorDialog() async {
    final TextEditingController controller =
        TextEditingController(text: _captionConfig.text);
    final String? updated = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1D26),
          title: const Text('Chỉnh sửa thanh Caption Locket'),
          content: TextField(
            controller: controller,
            maxLength: 70,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Nhập lời nhắn, giờ, vị trí...',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Áp dụng'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (updated != null) {
      setState(() {
        _captionConfig = _captionConfig.copyWith(
          enabled: true,
          text: updated,
        );
      });
    }
  }

  // --- Step 4 Actions ---
  Future<ExportResult?> _captureCanvas() async {
    setState(() {
      _selectedStickerId = null;
      _isExporting = true;
      _isBusy = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final ExportResult result = await _exportService.captureAndExportCanvas(
        repaintBoundaryKey: _repaintBoundaryKey,
        format: _exportFormat,
      );
      if (mounted) {
        setState(() {
          _lastExportResult = result;
        });
      }
      return result;
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _saveToAlbumAndOpenLocket() async {
    HapticFeedback.mediumImpact();
    try {
      final ExportResult? result = await _captureCanvas();
      if (result == null) return;
      await _exportService.saveToGallery(result.file);
      final bool openedDirect = await _exportService.openLocketApp();
      _showSnack(
        openedDirect
            ? 'Đã lưu ảnh 1080×1080 (${result.sizeInKb.toStringAsFixed(0)} KB) & mở Locket!'
            : 'Đã lưu vào Album (${result.sizeInKb.toStringAsFixed(0)} KB). Đang mở trang Locket.',
      );
    } catch (e) {
      _showSnack('Lỗi xuất hoặc mở Locket: $e', isError: true);
    }
  }

  Future<void> _saveOnlyToAlbum() async {
    HapticFeedback.mediumImpact();
    try {
      final ExportResult? result = await _captureCanvas();
      if (result == null) return;
      await _exportService.saveToGallery(result.file);
      _showSnack(
        'Đã lưu ${result.width}×${result.height} (${result.sizeInKb.toStringAsFixed(0)} KB) vào Album "Locket Studio"!',
      );
    } catch (e) {
      _showSnack('Lỗi lưu vào Album: $e', isError: true);
    }
  }

  Future<void> _shareViaSheet([BuildContext? buttonContext]) async {
    HapticFeedback.mediumImpact();
    Rect? origin;
    final RenderObject? box = buttonContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }

    try {
      final ExportResult? result = await _captureCanvas();
      if (result == null) return;
      await _exportService.shareViaSystemSheet(
        result.file,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      _showSnack('Lỗi chia sẻ ảnh: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double maxCanvasSide = math.min(
      screenSize.width - 32,
      math.max(210.0, screenSize.height * 0.39),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHeader(),
            _buildPipelineStepper(),
            const SizedBox(height: 8),
            // Center 1:1 Studio Canvas
            Center(
              child: SizedBox(
                width: maxCanvasSide,
                height: maxCanvasSide,
                child: StudioCanvas(
                  repaintBoundaryKey: _repaintBoundaryKey,
                  layoutMode: _layoutMode,
                  singleImagePath: _singleImagePath,
                  photoboothPaths: _photoboothPaths,
                  activePhotoboothSlot: _activePhotoboothSlot,
                  useDemoMode: _useDemoMode,
                  compositeColorMatrix: _compositeMatrix,
                  photoboothBgColor: _photoboothBgColor,
                  selectedFrame: _selectedFrame,
                  stickers: _stickers,
                  selectedStickerId: _selectedStickerId,
                  captionConfig: _captionConfig,
                  isExporting: _isExporting,
                  onCanvasBackgroundTap: () {
                    if (_selectedStickerId != null) {
                      setState(() => _selectedStickerId = null);
                    }
                  },
                  onSingleSlotTap: () => _pickImage(ImageSource.gallery),
                  onPhotoboothSlotTap: (int index) {
                    setState(() => _activePhotoboothSlot = index);
                  },
                  onSelectSticker: (String id) {
                    setState(() {
                      _selectedStickerId = id;
                      _activeStep = 2;
                    });
                  },
                  onUpdateSticker: (StickerItem updated) {
                    final int idx = _stickers.indexWhere(
                      (StickerItem item) => item.id == updated.id,
                    );
                    if (idx >= 0) {
                      setState(() => _stickers[idx] = updated);
                    }
                  },
                  onDeleteSticker: (String id) {
                    setState(() {
                      _stickers.removeWhere((StickerItem item) => item.id == id);
                      if (_selectedStickerId == id) {
                        _selectedStickerId = null;
                      }
                    });
                  },
                  onUpdateCaptionOffset: (Offset nextOffset) {
                    setState(() {
                      _captionConfig = _captionConfig.copyWith(
                        normalizedOffset: nextOffset,
                      );
                    });
                  },
                  onEditCaptionTap: _openCaptionEditorDialog,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildCanvasStatusLine(),
            const SizedBox(height: 6),
            // Bottom Control Panel
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF16161E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: Color(0xFF282836), width: 1),
                  ),
                ),
                child: _buildActiveStepPanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFB800), Color(0xFFFF6E40)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFF121216),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Locket Studio',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Companion Tool • Tiền kỳ 1:1',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          FilterChip(
            label: Text(
              _useDemoMode ? 'Ảnh mẫu: Bật' : 'Ảnh mẫu: Tắt',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            selected: _useDemoMode,
            onSelected: (bool v) => setState(() => _useDemoMode = v),
            selectedColor: const Color(0xFFFFB800).withValues(alpha: 0.22),
            checkmarkColor: const Color(0xFFFFB800),
            side: const BorderSide(color: Color(0xFF333344)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineStepper() {
    const List<(String, IconData)> steps = <(String, IconData)>[
      ('1. Khung 1:1', Icons.crop_square_rounded),
      ('2. Màu & Viền', Icons.filter_frames_rounded),
      ('3. Sticker & Caption', Icons.auto_awesome_rounded),
      ('4. Xuất Locket', Icons.ios_share_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List<Widget>.generate(steps.length, (int index) {
          final bool active = _activeStep == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < steps.length - 1 ? 6 : 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeStep = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFFFB800)
                          : const Color(0xFF2E2E3E),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          steps[index].$2,
                          size: 14,
                          color:
                              active ? const Color(0xFF141418) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          steps[index].$1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? const Color(0xFF141418)
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCanvasStatusLine() {
    final String modeText = _layoutMode == StudioLayoutMode.single
        ? '1080 × 1080 px • Tỉ lệ 1:1'
        : 'Photobooth 2×2 (4 ô 500×500 px)';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.aspect_ratio_rounded, size: 13, color: Color(0xFFFFB800)),
        const SizedBox(width: 6),
        Text(
          modeText,
          style: const TextStyle(
            fontSize: 11.5,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_selectedFrame.hasFrame) ...<Widget>[
          const Text('  •  ', style: TextStyle(color: Colors.white30)),
          Text(
            'Viền: ${_selectedFrame.name}',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFFFB800),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActiveStepPanel() {
    switch (_activeStep) {
      case 0:
        return _buildStep1InputPanel();
      case 1:
        return _buildStep2FilterFramePanel();
      case 2:
        return _buildStep3StickerCaptionPanel();
      default:
        return _buildStep4ExportPanel();
    }
  }

  Widget _buildStep1InputPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: <Widget>[
        const Text(
          'Bố cục chuẩn hóa 1:1 (1080×1080 px)',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ModeCardButton(
                title: 'Ảnh đơn 1:1',
                subtitle: '1080 × 1080 px',
                icon: Icons.crop_din_rounded,
                selected: _layoutMode == StudioLayoutMode.single,
                onTap: () => _setLayoutMode(StudioLayoutMode.single),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeCardButton(
                title: 'Photobooth 2×2',
                subtitle: '4 ô 500 × 500 px',
                icon: Icons.grid_view_rounded,
                selected: _layoutMode == StudioLayoutMode.photobooth2x2,
                onTap: () => _setLayoutMode(StudioLayoutMode.photobooth2x2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(
                _layoutMode == StudioLayoutMode.single
                    ? 'Chọn từ Thư viện'
                    : 'Chọn ảnh cho Ô ${_activePhotoboothSlot + 1}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Chụp Camera'),
            ),
            OutlinedButton.icon(
              onPressed: _cropCurrentSlot,
              icon: const Icon(Icons.crop_rounded, size: 18),
              label: const Text('Cắt vuông 1:1'),
            ),
            if (_layoutMode == StudioLayoutMode.photobooth2x2)
              FilledButton.tonalIcon(
                onPressed: _pickFourPhotoboothImages,
                icon: const Icon(Icons.collections_rounded, size: 18),
                label: const Text('Chọn 4 ảnh nhanh'),
              ),
          ],
        ),
        if (_layoutMode == StudioLayoutMode.photobooth2x2) ...<Widget>[
          const SizedBox(height: 14),
          const Text(
            'Chọn ô Photobooth đang chỉnh & màu nền đệm:',
            style: TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(4, (int idx) {
              final bool selected = _activePhotoboothSlot == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Ô ${idx + 1}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _activePhotoboothSlot = idx),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: _photoboothBgOptions.map((Color color) {
              final bool isSelected = _photoboothBgColor == color;
              return GestureDetector(
                onTap: () => setState(() => _photoboothBgColor = color),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFB800)
                          : Colors.white30,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2FilterFramePanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Bộ lọc màu (Color Matrix)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPreset = ColorFilterPreset.presets.first;
                  _brightness = 0.0;
                  _contrast = 1.0;
                  _saturation = 1.0;
                });
              },
              child: const Text('Đặt lại màu'),
            ),
          ],
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ColorFilterPreset.presets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final ColorFilterPreset preset = ColorFilterPreset.presets[i];
              final bool selected = preset.id == _selectedPreset.id;
              return ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: preset.previewColor,
                  radius: 8,
                ),
                label: Text(preset.name),
                selected: selected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPreset = preset);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildCompactSlider(
          label: 'Sáng',
          value: _brightness,
          min: -0.30,
          max: 0.30,
          onChanged: (double v) => setState(() => _brightness = v),
        ),
        _buildCompactSlider(
          label: 'Tương phản',
          value: _contrast,
          min: 0.70,
          max: 1.50,
          onChanged: (double v) => setState(() => _contrast = v),
        ),
        _buildCompactSlider(
          label: 'Bão hòa',
          value: _saturation,
          min: 0.00,
          max: 2.00,
          onChanged: (double v) => setState(() => _saturation = v),
        ),
        const Divider(height: 18, color: Color(0xFF282836)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Khung viền PNG 32-bit (Alpha Overlay)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: _importCustomFramePng,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: const Text('Tải PNG'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableFrames.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final FrameAsset frame = _availableFrames[index];
              final bool selected = frame.id == _selectedFrame.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFrame = frame);
                },
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF23232F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFB800)
                              : Colors.white24,
                          width: selected ? 2.2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildFrameThumbnail(frame),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 68,
                      child: Text(
                        frame.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? const Color(0xFFFFB800)
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFrameThumbnail(FrameAsset frame) {
    if (frame.customFilePath != null) {
      return Image.file(File(frame.customFilePath!), fit: BoxFit.cover);
    }
    if (frame.assetPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(color: const Color(0xFF39394B)),
          Image.asset(frame.assetPath!, fit: BoxFit.cover),
        ],
      );
    }
    return const Icon(Icons.block_rounded, color: Colors.white38, size: 22);
  }

  Widget _buildStep3StickerCaptionPanel() {
    final StickerItem? activeSticker = _selectedSticker;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Thanh Caption giả lập Locket (Bo 20px)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            Switch(
              value: _captionConfig.enabled,
              onChanged: (bool val) {
                setState(() {
                  _captionConfig = _captionConfig.copyWith(enabled: val);
                });
              },
            ),
          ],
        ),
        if (_captionConfig.enabled) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _openCaptionEditorDialog,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    _captionConfig.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _captionPresetChip(CaptionPresetType.custom, '💬 Lời nhắn'),
              _captionPresetChip(CaptionPresetType.time, '🕒 Giờ'),
              _captionPresetChip(CaptionPresetType.location, '📍 Vị trí'),
              _captionPresetChip(CaptionPresetType.music, '🎵 Nhạc'),
              _captionPresetChip(CaptionPresetType.weather, '🌙 Thời tiết'),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                const Text(
                  'Phông chữ: ',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                _fontStyleChip(FontFamilyStyle.roundedSans, 'Hiện đại'),
                const SizedBox(width: 6),
                _fontStyleChip(FontFamilyStyle.classicSerif, 'Cổ điển'),
                const SizedBox(width: 6),
                _fontStyleChip(FontFamilyStyle.monoTech, 'Mono'),
                const SizedBox(width: 6),
                _fontStyleChip(FontFamilyStyle.handwritten, 'Nghiêng'),
              ],
            ),
          ),
          _buildCompactSlider(
            label: 'Độ mờ nền (${(_captionConfig.backgroundOpacity * 100).round()}%)',
            value: _captionConfig.backgroundOpacity,
            min: 0.15,
            max: 0.85,
            onChanged: (double v) {
              setState(() {
                _captionConfig = _captionConfig.copyWith(backgroundOpacity: v);
              });
            },
          ),
        ],
        const Divider(height: 18, color: Color(0xFF282836)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Text(
              'Sticker (Chạm, kéo, phóng to, xoay)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            TextButton.icon(
              onPressed: _importCustomStickerPng,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: const Text('PNG từ máy'),
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickStickers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final String label = _quickStickers[i];
              return ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 15)),
                onPressed: () => _addTextOrEmojiSticker(label),
              );
            },
          ),
        ),
        if (activeSticker != null) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF20202B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Đang chọn Sticker: ${activeSticker.text ?? "PNG"}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _stickers.removeWhere(
                            (StickerItem s) => s.id == activeSticker.id,
                          );
                          _selectedStickerId = null;
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: Color(0xFFFF5252),
                      ),
                      label: const Text(
                        'Xóa',
                        style: TextStyle(color: Color(0xFFFF5252)),
                      ),
                    ),
                  ],
                ),
                _buildCompactSlider(
                  label: 'Kích thước',
                  value: activeSticker.scale,
                  min: 0.45,
                  max: 3.4,
                  onChanged: (double v) {
                    final int idx = _stickers.indexWhere(
                      (StickerItem s) => s.id == activeSticker.id,
                    );
                    if (idx >= 0) {
                      setState(() {
                        _stickers[idx] = activeSticker.copyWith(scale: v);
                      });
                    }
                  },
                ),
                _buildCompactSlider(
                  label: 'Góc xoay',
                  value: activeSticker.rotation,
                  min: -math.pi,
                  max: math.pi,
                  onChanged: (double v) {
                    final int idx = _stickers.indexWhere(
                      (StickerItem s) => s.id == activeSticker.id,
                    );
                    if (idx >= 0) {
                      setState(() {
                        _stickers[idx] = activeSticker.copyWith(rotation: v);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _captionPresetChip(CaptionPresetType type, String label) {
    final bool selected = _captionConfig.presetType == type;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() {
          _captionConfig = _captionConfig.copyWith(
            enabled: true,
            presetType: type,
            text: LocketCaptionConfig.defaultTextForPreset(type),
          );
        });
      },
    );
  }

  Widget _fontStyleChip(FontFamilyStyle style, String label) {
    final bool selected = _captionConfig.fontStyle == style;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() {
          _captionConfig = _captionConfig.copyWith(fontStyle: style);
        });
      },
    );
  }

  Widget _buildStep4ExportPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: <Widget>[
        const Text(
          'Kết xuất ảnh nén nhẹ (< 2MB) & Chuyển Locket',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ModeCardButton(
                title: 'JPEG tối ưu',
                subtitle: 'Nén gọn < 2MB',
                icon: Icons.speed_rounded,
                selected: _exportFormat == ExportFormat.jpeg,
                onTap: () => setState(() => _exportFormat = ExportFormat.jpeg),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeCardButton(
                title: 'PNG sắc nét',
                subtitle: 'Tự nén < 2MB',
                icon: Icons.high_quality_rounded,
                selected: _exportFormat == ExportFormat.png,
                onTap: () => setState(() => _exportFormat = ExportFormat.png),
              ),
            ),
          ],
        ),
        if (_lastExportResult != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2620),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E7D32)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF66BB6A),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã xuất ${_lastExportResult!.width}×${_lastExportResult!.height} px • '
                    '${_lastExportResult!.sizeInKb.toStringAsFixed(0)} KB '
                    '(${_lastExportResult!.format.name.toUpperCase()})',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _saveToAlbumAndOpenLocket,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB800),
              foregroundColor: const Color(0xFF141418),
            ),
            icon: _isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch_rounded),
            label: const Text(
              'Lưu vào Album & Mở Locket',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isBusy ? null : _saveOnlyToAlbum,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Chỉ lưu Album'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Builder(
                builder: (BuildContext buttonContext) {
                  return OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => _shareViaSheet(buttonContext),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Sheet'),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Mẹo: Sau khi lưu, ảnh 1080×1080 px sẽ nằm ngay đầu Thư viện để bạn chọn trực tiếp khi Locket mở lên.',
          style: TextStyle(fontSize: 11.5, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildCompactSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeCardButton extends StatelessWidget {
  const _ModeCardButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFB800).withValues(alpha: 0.14)
              : const Color(0xFF20202A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFB800)
                : const Color(0xFF303040),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: selected ? const Color(0xFFFFB800) : Colors.white70,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFFFFB800) : Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
