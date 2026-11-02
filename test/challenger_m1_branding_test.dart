import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUpAll(() {
    // Disable HTTP runtime fetching during test runs to ensure offline determinism
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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

  group('Challenger M1: Typography & Archivo Font Family Conformance (F3)', () {
    testWidgets('ThemeData textTheme explicitly applies GoogleFonts.archivo to all 15 TextTheme styles',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme;
      expect(theme, isNotNull, reason: 'MaterialApp must have a defined theme');

      final textTheme = theme!.textTheme;
      expect(textTheme, isNotNull);

      // Verify all 15 typography styles provided by Material 3 TextTheme
      final styles = <String, TextStyle?>{
        'displayLarge': textTheme.displayLarge,
        'displayMedium': textTheme.displayMedium,
        'displaySmall': textTheme.displaySmall,
        'headlineLarge': textTheme.headlineLarge,
        'headlineMedium': textTheme.headlineMedium,
        'headlineSmall': textTheme.headlineSmall,
        'titleLarge': textTheme.titleLarge,
        'titleMedium': textTheme.titleMedium,
        'titleSmall': textTheme.titleSmall,
        'bodyLarge': textTheme.bodyLarge,
        'bodyMedium': textTheme.bodyMedium,
        'bodySmall': textTheme.bodySmall,
        'labelLarge': textTheme.labelLarge,
        'labelMedium': textTheme.labelMedium,
        'labelSmall': textTheme.labelSmall,
      };

      for (final entry in styles.entries) {
        expect(entry.value, isNotNull, reason: '${entry.key} style must not be null');
        expect(
          entry.value!.fontFamily,
          isNotNull,
          reason: '${entry.key} must define a fontFamily',
        );
        expect(
          entry.value!.fontFamily!.toLowerCase(),
          contains('archivo'),
          reason: '${entry.key} font family "${entry.value!.fontFamily}" must contain "archivo"',
        );
      }
    });

    testWidgets('DefaultTextStyle in widget tree inherits GoogleFonts Archivo',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final BuildContext context = tester.element(find.text('FRAUD CHECK'));
      final defaultStyle = DefaultTextStyle.of(context).style;
      expect(
        defaultStyle.fontFamily?.toLowerCase(),
        contains('archivo'),
        reason: 'DefaultTextStyle must resolve to Archivo font family',
      );
    });

    testWidgets('No Text widget on Home screen overrides fontFamily with an alien font',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets, isNotEmpty);

      for (final textWidget in textWidgets) {
        if (textWidget.style?.fontFamily != null) {
          expect(
            textWidget.style!.fontFamily!.toLowerCase(),
            contains('archivo'),
            reason: 'Text widget with text "${textWidget.data}" has foreign fontFamily: ${textWidget.style!.fontFamily}',
          );
        }
      }
    });
  });

  group('Challenger M1: Complete English Subtitle Removal from Home (F4)', () {
    testWidgets('find.text strictly verifies legacy subtitle is absent',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final legacyFull = ['The', 'English', 'Barra', 'El', 'Salfa'].join(' ');
      final legacyLower = ['the', 'english', 'barra', 'el', 'salfa'].join(' ');
      final legacyTitle = ['Barra', 'El', 'Salfa'].join(' ');
      final legacyMixed = ['Barra', 'el', 'Salfa'].join(' ');
      final legacyPureLower = ['barra', 'el', 'salfa'].join(' ');

      // Exact phrase match
      expect(find.text(legacyFull), findsNothing);

      // Case variations and partial phrases
      expect(find.text(legacyLower), findsNothing);
      expect(find.text('The English'), findsNothing);
      expect(find.text(legacyTitle), findsNothing);
      expect(find.text(legacyPureLower), findsNothing);
      expect(find.text(legacyMixed), findsNothing);
    });

    testWidgets('find.textContaining verifies no RichText or partial text contains the removed subtitle',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final legacyFull = ['The', 'English', 'Barra', 'El', 'Salfa'].join(' ');
      final legacyTitle = ['Barra', 'El', 'Salfa'].join(' ');
      final legacyPureLower = ['barra', 'el', 'salfa'].join(' ');

      expect(find.textContaining(legacyFull, findRichText: true), findsNothing);
      expect(find.textContaining(legacyTitle, findRichText: true), findsNothing);
      expect(find.textContaining(legacyPureLower, findRichText: true), findsNothing);
      expect(find.textContaining('The English', findRichText: true), findsNothing);
    });

    testWidgets('Exhaustive inventory of text rendered on Home screen matches expected UI only',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final renderedTexts = textWidgets.map((t) => t.data).whereType<String>().toList();

      // Home screen must contain title and buttons
      expect(renderedTexts, contains('FRAUD CHECK'));
      expect(renderedTexts, contains('Play'));
      expect(renderedTexts, contains('Settings'));
      expect(renderedTexts, contains('Rules'));

      // None of the rendered texts should mention legacy phrase or English subtitle
      final legacyCheck = ['barra', 'el', 'salfa'].join(' ');
      for (final text in renderedTexts) {
        expect(text.toLowerCase(), isNot(contains('the english')));
        expect(text.toLowerCase(), isNot(contains(legacyCheck)));
      }
    });

    test('Static source verification: _home() in lib/main.dart contains no subtitle text', () {
      final mainFile = File('lib/main.dart');
      expect(mainFile.existsSync(), isTrue, reason: 'lib/main.dart must exist');
      final content = mainFile.readAsStringSync();

      // Extract _home() method body
      final homeStartIndex = content.indexOf('Widget _home()');
      expect(homeStartIndex, greaterThan(0), reason: '_home() method must exist in main.dart');
      final homeEndIndex = content.indexOf('Widget _mode()', homeStartIndex);
      expect(homeEndIndex, greaterThan(homeStartIndex), reason: '_mode() should follow _home()');

      final homeCode = content.substring(homeStartIndex, homeEndIndex);
      final legacyFull = ['The', 'English', 'Barra', 'El', 'Salfa'].join(' ');
      final legacyCheck = ['barra', 'el', 'salfa'].join(' ');
      expect(homeCode.contains(legacyFull), isFalse);
      expect(homeCode.toLowerCase().contains(legacyCheck), isFalse);
    });
  });

  group('Challenger M1: Palette Conformance & Exact Hex Integrity (F5)', () {
    test('Exact hex values match Fraud Check design tokens', () {
      expect(bg.toARGB32(), equals(0xFF0A0D1B), reason: 'bg token mismatch');
      expect(card.toARGB32(), equals(0xFF151932), reason: 'card token mismatch');
      expect(card2.toARGB32(), equals(0xFF1E2448), reason: 'card2 token mismatch');
      expect(cardHi.toARGB32(), equals(0xFF1E2448), reason: 'cardHi token mismatch');
      expect(border.toARGB32(), equals(0xFF2C3466), reason: 'border token mismatch');
      expect(yellow.toARGB32(), equals(0xFFFFC837), reason: 'yellow token mismatch');
      expect(red.toARGB32(), equals(0xFFFF3B5C), reason: 'red token mismatch');
      expect(green.toARGB32(), equals(0xFF00E5A3), reason: 'green token mismatch');
      expect(blue.toARGB32(), equals(0xFF3A86FF), reason: 'blue token mismatch');
      expect(ink.toARGB32(), equals(0xFFF8FAFC), reason: 'ink token mismatch');
      expect(muted.toARGB32(), equals(0xFF94A3B8), reason: 'muted token mismatch');
      expect(purple.toARGB32(), equals(0xFF8B5CF6), reason: 'purple token mismatch');
    });

    test('All palette tokens are 100% opaque alpha', () {
      final palette = [bg, card, card2, cardHi, border, yellow, red, green, blue, ink, muted, purple];
      for (final color in palette) {
        final alpha = (color.toARGB32() >> 24) & 0xFF;
        expect(alpha, equals(255), reason: 'Color $color must be fully opaque');
      }
    });

    test('CardHi is an exact alias for card2 to ensure backwards-compatibility', () {
      expect(cardHi, equals(card2));
      expect(identical(cardHi, card2), isTrue);
    });

    testWidgets('MaterialApp ThemeData binds theme tokens correctly',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final theme = materialApp.theme!;

      expect(theme.scaffoldBackgroundColor, equals(bg));
      expect(theme.colorScheme.surface, equals(card));
      expect(theme.colorScheme.primary, equals(yellow));
      expect(theme.textTheme.bodyMedium?.color, equals(ink));
      expect(theme.textTheme.displayMedium?.color, equals(ink));
    });
  });

  group('Challenger M1: Logo Presentation & Visual Stack Integrity (F1, F2)', () {
    testWidgets('Logo displays cutout image with party glow halo and no ShaderMask',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Logo asset exists and is rendered
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      final assetImage = imageWidget.image as AssetImage;
      expect(assetImage.assetName, equals('assets/logo.png'));

      // Check no ShaderMask or clipping mask workaround
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(ClipOval), findsNothing);

      // Verify party glow BoxShadow container is present behind logo
      final containers = tester.widgetList<Container>(find.byType(Container));
      final glowContainer = containers.firstWhere(
        (c) {
          final dec = c.decoration as BoxDecoration?;
          return dec != null &&
              dec.shape == BoxShape.circle &&
              dec.boxShadow != null &&
              dec.boxShadow!.length == 2;
        },
        orElse: () => throw Exception('Party glow Container not found'),
      );

      final boxDecoration = glowContainer.decoration as BoxDecoration;
      expect(boxDecoration.boxShadow!.length, equals(2));
      // First shadow uses yellow glow
      expect(boxDecoration.boxShadow![0].color.toARGB32(), equals(yellow.withValues(alpha: 0.30).toARGB32()));
      // Second shadow uses blue glow
      expect(boxDecoration.boxShadow![1].color.toARGB32(), equals(blue.withValues(alpha: 0.20).toARGB32()));
    });

    testWidgets('FilmStripBackground mounts as root background behind transparent Scaffold',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilmStripBackground), findsOneWidget);

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffoldWidget = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffoldWidget.backgroundColor, equals(Colors.transparent));
    });
  });
}
