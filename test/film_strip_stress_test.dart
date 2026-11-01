import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('FilmStripBackground & Painter Extreme Dimensions Stress Tests', () {
    testWidgets('FilmStripPainter paints directly without error on Size(0, 0)', (WidgetTester tester) async {
      await tester.pumpWidget(
        CustomPaint(
          size: Size.zero,
          painter: FilmStripPainter(progress: 0.5),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('FilmStripPainter paints directly on extreme dimensions (0x0, 320x480, 2400x3840, 1920x1080)', (WidgetTester tester) async {
      final sizes = [
        const Size(0, 0),
        const Size(1, 1),
        const Size(320, 480),       // Small mobile
        const Size(1920, 1080),     // Full HD Landscape
        const Size(2400, 3840),     // 4K Ultra-res Portrait
        const Size(3840, 2160),     // 4K Landscape
      ];

      for (final size in sizes) {
        for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          await tester.pumpWidget(
            Center(
              child: CustomPaint(
                size: size,
                painter: FilmStripPainter(progress: progress),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.byType(CustomPaint), findsOneWidget);
        }
      }
    });

    testWidgets('FilmStripBackground renders inside SizedBox(0, 0)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 0,
              height: 0,
              child: FilmStripBackground(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(FilmStripBackground), findsOneWidget);
    });

    testWidgets('FilmStripBackground renders inside SizedBox(320, 480)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 480,
              child: FilmStripBackground(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FilmStripBackground), findsOneWidget);
    });

    testWidgets('FilmStripBackground renders inside SizedBox(1920, 1080) landscape', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1920,
              height: 1080,
              child: FilmStripBackground(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FilmStripBackground), findsOneWidget);
    });

    testWidgets('FilmStripBackground renders inside SizedBox(2400, 3840) high-res portrait', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 2400,
              height: 3840,
              child: FilmStripBackground(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(FilmStripBackground), findsOneWidget);
    });

    testWidgets('FraudCheckApp full viewport stress: 320x480 (small mobile)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilmStripBackground), findsOneWidget);
      // Advance animation through multiple cycles
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('FraudCheckApp full viewport stress: 1920x1080 (landscape desktop)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilmStripBackground), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('FraudCheckApp full viewport stress: 2400x3840 (ultra-res portrait)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilmStripBackground), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
