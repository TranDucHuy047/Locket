import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locket_studio/main.dart';
import 'package:locket_studio/models/studio_models.dart';

void main() {
  group('Color matrix engine', () {
    test('buildCompositeColorMatrix returns identity matrix for default values', () {
      final List<double> result = buildCompositeColorMatrix(
        preset: ColorFilterPreset.presets.first,
        brightness: 0.0,
        contrast: 1.0,
        saturation: 1.0,
      );

      expect(result.length, 20);
      for (int i = 0; i < 20; i++) {
        expect(
          result[i],
          closeTo(ColorFilterPreset.identityMatrix[i], 1e-6),
        );
      }
    });

    test('buildCompositeColorMatrix modifies matrix when brightness/saturation/preset change', () {
      final List<double> warmMuted = buildCompositeColorMatrix(
        preset: ColorFilterPreset.presets[1], // Locket Warm
        brightness: 0.1,
        contrast: 1.2,
        saturation: 0.0, // grayscale saturation
      );

      expect(warmMuted.length, 20);
      expect(warmMuted[4], isNot(0.0));
      expect(warmMuted[0], isNot(closeTo(1.0, 0.01)));
    });
  });

  group('Locket Studio 4-step pipeline UI', () {
    testWidgets('renders all 4 pipeline steps and switches single/photobooth 2x2',
        (WidgetTester tester) async {
      await tester.pumpWidget(const LocketStudioApp());
      await tester.pumpAndSettle();

      // Verify all 4 pipeline stepper tabs exist
      expect(find.text('1. Khung 1:1'), findsOneWidget);
      expect(find.text('2. Màu & Viền'), findsOneWidget);
      expect(find.text('3. Sticker & Caption'), findsOneWidget);
      expect(find.text('4. Xuất Locket'), findsOneWidget);

      // Default mode is Single 1080x1080
      expect(find.text('1080 × 1080 px • Tỉ lệ 1:1'), findsOneWidget);

      // Switch to Photobooth 2x2
      await tester.tap(find.text('Photobooth 2×2'));
      await tester.pumpAndSettle();

      expect(find.text('Photobooth 2×2 (4 ô 500×500 px)'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ô 1'),
        120.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Ô 1'), findsOneWidget);
      expect(find.text('Ô 4'), findsOneWidget);
    });

    testWidgets('toggling Locket caption and adding sticker updates canvas',
        (WidgetTester tester) async {
      await tester.pumpWidget(const LocketStudioApp());
      await tester.pumpAndSettle();

      // Caption text should initially be visible on the canvas
      expect(find.text('✨ Khoảnh khắc Locket hôm nay'), findsOneWidget);

      // Navigate to Step 3: Sticker & Caption
      await tester.tap(find.text('3. Sticker & Caption'));
      await tester.pumpAndSettle();

      // Now caption text appears both on canvas and on edit button (2 widgets)
      expect(find.text('✨ Khoảnh khắc Locket hôm nay'), findsNWidgets(2));

      // Toggle off the Locket caption switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Caption should be gone from both canvas and edit controls
      expect(find.text('✨ Khoảnh khắc Locket hôm nay'), findsNothing);

      // Add a sticker from the quick sticker bar
      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();

      expect(find.text('Đang chọn Sticker: 🔥'), findsOneWidget);
    });

    testWidgets('Step 2 filter presets and Step 4 export controls render cleanly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const LocketStudioApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('2. Màu & Viền'));
      await tester.pumpAndSettle();
      expect(find.text('Bộ lọc màu (Color Matrix)'), findsOneWidget);
      expect(find.text('Locket Warm'), findsOneWidget);

      await tester.tap(find.text('4. Xuất Locket'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Share Sheet'),
        120.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Lưu vào Album & Mở Locket'), findsOneWidget);
      expect(find.text('Chỉ lưu Album'), findsOneWidget);
      expect(find.text('Share Sheet'), findsOneWidget);
    });
  });
}
