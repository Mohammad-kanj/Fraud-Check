import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  void setViewport(WidgetTester tester, {required double width, required double height}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void setDefaultScreen(WidgetTester tester) {
    setViewport(tester, width: 800, height: 2400);
  }

  /// Helper: Navigate from Home to Players setup screen at default size
  Future<void> navigateToPlayers(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    setDefaultScreen(tester);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Play
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    // Select mode
    await tester.tap(find.text(modeTitle));
    await tester.pump(const Duration(milliseconds: 100));

    // Select category
    await tester.tap(find.text(category));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper: Start round and land on Screen.pass
  Future<void> startRound(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
    int targetPlayerCount = 4,
  }) async {
    await navigateToPlayers(tester, modeTitle: modeTitle, category: category);

    // Adjust player count if needed
    final currentFields = find.byType(TextField).evaluate().length;
    if (targetPlayerCount > currentFields) {
      for (int i = 0; i < targetPlayerCount - currentFields; i++) {
        await tester.tap(find.text('Add player'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    } else if (targetPlayerCount < currentFields) {
      for (int i = 0; i < currentFields - targetPlayerCount; i++) {
        final removeButtons = find.byTooltip('Remove player');
        await tester.tap(removeButtons.last);
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper: Put app directly on Screen.reveal with exact role configuration
  Future<void> directSetupReveal(
    WidgetTester tester, {
    required double width,
    required double height,
    required String role, // 'safe', 'fraud', 'undercover'
    String playerName = 'Player 1',
  }) async {
    setViewport(tester, width: width, height: height);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    final dynamic state = tester.state(find.byType(GamePage));
    state.setState(() {
      state.players = [playerName, 'Player 2', 'Player 3', 'Player 4'];
      state.playerCount = 4;
      state.roundCat = 'Food';
      state.roundWord = 'Pizza';
      state.roundUndercoverWord = 'Burger';
      state.passOrder = [0, 1, 2, 3];
      state.passIdx = 0;
      state.revealed = true;
      state.screen = Screen.reveal;

      if (role == 'fraud') {
        state.fraudIndices = {0};
        state.undercoverIndex = null;
      } else if (role == 'undercover') {
        state.fraudIndices = {1};
        state.undercoverIndex = 0;
      } else {
        // safe
        state.fraudIndices = {1};
        state.undercoverIndex = null;
      }
    });
    await tester.pump();
  }

  // =========================================================================
  // GROUP 1: 3D PERSPECTIVE FLIP & MATRIX4 PERSPECTIVE ENTRY (F15 / R5)
  // =========================================================================
  group('F15 - 3D Perspective Card Flip & Matrix4 Perspective Entry', () {
    testWidgets('G1.1: Transform widget with Matrix4 entry (3,2)=0.001 exists on Screen.reveal at 0ms and 400ms',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      // On Screen.pass -> tap to reveal
      expect(find.text('Tap to reveal'), findsOneWidget);
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(); // pump 0ms

      // Dynamic check for GamePage state
      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('reveal'));

      // Check Transform widgets at pump 0ms
      var transforms = tester.widgetList<Transform>(find.byType(Transform));
      var perspectiveTransforms = transforms.where((t) {
        return (t.transform.entry(3, 2) - 0.001).abs() < 1e-6;
      }).toList();

      expect(
        perspectiveTransforms.isNotEmpty,
        isTrue,
        reason: 'Transform with Matrix4 perspective entry (3,2)=0.001 must exist at pump 0ms',
      );

      // Advance to pump 400ms (completed flip)
      await tester.pump(const Duration(milliseconds: 400));
      transforms = tester.widgetList<Transform>(find.byType(Transform));
      perspectiveTransforms = transforms.where((t) {
        return (t.transform.entry(3, 2) - 0.001).abs() < 1e-6;
      }).toList();

      expect(
        perspectiveTransforms.isNotEmpty,
        isTrue,
        reason: 'Transform with Matrix4 perspective entry (3,2)=0.001 must exist at pump 400ms',
      );
    });

    testWidgets('G1.2: Card flip animation transitions through 0ms (back card), 200ms (midpoint), and 400ms (front card)',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(); // 0ms

      // At 0ms: Back card is rendered with mystery badge
      expect(find.text('TOP SECRET • سري للغاية'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

      // At 200ms: Midpoint flip (value = 0.5 boundary)
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: 'Midpoint 200ms animation must not throw or crash');

      // At 400ms: Front card fully rendered, back card removed
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('TOP SECRET • سري للغاية'), findsNothing);
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
      expect(
        find.text('YOU ARE NOT THE FRAUD').evaluate().isNotEmpty ||
            find.text('YOU ARE THE FRAUD').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('G1.3: Animation restarts cleanly with ValueKey for subsequent players',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 3);

      final dynamic state = tester.state(find.byType(GamePage));
      final List<int> passOrder = (state.passOrder as List<int>);
      final List<String> players = (state.players as List<String>);

      for (int i = 0; i < passOrder.length; i++) {
        final activeName = players[passOrder[i]];

        // Tap to reveal
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(); // 0ms

        // Must display active player name on mystery card back at 0ms
        expect(find.text(activeName), findsOneWidget);
        expect(find.text('TOP SECRET • سري للغاية'), findsOneWidget);

        // Advance to 400ms
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('TOP SECRET • سري للغاية'), findsNothing);

        // Tap next
        final isLast = i == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  // =========================================================================
  // GROUP 2: MYSTERY BACK CARD VERIFICATION AT PUMP 0MS
  // =========================================================================
  group('F15 - Mystery Back Card at Pump 0ms', () {
    testWidgets('G2.1: Mystery card back renders exact typography, icon, and active player name at pump 0ms',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final List<int> passOrder = (state.passOrder as List<int>);
      final List<String> players = (state.players as List<String>);
      final firstPlayerName = players[passOrder[0]];

      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(); // 0ms

      // Verify mystery card back elements
      expect(find.text('TOP SECRET • سري للغاية'), findsOneWidget);
      expect(find.text(firstPlayerName), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
      expect(find.text('REVEALING ROLE...'), findsOneWidget);

      // Verify front card is hidden via Opacity = 0.0
      final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(
        opacities.any((o) => o.opacity == 0.0),
        isTrue,
        reason: 'Front card must have opacity 0.0 while back card is visible',
      );
    });
  });

  // =========================================================================
  // GROUP 3: ROLE WORDING AT PUMP 400MS
  // =========================================================================
  group('F15 - Role Reveal Wording (400ms)', () {
    testWidgets('G3.1: Classic Mode - Safe & Fraud roles render updated R6 banners',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 3);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<int> passOrder = (state.passOrder as List<int>);
      final String roundWord = (state.roundWord as String);

      bool sawSafe = false;
      bool sawFraud = false;

      for (int i = 0; i < passOrder.length; i++) {
        final playerIdx = passOrder[i];
        final isFraud = fraudIndices.contains(playerIdx);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        if (isFraud) {
          sawFraud = true;
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
          expect(find.textContaining('blend in'), findsOneWidget);
          expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
        } else {
          sawSafe = true;
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
          expect(find.text('YOUR SECRET WORD'), findsOneWidget);
          expect(find.text(roundWord), findsOneWidget);
          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
        }

        final isLast = i == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(sawSafe, isTrue, reason: 'Must test at least one safe player');
      expect(sawFraud, isTrue, reason: 'Must test at least one fraud player');
    });

    testWidgets('G3.2: Two Frauds Mode - Both frauds receive YOU ARE THE FRAUD and dual-fraud warning',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Two Frauds', category: 'Food', targetPlayerCount: 5);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<int> passOrder = (state.passOrder as List<int>);

      expect(fraudIndices.length, equals(2), reason: 'Two Frauds mode must designate exactly 2 frauds');

      int fraudCountObserved = 0;
      int safeCountObserved = 0;

      for (int i = 0; i < passOrder.length; i++) {
        final playerIdx = passOrder[i];
        final isFraud = fraudIndices.contains(playerIdx);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        if (isFraud) {
          fraudCountObserved++;
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
          expect(find.textContaining('There are 2 frauds this round!'), findsOneWidget);
          expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
        } else {
          safeCountObserved++;
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
        }

        final isLast = i == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fraudCountObserved, equals(2));
      expect(safeCountObserved, equals(3));
    });

    testWidgets('G3.3: Undercover Mode - Undercover player renders UNDERCOVER role banner and decoy word',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Undercover', category: 'Food', targetPlayerCount: 4);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final int undercoverIndex = (state.undercoverIndex as int);
      final List<int> passOrder = (state.passOrder as List<int>);
      final String undercoverWord = (state.roundUndercoverWord as String);

      bool sawUndercover = false;
      bool sawFraud = false;
      bool sawSafe = false;

      for (int i = 0; i < passOrder.length; i++) {
        final playerIdx = passOrder[i];
        final isFraud = fraudIndices.contains(playerIdx);
        final isUndercover = playerIdx == undercoverIndex;

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        if (isUndercover) {
          sawUndercover = true;
          expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
          expect(find.text('👁️ UNDERCOVER'), findsOneWidget);
          expect(find.text('YOUR DECOY WORD'), findsOneWidget);
          expect(find.text(undercoverWord), findsOneWidget);
          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
          expect(
            find.textContaining('Your word is slightly different'),
            findsOneWidget,
          );
        } else if (isFraud) {
          sawFraud = true;
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
          expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
        } else {
          sawSafe = true;
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
        }

        final isLast = i == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(sawUndercover, isTrue, reason: 'Undercover player must be tested');
      expect(sawFraud, isTrue, reason: 'Fraud player must be tested in Undercover mode');
      expect(sawSafe, isTrue, reason: 'Safe players must be tested in Undercover mode');
    });
  });

  // =========================================================================
  // GROUP 4: STRICT ABSENCE OF SEQUENCE COUNTER (\b\d+\s+of\s+\d+\b)
  // =========================================================================
  group('F15 - Zero Sequence Counters on Screen.reveal', () {
    final sequenceRegex = RegExp(r'\b\d+\s+of\s+\d+\b', caseSensitive: false);

    void assertNoSequenceCounterOnScreen(WidgetTester tester, {required String contextDesc}) {
      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final t in texts) {
        final content = t.data ?? t.textSpan?.toPlainText() ?? '';
        expect(
          sequenceRegex.hasMatch(content),
          isFalse,
          reason: '[$contextDesc] Sequence counter "$content" matching \\b\\d+\\s+of\\s+\\d+\\b leaked on Screen.reveal!',
        );
      }
      expect(find.textContaining(sequenceRegex), findsNothing);
    }

    testWidgets('G4.1: Classic Mode (3 players) - Zero sequence counters at 0ms and 400ms across all players',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 3);

      for (int i = 0; i < 3; i++) {
        // Tap reveal
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(); // 0ms
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Classic 3p - Player $i @ 0ms');

        await tester.pump(const Duration(milliseconds: 400)); // 400ms
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Classic 3p - Player $i @ 400ms');

        final nextBtn = (i == 2)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('G4.2: Two Frauds Mode (5 players) - Zero sequence counters across all reveals',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Two Frauds', category: 'Food', targetPlayerCount: 5);

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump();
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Two Frauds 5p - Player $i @ 0ms');

        await tester.pump(const Duration(milliseconds: 400));
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Two Frauds 5p - Player $i @ 400ms');

        final nextBtn = (i == 4)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('G4.3: Undercover Mode (4 players) - Zero sequence counters across all reveals',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Undercover', category: 'Food', targetPlayerCount: 4);

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump();
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Undercover 4p - Player $i @ 0ms');

        await tester.pump(const Duration(milliseconds: 400));
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Undercover 4p - Player $i @ 400ms');

        final nextBtn = (i == 3)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('G4.4: 8-Player Max Stress - Zero sequence counters across all 8 player reveals',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 8);

      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        assertNoSequenceCounterOnScreen(tester, contextDesc: 'Classic 8p - Player $i @ 400ms');

        final nextBtn = (i == 7)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  // =========================================================================
  // GROUP 5: MULTI-VIEWPORT ADAPTABILITY (320px to 768px) & ZERO OVERFLOW
  // =========================================================================
  group('F15 - Multi-Viewport Adaptability & Zero Overflow Errors on Screen.reveal', () {
    final viewports = [
      {'name': 'iPhone SE 1st gen (Narrow 320px)', 'width': 320.0, 'height': 568.0},
      {'name': 'Compact Android (360px)', 'width': 360.0, 'height': 640.0},
      {'name': 'iPhone SE 2nd gen (375px)', 'width': 375.0, 'height': 667.0},
      {'name': 'iPhone 13/14 (390px)', 'width': 390.0, 'height': 844.0},
      {'name': 'iPhone XR/Plus (414px)', 'width': 414.0, 'height': 896.0},
      {'name': 'Small Tablet (600px)', 'width': 600.0, 'height': 960.0},
      {'name': 'iPad Standard Portrait (768px)', 'width': 768.0, 'height': 1024.0},
    ];

    for (final vp in viewports) {
      testWidgets('G5: Zero overflow on Screen.reveal at viewport ${vp['name']} (Safe, Fraud, Undercover)',
          (WidgetTester tester) async {
        final w = vp['width'] as double;
        final h = vp['height'] as double;

        // Test 1: Safe role on reveal screen
        await directSetupReveal(tester, width: w, height: h, role: 'safe');
        expect(tester.takeException(), isNull, reason: 'Zero exceptions during setup at $w x $h');

        // At 0ms (back card)
        expect(find.text('TOP SECRET • سري للغاية'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero layout overflow at 0ms (back card) on $w x $h');

        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: 'Zero layout overflow at 400ms (Safe front card) on $w x $h');
        expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);

        // Test 2: Fraud role on reveal screen
        await directSetupReveal(tester, width: w, height: h, role: 'fraud');
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero layout overflow at 400ms (Fraud front card) on $w x $h');

        // Test 3: Undercover role on reveal screen
        await directSetupReveal(tester, width: w, height: h, role: 'undercover');
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero layout overflow at 400ms (Undercover front card) on $w x $h');
      });
    }

    testWidgets('G5.8: Screen.reveal live transition and interactive button tap across viewports',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 3);

      // Now on Screen.pass. Switch to narrow 320px viewport for reveal screen testing
      setViewport(tester, width: 320.0, height: 568.0);
      await tester.pump(const Duration(milliseconds: 50));

      final tapBtn = find.text('Tap to reveal');
      await tester.ensureVisible(tapBtn);
      await tester.tap(tapBtn);
      await tester.pump(); // 0ms back card
      expect(tester.takeException(), isNull);
      expect(find.text('TOP SECRET • سري للغاية'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400)); // 400ms front card
      expect(tester.takeException(), isNull);

      final hideBtn = find.text('Hide and pass on');
      expect(hideBtn, findsOneWidget);
      await tester.tap(hideBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('G5.9: Long player name (30 characters) on 320px viewport renders cleanly on back card and front card',
        (WidgetTester tester) async {
      const longName = 'Maximilian Alexander III Super';
      await directSetupReveal(tester, width: 320.0, height: 568.0, role: 'safe', playerName: longName);

      // 0ms Back card
      expect(find.text(longName), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Long player name must not overflow back card on 320px');

      // 400ms Front card
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'Long player name must not cause overflow on front card on 320px');
    });
  });

  // =========================================================================
  // GROUP 6: ADVERSARIAL TIMING & STABILITY STRESS TESTS
  // =========================================================================
  group('F15 - Adversarial Timing & Card State Stability', () {
    testWidgets('G6.1: Extended pump past 400ms (1000ms, 2000ms) preserves stable card state',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400));

      // Over-pumping
      await tester.pump(const Duration(milliseconds: 600)); // total 1000ms
      await tester.pump(const Duration(milliseconds: 1000)); // total 2000ms

      expect(tester.takeException(), isNull);
      expect(
        find.text('YOU ARE NOT THE FRAUD').evaluate().isNotEmpty ||
            find.text('YOU ARE THE FRAUD').evaluate().isNotEmpty,
        isTrue,
        reason: 'Front card must remain stably rendered after extended duration',
      );
    });

    testWidgets('G6.2: Final player action button renders "Hide and start discussion" transitioning directly to Screen.discuss',
        (WidgetTester tester) async {
      setDefaultScreen(tester);
      await startRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayerCount: 3);

      for (int i = 0; i < 2; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Hide and pass on'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Final (3rd) player
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400));

      final finalBtn = find.text('Hide and start discussion');
      expect(finalBtn, findsOneWidget);
      await tester.tap(finalBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));
      expect(find.text('Discuss!'), findsOneWidget);
    });
  });
}
