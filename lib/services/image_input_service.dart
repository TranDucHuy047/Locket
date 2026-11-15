import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImageInputService {
  ImageInputService({
    ImagePicker? picker,
    ImageCropper? cropper,
  })  : _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  final ImagePicker _picker;
  final ImageCropper _cropper;

  Future<String?> pickAndCropSingleImage({
    required ImageSource source,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );
    if (picked == null) return null;

    final String? croppedPath = await cropToSquare(picked.path);
    return croppedPath ?? picked.path;
  }

  Future<String?> cropToSquare(String sourcePath) async {
    try {
      final CroppedFile? cropped = await _cropper.cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 1080,
        maxHeight: 1080,
        compressQuality: 95,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: <PlatformUiSettings>[
          AndroidUiSettings(
            toolbarTitle: 'Cắt vuông 1:1 (1080x1080)',
            toolbarColor: const Color(0xFF141418),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFFFB800),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Cắt vuông 1:1',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      return cropped?.path;
    } on MissingPluginException {
      return sourcePath;
    } on UnimplementedError {
      return sourcePath;
    } on UnsupportedError {
      return sourcePath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<List<String>> pickPhotoboothImages() async {
    final List<XFile> picked = await _picker.pickMultiImage(
      limit: 4,
      imageQuality: 95,
    );
    return picked.take(4).map((XFile file) => file.path).toList();
  }

  Future<String?> pickCustomPngFromGallery() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    return picked?.path;
  }
}
