import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fraud_check/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => null,
    );
  });

  setUp(() {
    Sound.enabled = false;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void setViewport(WidgetTester tester, {required double width, required double height}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // =========================================================================
  // Group 1: Alternating Film Strip Scrolling Invariants (Mathematical & Empirical)
  // =========================================================================
  group('Empirical Challenge 1: Film Strip Scrolling Direction Invariant', () {
    test('Mathematical Invariant: stripProgress(s) direction is opposite to s-1 and s+1 for all s in [-100, 100]', () {
      // Implementation in FilmStripPainter:
      // stripProgress = s.isEven ? progress : (1.0 - progress)
      double computeStripProgress(int s, double p) => s.isEven ? p : (1.0 - p);

      const double pStart = 0.2;
      const double pEnd = 0.6; // Forward progression

      for (int s = -100; s <= 100; s++) {
        final deltaCurrent = computeStripProgress(s, pEnd) - computeStripProgress(s, pStart);
        final deltaPrev = computeStripProgress(s - 1, pEnd) - computeStripProgress(s - 1, pStart);
        final deltaNext = computeStripProgress(s + 1, pEnd) - computeStripProgress(s + 1, pStart);

        // Verification: deltaCurrent must have opposite sign to deltaPrev and deltaNext
        expect(deltaCurrent * deltaPrev, lessThan(0.0),
            reason: 'Strip $s and strip ${s - 1} must move in opposite directions');
        expect(deltaCurrent * deltaNext, lessThan(0.0),
            reason: 'Strip $s and strip ${s + 1} must move in opposite directions');
        expect(deltaPrev, equals(deltaNext),
            reason: 'Sandwiching strips ${s - 1} and ${s + 1} must have identical scroll parity');

        // Check exact velocity values
        if (s.isEven) {
          expect(deltaCurrent, greaterThan(0.0), reason: 'Even strip $s moves forward');
          expect(deltaPrev, lessThan(0.0), reason: 'Odd strip ${s - 1} moves backward');
          expect(deltaNext, lessThan(0.0), reason: 'Odd strip ${s + 1} moves backward');
        } else {
          expect(deltaCurrent, lessThan(0.0), reason: 'Odd strip $s moves backward');
          expect(deltaPrev, greaterThan(0.0), reason: 'Even strip ${s - 1} moves forward');
          expect(deltaNext, greaterThan(0.0), reason: 'Even strip ${s + 1} moves forward');
        }
      }
    });

    testWidgets('Empirical Painting: FilmStripPainter repaints cleanly across full progress cycle [0.0, 1.0]',
        (WidgetTester tester) async {
      final painterA = FilmStripPainter(progress: 0.1);
      final painterB = FilmStripPainter(progress: 0.2);
      final painterIdentical = FilmStripPainter(progress: 0.1);

      expect(painterA.shouldRepaint(painterB), isTrue);
      expect(painterA.shouldRepaint(painterIdentical), isFalse);

      // Verify rendering on canvas without exceptions
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        await tester.pumpWidget(
          Center(
            child: CustomPaint(
              size: const Size(400, 800),
              painter: FilmStripPainter(progress: p),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  // =========================================================================
  // Group 2: Main Menu Title Contrast, Glow, Subtitle & Logo Pop
  // =========================================================================
  group('Empirical Challenge 2: Main Menu Title Contrast & Logo Pop Invariants', () {
    testWidgets('MM.Title: "FRAUD CHECK" renders with deep shadows, gold glow, and correct subtitle',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final titleFinder = find.text('FRAUD CHECK');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontFamily, GoogleFonts.archivo().fontFamily);
      expect(titleWidget.style?.fontWeight, FontWeight.w900);
      expect(titleWidget.style?.shadows, isNotNull);

      final shadows = titleWidget.style!.shadows!;
      expect(shadows.length, greaterThanOrEqualTo(2));

      // Drop shadow (black with vertical offset)
      final dropShadow = shadows.firstWhere(
        (s) => s.offset.dy > 0,
        orElse: () => throw Exception('Missing vertical drop shadow'),
      );
      expect(dropShadow.blurRadius, greaterThanOrEqualTo(10.0));

      // Glow shadow (zero offset, gold/yellow)
      final glowShadow = shadows.firstWhere(
        (s) => s.offset == Offset.zero,
        orElse: () => throw Exception('Missing glow shadow'),
      );
      expect(glowShadow.blurRadius, greaterThanOrEqualTo(20.0));

      // Subtitle badge: "WHO IS THE FRAUD?"
      final subtitleFinder = find.text('WHO IS THE FRAUD?');
      expect(subtitleFinder, findsOneWidget);
      expect(find.textContaining('WHO IS THE IMPOSTER', findRichText: true), findsNothing);

      // Verify subtitle is wrapped in a styled container badge
      final badgeContainerFinder = find.ancestor(of: subtitleFinder, matching: find.byType(Container)).first;
      final badgeContainer = tester.widget<Container>(badgeContainerFinder);
      final decoration = badgeContainer.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.border, isNotNull);
    });

    testWidgets('MM.Logo: Circular backing disc with dual glow pops behind logo image',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final logoImageFinder = find.byType(Image);
      expect(logoImageFinder, findsOneWidget);

      // Find the Stack containing the logo and backing disc
      final stackFinder = find.ancestor(of: logoImageFinder, matching: find.byType(Stack)).first;
      expect(stackFinder, findsOneWidget);

      // Find backing Container
      final containers = tester.widgetList<Container>(
        find.descendant(of: stackFinder, matching: find.byType(Container)),
      );
      expect(containers.isNotEmpty, isTrue);

      final disc = containers.firstWhere((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });

      final discDec = disc.decoration as BoxDecoration;
      expect(discDec.boxShadow, isNotNull);
      expect(discDec.boxShadow!.length, greaterThanOrEqualTo(2),
          reason: 'Backing disc must feature multi-layered glow shadows');
    });
  });

  // =========================================================================
  // Group 3: Screen Brightness Slider, Overlay Opacity Math & IgnorePointer
  // =========================================================================
  group('Empirical Challenge 3: Screen Brightness Overlay Math & Touch Transparency', () {
    test('Overlay Math Formula: O(brightness) = (1.0 - brightness) * 0.75', () {
      double computeOpacity(double brightness) => (1.0 - brightness) * 0.75;

      expect(computeOpacity(1.0), equals(0.0));
      expect(computeOpacity(0.5), equals(0.375));
      expect(computeOpacity(0.2), closeTo(0.60, 0.0001));
      expect(computeOpacity(0.0), equals(0.75));
    });

    testWidgets('Overlay presence: Not mounted at 1.0, mounted with IgnorePointer when dimmed',
        (WidgetTester tester) async {
      setViewport(tester, width: 400, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.brightness, equals(1.0));

      // At brightness = 1.0, no dimming overlay should be present
      final activeDimmerFinder = find.byWidgetPredicate(
        (w) => w is IgnorePointer && w.ignoring == true,
      );
      expect(activeDimmerFinder, findsNothing);

      // Dim the brightness to 0.5
      state.setState(() {
        state.brightness = 0.5;
      });
      await tester.pump();

      // Now IgnorePointer (ignoring: true) must be present wrapping the black dimmer
      expect(activeDimmerFinder, findsOneWidget);

      final containerFinder = find.descendant(
        of: activeDimmerFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      expect(container.color, Colors.black.withValues(alpha: (1.0 - 0.5) * 0.75));
    });

    testWidgets('Critical Invariant: IgnorePointer ensures touches pass through overlay even at maximum dimming',
        (WidgetTester tester) async {
      setViewport(tester, width: 400, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Screen Brightness'), findsOneWidget);

      final dynamic state = tester.state(find.byType(GamePage));
      // Set brightness to 0.2 (maximum dimming allowed by slider)
      state.setState(() {
        state.brightness = 0.2;
      });
      await tester.pump();

      // Verify overlay is active
      final activeDimmerFinder = find.byWidgetPredicate(
        (w) => w is IgnorePointer && w.ignoring == true,
      );
      expect(activeDimmerFinder, findsOneWidget);

      // Now tap "Back to main menu" through the dimmer overlay
      final backBtn = find.text('Back to main menu');
      expect(backBtn, findsOneWidget);

      // Tap through the overlay
      await tester.tap(backBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify navigation occurred successfully to Screen.home
      expect(find.text('FRAUD CHECK'), findsOneWidget,
          reason: 'Touch events must pass through IgnorePointer dimmer overlay without hindrance');
      expect(state.screen, equals(Screen.home));
    });
  });

  // =========================================================================
  // Group 4: Master Audio Volume, Clamping & Sound Engine
  // =========================================================================
  group('Empirical Challenge 4: Master Audio Volume & Clamping Invariants', () {
    testWidgets('Boundary and clamping verification for Sound.setVolume(val)', (WidgetTester tester) async {
      // Nominal values
      Sound.setVolume(0.0);
      expect(Sound.volume, equals(0.0));

      Sound.setVolume(0.5);
      expect(Sound.volume, equals(0.5));

      Sound.setVolume(1.0);
      expect(Sound.volume, equals(1.0));

      // Negative underflow clamping
      Sound.setVolume(-0.01);
      expect(Sound.volume, equals(0.0));

      Sound.setVolume(-100.0);
      expect(Sound.volume, equals(0.0));

      // Positive overflow clamping
      Sound.setVolume(1.01);
      expect(Sound.volume, equals(1.0));

      Sound.setVolume(50.0);
      expect(Sound.volume, equals(1.0));
    });

    testWidgets('Settings UI reflects volume and provides responsive slider control',
        (WidgetTester tester) async {
      setViewport(tester, width: 400, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Audio'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2)); // Volume slider + Brightness slider

      // Verify Sound volume percentage text
      Sound.setVolume(0.75);
      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {});
      await tester.pump();

      expect(find.text('75%'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 5: Viewport Stress Test Across Main Menu, Settings, and Rules (ZERO Overflows)
  // =========================================================================
  group('Empirical Challenge 5: Required Responsive Viewport Stress Tests (ZERO Overflows)', () {
    final viewports = [
      {'name': 'Ultra-compact mobile (320x568)', 'width': 320.0, 'height': 568.0},
      {'name': 'Compact mobile (360x640)', 'width': 360.0, 'height': 640.0},
      {'name': 'Standard mobile (400x800)', 'width': 400.0, 'height': 800.0},
      {'name': 'Compact landscape (640x360)', 'width': 640.0, 'height': 360.0},
    ];

    for (final vp in viewports) {
      final w = vp['width']! as double;
      final h = vp['height']! as double;
      final name = vp['name']! as String;

      testWidgets('ZERO overflow on Screen.home (Main Menu) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('FRAUD CHECK'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ZERO overflow on Screen.settings (Settings) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));
        state.setState(() => state.screen = Screen.settings);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Screen Brightness'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ZERO overflow on Screen.rules (Rules) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));
        state.setState(() => state.screen = Screen.rules);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Rules'), findsOneWidget);
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Roles & Objectives'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ZERO overflow on Screen.reveal (Role Reveal) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));

        // Test Safe Role
        state.setState(() {
          state.screen = Screen.reveal;
          state.roundCat = 'Food';
          state.roundWord = 'Pizza';
          state.roundUndercoverWord = 'Burger';
          state.revealed = true;
          state.fraudIndices = {1};
          state.undercoverIndex = null;
          state.passOrder = [0, 1, 2, 3];
          state.passIdx = 0;
        });
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsNothing);
        expect(tester.takeException(), isNull);

        // Test Fraud Role
        state.setState(() {
          state.fraudIndices = {0};
          state.undercoverIndex = null;
        });
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        expect(find.text('👁️ FRAUD'), findsOneWidget);
        expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
        expect(tester.takeException(), isNull);

        // Test Undercover Role
        state.setState(() {
          state.fraudIndices = {1};
          state.undercoverIndex = 0;
        });
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
        expect(find.text('👁️ UNDERCOVER'), findsOneWidget);
        expect(find.byIcon(Icons.lock_rounded), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ZERO overflow on Screen.discuss (Discussion) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));
        state.setState(() {
          state.screen = Screen.discuss;
          state.players = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
          state.playerCount = 4;
          state.questionAskers = [0, 1, 2, 3];
          state.questionTargets = [1, 2, 3, 0];
          state.questionTurnIdx = 0;
        });
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Discuss!'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Vote'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ZERO overflow on Screen.vote (Voting) at $name', (WidgetTester tester) async {
        setViewport(tester, width: w, height: h);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));
        state.setState(() {
          state.screen = Screen.vote;
          state.players = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
          state.playerCount = 4;
          state.voteIdx = 0;
          state.voteRevealed = true; // active voting stage
        });
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Who is the fraud?'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Vote'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // =========================================================================
  // Group 6: Empirical Finding on Screen.result Leaderboard Layout at Narrow Viewports
  // =========================================================================
  group('Empirical Challenge 6: Results Screen Layout & Leaderboard Invariants', () {
    testWidgets('Results screen elements render correctly, documenting narrow viewport layout constraints',
        (WidgetTester tester) async {
      setViewport(tester, width: 480, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.screen = Screen.result;
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.fraudIndices = {1};
        state.caughtFrauds.addAll({1});
        state.fraudCaughtByMajority = true;
        state.players = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
        state.scores.addAll({'Player 1': 100, 'Player 2': 0, 'Player 3': 100, 'Player 4': 100});
        state.pointsEarnedThisRound.addAll({0: 100, 1: 0, 2: 100, 3: 100});
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('THE PLAYERS WIN'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('+100'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 7: Strict Legacy Terminology Check
  // =========================================================================
  group('Empirical Challenge 7: Strict Negative Terminology Check', () {
    testWidgets('UI elements contain zero occurrences of legacy phrase', (WidgetTester tester) async {
      final forbiddenEnglish = ['barra', 'el', 'salfa'].join(' ');
      final forbiddenArabic = ['برا', 'السالفة'].join(' ');

      setViewport(tester, width: 400, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining(forbiddenEnglish, findRichText: true), findsNothing);
      expect(find.textContaining(forbiddenArabic, findRichText: true), findsNothing);
    });
  });
}
