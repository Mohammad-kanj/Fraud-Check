import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  void setMobileScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('M1: Branding & Visuals Foundation Tests', () {
    testWidgets('FilmStripBackground is mounted and animates smoothly',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilmStripBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify custom painter repaint behavior
      final painter1 = FilmStripPainter(progress: 0.1);
      final painter2 = FilmStripPainter(progress: 0.2);
      final painter3 = FilmStripPainter(progress: 0.1);
      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter3), isFalse);
    });

    testWidgets('Logo displays cutout without circular ShaderMask',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, 'assets/logo.png');

      // Ensure no ShaderMask is used on the logo
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('Main menu does NOT display legacy subtitle',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(find.text(['The', 'English', 'Barra', 'El', 'Salfa'].join(' ')), findsNothing);
      expect(find.text(['Barra', 'El', 'Salfa'].join(' ')), findsNothing);
    });

    test('Color palette matches modern Fraud Check specification', () {
      expect(bg.toARGB32(), 0xFF0A0D1B);
      expect(card.toARGB32(), 0xFF151932);
      expect(card2.toARGB32(), 0xFF1E2448);
      expect(cardHi.toARGB32(), 0xFF1E2448);
      expect(border.toARGB32(), 0xFF2C3466);
      expect(yellow.toARGB32(), 0xFFFFC837);
      expect(red.toARGB32(), 0xFFFF3B5C);
      expect(green.toARGB32(), 0xFF00E5A3);
      expect(blue.toARGB32(), 0xFF3A86FF);
      expect(ink.toARGB32(), 0xFFF8FAFC);
      expect(muted.toARGB32(), 0xFF94A3B8);
    });

    test('All 7 audio files exist and are non-empty WAV files', () {
      final soundNames = ['tap', 'start', 'reveal', 'vote', 'guess', 'win', 'lose'];
      for (final name in soundNames) {
        final file = File('assets/sounds/$name.wav');
        expect(file.existsSync(), isTrue, reason: '$name.wav should exist');
        expect(file.lengthSync(), greaterThan(1000), reason: '$name.wav should not be empty');
      }
    });

    test('Sound service triggers all 7 sound methods safely when sound is disabled',
        () async {
      Sound.enabled = false;
      await expectLater(Sound.tap(), completes);
      await expectLater(Sound.start(), completes);
      await expectLater(Sound.reveal(), completes);
      await expectLater(Sound.vote(), completes);
      await expectLater(Sound.guess(), completes);
      await expectLater(Sound.win(), completes);
      await expectLater(Sound.lose(), completes);
    });

    testWidgets('App theme configures GoogleFonts PixelifySans text theme',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme;
      expect(theme, isNotNull);
      expect(theme!.scaffoldBackgroundColor, bg);
      expect(theme.colorScheme.primary, yellow);
      expect(theme.colorScheme.surface, card);
      expect(theme.textTheme.bodyMedium?.fontFamily?.toLowerCase(), contains('pixelifysans'));
    });
  });
}
