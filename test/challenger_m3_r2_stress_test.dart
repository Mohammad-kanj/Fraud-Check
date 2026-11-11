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
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  /// Helper: Navigate from Home through mode and category setup at default screen size,
  /// then land on Screen.pass
  Future<void> setupAndStartRound(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
    int playerCount = 4,
    List<String>? customNames,
  }) async {
    setDefaultScreen(tester);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Play
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    // Mode
    await tester.tap(find.text(modeTitle));
    await tester.pump(const Duration(milliseconds: 100));

    // Category
    await tester.tap(find.text(category));
    await tester.pump(const Duration(milliseconds: 100));

    // Set player count
    while (tester.widgetList(find.byType(TextField)).length < playerCount) {
      await tester.tap(find.text('Add player'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.widgetList(find.byType(TextField)).length > playerCount) {
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
    }

    if (customNames != null) {
      final fields = find.byType(TextField);
      for (int i = 0; i < customNames.length && i < playerCount; i++) {
        await tester.enterText(fields.at(i), customNames[i]);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Start round -> Lands on Screen.pass
    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper to pass through all player reveals to land on Screen.discuss
  Future<void> passThroughAllReveals(WidgetTester tester, int playerCount) async {
    for (int p = 0; p < playerCount; p++) {
      expect(find.text('Pass the phone'), findsOneWidget);
      final revealBtn = find.text('Tap to reveal');
      await tester.ensureVisible(revealBtn);
      await tester.tap(revealBtn);
      await tester.pump(const Duration(milliseconds: 400));

      final isLast = p == playerCount - 1;
      final btnText = isLast ? 'Hide and start discussion' : 'Hide and pass on';
      final nextBtn = find.text(btnText);
      expect(nextBtn, findsOneWidget);
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // =========================================================================
  // GROUP 1: EMPIRICAL VERIFICATION OF NARROW VIEWPORTS ON SCREEN.DISCUSS & SCREEN.REVEAL
  // =========================================================================
  group('Challenger M3 R2: Narrow Viewports Zero Overflow Stress', () {
    testWidgets('ST.1.1: Screen.discuss on iPhone SE 1st Gen (320x568) across all question turns',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, playerCount: 4);
      await passThroughAllReveals(tester, 4);

      // Switch to narrow viewport 320x568 for Screen.discuss testing
      setViewport(tester, width: 320.0, height: 568.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Check Turn 1
      expect(tester.takeException(), isNull,
          reason: 'Zero layout overflow on Turn 1 on 320x568');

      // Advance to Turn 2
      final nextBtn = find.text('Next question');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Zero layout overflow on Turn 2 on 320x568');

      // Advance to Turn 3
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Zero layout overflow on Turn 3 on 320x568');

      // Advance to Turn 4
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Zero layout overflow on Turn 4 on 320x568');
    });

    testWidgets('ST.1.2: Screen.discuss on Compact Android (360x640) across all question turns',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, playerCount: 5);
      await passThroughAllReveals(tester, 5);

      setViewport(tester, width: 360.0, height: 640.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      for (int i = 1; i <= 5; i++) {
        expect(tester.takeException(), isNull,
            reason: 'Zero layout overflow on Turn $i on 360x640');

        if (i < 5) {
          final nextBtn = find.text('Next question');
          await tester.ensureVisible(nextBtn);
          await tester.tap(nextBtn);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('ST.1.3: Screen.reveal front card Category badge zero overflow on 320px and 360px',
        (WidgetTester tester) async {
      final viewports = [
        const Size(320.0, 568.0),
        const Size(360.0, 640.0),
        const Size(375.0, 667.0),
      ];

      for (final vp in viewports) {
        await setupAndStartRound(tester, playerCount: 3, category: 'Food');

        // Switch to test viewport on Screen.pass
        setViewport(tester, width: vp.width, height: vp.height);
        await tester.pump(const Duration(milliseconds: 50));

        // Tap to reveal -> Back card
        final revealBtn = find.text('Tap to reveal');
        await tester.ensureVisible(revealBtn);
        await tester.tap(revealBtn);
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Zero overflow on back card at ${vp.width}x${vp.height}');

        // Flip to Front card (400ms)
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull,
            reason: 'Zero overflow on front card Category badge at ${vp.width}x${vp.height}');
        expect(find.textContaining('Category: Food'), findsOneWidget);

        // Reset for next viewport
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  // =========================================================================
  // GROUP 2: UNICODE, EMOJI, AND LONG STRINGS STRESS
  // =========================================================================
  group('Challenger M3 R2: Unicode, Emoji & Long Player Names Stress', () {
    testWidgets('ST.2.1: 30-character and Arabic/Emoji player names on Screen.discuss at 320px viewport',
        (WidgetTester tester) async {
      final extremeNames = [
        'MaximilianAlexanderTheThirdSuper',
        'محمد بن عبدالعزيز آل سعود 👑',
        'Princess_Anastasia_Star_⭐',
        'خالد_المحارب_السري_الذكي_🔥',
      ];

      await setupAndStartRound(
        tester,
        playerCount: 4,
        customNames: extremeNames,
      );
      await passThroughAllReveals(tester, 4);

      setViewport(tester, width: 320.0, height: 568.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Check Asker and Responder cards with long names on 320px width
      expect(tester.takeException(), isNull,
          reason: 'Long unicode names must not cause RenderFlex overflow on Screen.discuss at 320px');

      // Verify names render
      final askerIdx = (state.questionAskers as List<int>)[0];
      final targetIdx = (state.questionTargets as List<int>)[0];
      expect(find.textContaining(extremeNames[askerIdx]), findsWidgets);
      expect(find.textContaining(extremeNames[targetIdx]), findsWidgets);

      // Cycle through turns
      for (int i = 0; i < 3; i++) {
        final nextBtn = find.text('Next question');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'Turn ${i + 2} must not overflow with long unicode names at 320px');
      }
    });

    testWidgets('ST.2.2: Extreme names on Screen.reveal card back & front at 320px viewport',
        (WidgetTester tester) async {
      const arabicLongName = 'عبدالله بن فهد المنصور القحطاني 🕵️‍♂️';

      await setupAndStartRound(
        tester,
        playerCount: 3,
        customNames: [arabicLongName, 'سارة بنت فيصل الشمري 🌟', 'محمد عبدالرحمن خالد ⚡'],
      );

      setViewport(tester, width: 320.0, height: 568.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      final activePlayerName = (state.players as List<String>)[(state.passOrder as List<int>)[state.passIdx as int]];

      // Player reveal
      final revealBtn = find.text('Tap to reveal');
      await tester.ensureVisible(revealBtn);
      await tester.tap(revealBtn);
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'Arabic emoji name on reveal back card must not overflow at 320px');
      expect(find.text(activePlayerName), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull,
          reason: 'Arabic emoji name on reveal front card must not overflow at 320px');
      expect(find.textContaining('YOU ARE'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: RAPID TRANSITIONS & STATE STABILITY HARNESS
  // =========================================================================
  group('Challenger M3 R2: Rapid Transitions & State Stability', () {
    testWidgets('ST.3.1: Rapid-fire Next question taps advance infinite questioning without overflow or crash',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, playerCount: 5);
      await passThroughAllReveals(tester, 5);

      setViewport(tester, width: 360.0, height: 640.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.questionTurnIdx, equals(0));

      // Rapidly tap "Next question" 10 times
      for (int i = 0; i < 10; i++) {
        final nextFinder = find.text('Next question');
        if (nextFinder.evaluate().isNotEmpty) {
          await tester.ensureVisible(nextFinder);
          await tester.tap(nextFinder);
          await tester.pump(const Duration(milliseconds: 10));
          if (find.text('Another round').evaluate().isNotEmpty) {
            await tester.tap(find.text('Another round'));
            await tester.pump(const Duration(milliseconds: 10));
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 100));

      // With infinite questioning, questionTurnIdx advances smoothly without throwing
      expect(state.questionTurnIdx, greaterThanOrEqualTo(5));
      expect(tester.takeException(), isNull);

      // Verify "Previous question" button is removed per R4.3
      expect(find.text('Previous question'), findsNothing);

      // Verify voting transition remains healthy
      final voteFinder = find.text('Vote');
      await tester.ensureVisible(voteFinder);
      await tester.tap(voteFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ST.3.2: Adversarial out-of-bounds questionTurnIdx injection does not crash UI',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, playerCount: 4);
      await passThroughAllReveals(tester, 4);

      setViewport(tester, width: 360.0, height: 640.0);
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));

      // Inject wildly negative questionTurnIdx
      state.setState(() {
        state.questionTurnIdx = -99;
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Negative questionTurnIdx must be defensively clamped');

      // Inject wildly large questionTurnIdx
      state.setState(() {
        state.questionTurnIdx = 999;
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Excessive questionTurnIdx must be defensively clamped');
    });
  });

  // =========================================================================
  // GROUP 4: MULTI-ROUND PLAYTHROUGH & STATE RESET ISOLATION
  // =========================================================================
  group('Challenger M3 R2: Multi-Round State Reset Isolation', () {
    testWidgets('ST.4.1: Three consecutive full rounds correctly reset questioning state each round',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, playerCount: 4, category: 'Food');

      for (int round = 1; round <= 3; round++) {
        // Pass reveal
        await passThroughAllReveals(tester, 4);

        final dynamic state = tester.state(find.byType(GamePage));
        expect(state.screen.toString(), contains('discuss'),
            reason: 'Round $round lands on discuss');

        // Verify fresh questioning state: questionTurnIdx == 0
        expect(state.questionTurnIdx, equals(0),
            reason: 'Round $round questionTurnIdx must start at 0');

        // Advance to mid turn
        final nextBtn = find.text('Next question');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.questionTurnIdx, equals(1));

        // Jump to voting
        final voteBtn = find.text('Vote');
        await tester.ensureVisible(voteBtn);
        await tester.tap(voteBtn);
        await tester.pump(const Duration(milliseconds: 50));
        expect(state.screen.toString(), contains('vote'));

        // All vote for the first fraud
        final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
        final targetFraud = fraudIndices.first;
        for (int v = 0; v < 4; v++) {
          if (find.text('Tap to vote').evaluate().isNotEmpty) {
            final tapVoteBtn = find.text('Tap to vote');
            await tester.ensureVisible(tapVoteBtn);
            await tester.tap(tapVoteBtn);
            await tester.pump(const Duration(milliseconds: 50));
          }

          if (v == targetFraud) {
            final alt = (targetFraud + 1) % 4;
            final targetPlayer = find.text(state.players[alt]);
            await tester.ensureVisible(targetPlayer);
            await tester.tap(targetPlayer);
          } else {
            final targetPlayer = find.text(state.players[targetFraud]);
            await tester.ensureVisible(targetPlayer);
            await tester.tap(targetPlayer);
          }
          await tester.pump(const Duration(milliseconds: 50));

          final confirmBtn = find.text('Vote');
          await tester.ensureVisible(confirmBtn);
          await tester.tap(confirmBtn);
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Guess screen
        expect(find.text('Last chance!'), findsOneWidget);
        final List<String> guessOptions = (state.guessOptions as List<String>);
        final wrongWord = guessOptions.firstWhere((w) => w != state.roundWord);
        final wrongWordFinder = find.text(wrongWord);
        await tester.ensureVisible(wrongWordFinder);
        await tester.tap(wrongWordFinder);
        await tester.pump(const Duration(milliseconds: 50));

        final confirmGuessBtn = find.text('Confirm guess');
        await tester.ensureVisible(confirmGuessBtn);
        await tester.tap(confirmGuessBtn);
        await tester.pump(const Duration(milliseconds: 50));

        // Result screen
        expect(find.text('THE PLAYERS WIN'), findsOneWidget);

        if (round < 3) {
          // Tap "Continue"
          final continueBtn = find.text('Continue');
          await tester.ensureVisible(continueBtn);
          await tester.tap(continueBtn);
          await tester.pump(const Duration(milliseconds: 100));

          expect(state.screen.toString(), contains('category'));
          final catBtn = find.text('Food');
          await tester.ensureVisible(catBtn);
          await tester.tap(catBtn);
          await tester.pump(const Duration(milliseconds: 100));

          final startRoundBtn = find.text('Start round');
          await tester.ensureVisible(startRoundBtn);
          await tester.tap(startRoundBtn);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });
  });
}
