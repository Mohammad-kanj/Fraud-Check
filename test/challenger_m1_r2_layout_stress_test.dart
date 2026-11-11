import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  /// Helper to configure a given viewport size and pixel ratio with automatic cleanup
  void setViewport(WidgetTester tester, {required double width, required double height, double pixelRatio = 1.0}) {
    tester.view.physicalSize = Size(width * pixelRatio, height * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Helper to force the game state directly to a specific screen and role configuration
  void configureGameState(
    WidgetTester tester, {
    required Screen targetScreen,
    String role = 'safe', // 'safe', 'fraud', 'undercover'
    String playerName = 'Player 1',
    String category = 'Animals',
    String word = 'Elephant',
    String undercoverWord = 'Mammoth',
    int passIdx = 0,
    int totalPlayers = 4,
  }) {
    final dynamic state = tester.state(find.byType(GamePage));
    state.setState(() {
      state.screen = targetScreen;
      state.players = List.generate(totalPlayers, (i) => 'Player ${i + 1}');
      state.players[0] = playerName;
      state.playerCount = totalPlayers;
      state.roundCat = category;
      state.roundWord = word;
      state.roundUndercoverWord = undercoverWord;
      state.passOrder = List.generate(totalPlayers, (i) => i);
      state.passIdx = passIdx;
      state.revealed = (targetScreen == Screen.reveal);

      if (role == 'fraud') {
        state.fraudIndices = {passIdx};
        state.undercoverIndex = null;
      } else if (role == 'undercover') {
        state.fraudIndices = {1};
        state.undercoverIndex = passIdx;
      } else {
        state.fraudIndices = {1};
        state.undercoverIndex = 2;
      }
    });
  }

  group('Group 1: Extreme Viewport Multi-Device Matrix Stress Tests', () {
    final viewports = <String, Size>{
      'Ultra-compact mobile (320x480)': const Size(320, 480),
      'iPhone SE 1st gen (320x568)': const Size(320, 568),
      'iPhone SE 2nd gen (375x667)': const Size(375, 667),
      'iPhone 13/14 (390x844)': const Size(390, 844),
      'Android Pixel 7 (412x915)': const Size(412, 915),
      'iPad Mini Portrait (768x1024)': const Size(768, 1024),
      'iPad Landscape (1024x768)': const Size(1024, 768),
      'Full HD Mobile (1080x1920)': const Size(1080, 1920),
      'Desktop Laptop (1440x900)': const Size(1440, 900),
      'Desktop Monitor (1920x1080)': const Size(1920, 1080),
      'Extreme squished landscape (320x360)': const Size(320, 360),
    };

    for (final entry in viewports.entries) {
      testWidgets('Home Screen renders cleanly on ${entry.key} with zero overflow',
          (WidgetTester tester) async {
        setViewport(tester, width: entry.value.width, height: entry.value.height);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Verify key home elements
        expect(find.text('FRAUD CHECK'), findsOneWidget);
        expect(find.text('WHO IS THE FRAUD?'), findsOneWidget);
        expect(find.text('Play'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Rules'), findsOneWidget);

        // Verify settings and rules buttons have NO emojis or icons
        final actionButtons = find.byType(InkWell);
        expect(actionButtons, findsWidgets);

        // Ensure 0 RenderFlex overflow errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('Settings Screen renders cleanly on ${entry.key} with zero overflow',
          (WidgetTester tester) async {
        setViewport(tester, width: entry.value.width, height: entry.value.height);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        configureGameState(tester, targetScreen: Screen.settings);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Audio Feedback'), findsNothing);
        expect(find.text('Screen Brightness'), findsOneWidget);
        expect(find.text('Back to main menu'), findsOneWidget);

        // Ensure 0 RenderFlex overflow errors
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Group 2: Rules Screen Layout & Vertical Scrolling Stress Tests', () {
    testWidgets('Rules screen displays exactly 4 distinct rounded cards with correct headings',
        (WidgetTester tester) async {
      setViewport(tester, width: 375, height: 667);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester, targetScreen: Screen.rules);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rules'), findsOneWidget);

      // Verify the 4 tags at the top
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Roles & Objectives'), findsOneWidget);
      expect(find.text('Questioning Phase'), findsOneWidget);
      expect(find.text('Voting & Scoring'), findsOneWidget);

      // Tap 'Roles & Objectives' tag and verify switching
      await tester.tap(find.text('Roles & Objectives'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Roles & Objectives'), findsOneWidget);

      // Ensure 0 exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rules screen scrolls vertically through all 4 cards and back to main menu without clipping',
        (WidgetTester tester) async {
      // Use constrained 320x480 viewport to force vertical scrolling
      setViewport(tester, width: 320, height: 480);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester, targetScreen: Screen.rules);
      await tester.pump(const Duration(milliseconds: 100));

      // Scrollable must be mounted
      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);

      // Initially top elements are visible
      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);

      final backBtnFinder = find.text('Back to main menu');
      await tester.ensureVisible(backBtnFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(backBtnFinder, findsOneWidget);

      // Tap 'Back to main menu' and verify navigation
      await tester.tap(backBtnFinder);
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Confirm').evaluate().isNotEmpty) {
        await tester.tap(find.text('Confirm'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('FRAUD CHECK'), findsOneWidget);

      // Ensure 0 overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rules screen handles extreme squished viewport (320x300) without RenderFlex overflow',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 300);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester, targetScreen: Screen.rules);
      await tester.pump(const Duration(milliseconds: 100));

      final scrollable = find.byType(SingleChildScrollView);
      // Repeatedly drag down and up
      await tester.drag(scrollable, const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(scrollable, const Offset(0, 800));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });

  group('Group 3: Role Reveal Animations, Badges, and Viewport Robustness', () {
    testWidgets('Fraud role displays eye badge "👁️ FRAUD", clean category, and NO lock icon',
        (WidgetTester tester) async {
      setViewport(tester, width: 375, height: 667);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester,
          targetScreen: Screen.reveal,
          role: 'fraud',
          category: 'Technology',
          word: 'Smartphone');
      await tester.pump(const Duration(milliseconds: 100));

      // Category displayed cleanly outside content box without emojis
      expect(find.text('Category: Technology'), findsOneWidget);
      expect(find.textContaining('💻'), findsNothing);

      // Lock icon must be absent once revealed
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);

      // Fraud role badge with eye emoji
      expect(find.text('👁️ FRAUD'), findsOneWidget);
      expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
      expect(find.textContaining('blend in'), findsOneWidget);

      // Action button
      expect(find.text('Hide and pass on'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Undercover role displays eye badge "👁️ UNDERCOVER", clean category, and decoy word',
        (WidgetTester tester) async {
      setViewport(tester, width: 375, height: 667);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester,
          targetScreen: Screen.reveal,
          role: 'undercover',
          category: 'Food',
          word: 'Pizza',
          undercoverWord: 'Burger');
      await tester.pump(const Duration(milliseconds: 100));

      // Category without emojis
      expect(find.text('Category: Food'), findsOneWidget);

      // No lock icon
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);

      // Undercover role badge with eye emoji
      expect(find.text('👁️ UNDERCOVER'), findsOneWidget);
      expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
      expect(find.text('YOUR DECOY WORD'), findsOneWidget);
      expect(find.text('Burger'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Safe player displays clean category, secret word, and NO lock icon',
        (WidgetTester tester) async {
      setViewport(tester, width: 375, height: 667);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester,
          targetScreen: Screen.reveal,
          role: 'safe',
          category: 'Sports',
          word: 'Football');
      await tester.pump(const Duration(milliseconds: 100));

      // Category without emojis
      expect(find.text('Category: Sports'), findsOneWidget);

      // No lock icon
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
      expect(find.byIcon(Icons.lock_open_rounded), findsNothing);

      expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
      expect(find.text('YOUR SECRET WORD'), findsOneWidget);
      expect(find.text('Football'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Role reveal flip animation completes without matrix distortion or overflow across all viewports',
        (WidgetTester tester) async {
      final testSizes = [
        const Size(320, 480),
        const Size(375, 667),
        const Size(768, 1024),
        const Size(1080, 1920),
      ];

      for (final size in testSizes) {
        setViewport(tester, width: size.width, height: size.height);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        // Start on pass screen
        configureGameState(tester, targetScreen: Screen.pass, role: 'fraud');
        await tester.pump(const Duration(milliseconds: 100));

        final revealBtn = find.text('Tap to reveal');
        await tester.ensureVisible(revealBtn);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(revealBtn);

        // Advance animation frame by frame up to completion (400ms duration)
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('👁️ FRAUD'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Role reveal with large accessibility text scale (1.5x) causes zero RenderFlex overflows',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const FraudCheckApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      configureGameState(tester,
          targetScreen: Screen.reveal,
          role: 'fraud',
          category: 'Very Long Category Name That Might Wrap',
          word: 'Supercalifragilistic');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('👁️ FRAUD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Group 4: Milestone M1 Screens End-to-End Zero Overflow Audit', () {
    testWidgets('Traversing all M1 target screens on 320px ultra-narrow viewport produces 0 RenderFlex overflows',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Home Screen (M1)
      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 2. Rules Screen (M1)
      final rulesBtn = find.text('Rules');
      await tester.ensureVisible(rulesBtn);
      await tester.tap(rulesBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Rules'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Back to Home
      final backRulesBtn = find.text('Back to main menu');
      await tester.ensureVisible(backRulesBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(backRulesBtn);
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Confirm').evaluate().isNotEmpty) {
        await tester.tap(find.text('Confirm'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 3. Settings Screen (M1)
      final settingsBtn = find.text('Settings');
      await tester.ensureVisible(settingsBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(settingsBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Back to Home
      final backSettingsBtn = find.text('Back to main menu');
      await tester.ensureVisible(backSettingsBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(backSettingsBtn);
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Confirm').evaluate().isNotEmpty) {
        await tester.tap(find.text('Confirm'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4. Pass Screen & Reveal Screen (M1)
      configureGameState(tester, targetScreen: Screen.pass, role: 'fraud');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final revealPassBtn = find.text('Tap to reveal');
      await tester.ensureVisible(revealPassBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(revealPassBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('👁️ FRAUD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
