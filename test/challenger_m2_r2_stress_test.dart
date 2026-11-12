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

  /// Helper: Navigate from Home through mode and category setup, setting custom player names if provided,
  /// then completing all player reveals to land on Screen.discuss.
  Future<void> setupAndReachDiscussion(
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

    // Select Mode
    await tester.tap(find.text(modeTitle));
    await tester.pump(const Duration(milliseconds: 100));

    // Select Category
    await tester.tap(find.text(category));
    await tester.pump(const Duration(milliseconds: 100));

    // Adjust player count
    while (tester.widgetList(find.byType(TextField)).length < playerCount) {
      await tester.tap(find.text('Add player'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.widgetList(find.byType(TextField)).length > playerCount) {
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Set custom names if provided
    if (customNames != null) {
      final fields = find.byType(TextField);
      for (int i = 0; i < customNames.length && i < playerCount; i++) {
        await tester.enterText(fields.at(i), customNames[i]);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Start round -> lands on Screen.pass
    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));

    // Pass through all player reveals to enter Screen.discuss
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

    // Ensure we are now on Screen.discuss
    expect(find.text('Discuss!'), findsOneWidget);
  }

  // =========================================================================
  // GROUP 1: MULTI-VIEWPORT EXTREME RESPONSIVENESS & ZERO OVERFLOW STRESS
  // =========================================================================
  group('Challenger M2 R2: Multi-Viewport Responsive Stress Suite', () {
    testWidgets('VP.1: Ultra-compact mobile (320x568 iPhone SE 1st gen) zero overflow',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      setViewport(tester, width: 320.0, height: 568.0);
      await tester.pump(const Duration(milliseconds: 50));

      // Light box Discuss title
      expect(find.text('Discuss!'), findsOneWidget);
      // Light box instruction container
      expect(find.textContaining('Give clues and ask each other questions'), findsOneWidget);
      // Vertical prompt: Asker box, 'asks' text, Target box
      expect(find.text('asks'), findsOneWidget);

      expect(tester.takeException(), isNull,
          reason: 'Initial 320x568 viewport render must have zero RenderFlex overflow');

      // Scroll and advance through question turns
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull,
          reason: 'Turn advance on 320x568 must have zero overflow');

      // Tap Next question again
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Verify Vote button is reachable by scroll and works
      final voteBtn = find.widgetWithText(ElevatedButton, 'Vote');
      await tester.ensureVisible(voteBtn);
      await tester.tap(voteBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Vote 1 of'), findsWidgets);
    });

    testWidgets('VP.2: Standard compact mobile (375x667 iPhone 8 / SE 2nd gen) zero overflow',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      setViewport(tester, width: 375.0, height: 667.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VP.3: Standard flagship Android (412x915 Pixel 7) zero overflow',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      setViewport(tester, width: 412.0, height: 915.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VP.4: Tablet portrait (768x1024 iPad Mini) centers within max constraint 640px',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      setViewport(tester, width: 768.0, height: 1024.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify ConstrainedBox enforces maxWidth 640
      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 640,
      );
      expect(constrainedBoxFinder, findsOneWidget);

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VP.5: Desktop Full HD (1080x1920) zero overflow',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      setViewport(tester, width: 1080.0, height: 1920.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('VP.6: Squished landscape mobile (800x350 & 600x300) scrollable without clipping',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      // Test 800x350
      setViewport(tester, width: 800.0, height: 350.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Discuss!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll down to Next question and tap
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.ensureVisible(nextQuestionBtn);
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Test extreme squished landscape 600x300
      setViewport(tester, width: 600.0, height: 300.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Discuss!'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final voteBtn = find.widgetWithText(ElevatedButton, 'Vote');
      await tester.ensureVisible(voteBtn);
      await tester.tap(voteBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Vote 1 of'), findsWidgets);
    });
  });

  // =========================================================================
  // GROUP 2: STRESS-TESTING VERTICAL QUESTIONING BOXES WITH EXTREME NAMES
  // =========================================================================
  group('Challenger M2 R2: Extreme Player Names Stress Suite', () {
    testWidgets('PN.1: Extremely long names and unbroken strings render and wrap cleanly on 320px viewport',
        (WidgetTester tester) async {
      final extremeNames = [
        'SupercalifragilisticexpialidociousUnbrokenLongStringWithoutSpaces1234567890',
        'Sir Bartholomew Montgomery-Hetherington-Smythe III of Greater London England',
        'Wolfeschlegelsteinhausenbergerdorffwelchevoralterwarengewissenhaftssicherheit',
        'Dr. Elizabeth Alexandria Theodora von Hohenzollern-Sigmaringen Duchess of Bavaria',
      ];

      await setupAndReachDiscussion(
        tester,
        playerCount: 4,
        customNames: extremeNames,
      );

      // Set to narrowest viewport
      setViewport(tester, width: 320.0, height: 600.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull,
          reason: 'Extreme names must not throw layout exceptions on 320px viewport');

      // Verify that 'asks' connector is present
      expect(find.text('asks'), findsOneWidget);

      // Verify that at least two of the extreme names are rendered on screen
      int renderedCount = 0;
      for (final name in extremeNames) {
        if (tester.any(find.text(name))) {
          renderedCount++;
        }
      }
      expect(renderedCount, equals(2),
          reason: 'Exactly two extreme names must be rendered on the vertical questioning cards');

      // Step through all 4 turns to ensure every extreme name renders without overflow
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      for (int i = 0; i < 4; i++) {
        await tester.ensureVisible(nextQuestionBtn);
        await tester.tap(nextQuestionBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'Turn $i with extreme long names must have zero RenderFlex overflow');
      }
    });

    testWidgets('PN.2: Complex multi-byte emoji names render without crash',
        (WidgetTester tester) async {
      final emojiNames = [
        '👑🔥🚀💎🎉',
        '👩‍👩‍👦‍👦👨‍💻🧙‍♂️🧝‍♀️',
        '🕵️‍♂️ vs 🕵️‍♀️',
        '🍔🍕🍣🍦🍩',
      ];

      await setupAndReachDiscussion(
        tester,
        playerCount: 4,
        customNames: emojiNames,
      );

      setViewport(tester, width: 360.0, height: 640.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('asks'), findsOneWidget);

      int renderedEmojiNames = 0;
      for (final name in emojiNames) {
        if (tester.any(find.text(name))) {
          renderedEmojiNames++;
        }
      }
      expect(renderedEmojiNames, equals(2));

      // Advance through questions
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      for (int i = 0; i < 4; i++) {
        await tester.ensureVisible(nextQuestionBtn);
        await tester.tap(nextQuestionBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('PN.3: Foreign scripts & RTL text (Arabic, CJK, Cyrillic, Devanagari) render cleanly',
        (WidgetTester tester) async {
      final foreignNames = [
        'محمد بن عبد الله آل سعود',
        'ウィリアム・シェイクスピア 𠮷野家',
        'Александр Константинович Преображенский',
        'श्री कृष्ण जन्माष्टमी',
      ];

      await setupAndReachDiscussion(
        tester,
        playerCount: 4,
        customNames: foreignNames,
      );

      setViewport(tester, width: 360.0, height: 640.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('asks'), findsOneWidget);

      int renderedForeignNames = 0;
      for (final name in foreignNames) {
        if (tester.any(find.text(name))) {
          renderedForeignNames++;
        }
      }
      expect(renderedForeignNames, equals(2));

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      for (int i = 0; i < 4; i++) {
        await tester.ensureVisible(nextQuestionBtn);
        await tester.tap(nextQuestionBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  });

  // =========================================================================
  // GROUP 3: RAPID QUESTION STEPPING STRESS (50+ DYNAMIC DERANGEMENTS)
  // =========================================================================
  group('Challenger M2 R2: Rapid Question Stepping Stress Suite', () {
    testWidgets('QS.1: Rapid stepping across 64 questions (16 full 4-player rounds) strictly maintains derangements',
        (WidgetTester tester) async {
      const playerCount = 4;
      await setupAndReachDiscussion(tester, playerCount: playerCount);

      final dynamic state = tester.state(find.byType(GamePage));
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');

      // Cycle rapidly through 64 questions
      for (int step = 0; step < 64; step++) {
        expect(state.questionTurnIdx, equals(step),
            reason: 'Question turn index must be exactly $step');

        final askers = state.questionAskers as List<int>;
        final targets = state.questionTargets as List<int>;

        // Verify lists are non-empty and equal in length
        expect(askers.length, greaterThanOrEqualTo(step + 1));
        expect(targets.length, equals(askers.length));

        // Strict zero self-questioning invariant
        expect(askers[step], isNot(equals(targets[step])),
            reason: 'Step $step: Player ${askers[step]} cannot question themselves');

        // Tap Next question
        await tester.tap(nextQuestionBtn);
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Another round').evaluate().isNotEmpty) {
          await tester.tap(find.text('Another round'));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      expect(state.questionTurnIdx, equals(64));
      final finalAskers = state.questionAskers as List<int>;
      final finalTargets = state.questionTargets as List<int>;

      // Verify that every 4-turn round within the 64 questions was a full derangement
      for (int round = 0; round < 16; round++) {
        final roundAskers = finalAskers.sublist(round * 4, (round + 1) * 4);
        final roundTargets = finalTargets.sublist(round * 4, (round + 1) * 4);

        expect(roundAskers.toSet().length, equals(playerCount),
            reason: 'Round $round: All $playerCount players must ask questions');
        expect(roundTargets.toSet().length, equals(playerCount),
            reason: 'Round $round: All $playerCount players must be asked questions');

        for (int q = 0; q < 4; q++) {
          expect(roundAskers[q], isNot(equals(roundTargets[q])),
              reason: 'Round $round Question $q: No self-asking');
        }
      }

      // Verify zero RenderFlex overflow occurred during rapid rebuilds
      expect(tester.takeException(), isNull);

      // Verify transitioning to voting after rapid stepping works seamlessly
      final voteBtn = find.widgetWithText(ElevatedButton, 'Vote');
      await tester.ensureVisible(voteBtn);
      await tester.tap(voteBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen.toString(), contains('vote'));
      expect(find.textContaining('Vote 1 of'), findsWidgets);
    });

    testWidgets('QS.2: Rapid stepping across 50 questions with 10 players (maximum capacity)',
        (WidgetTester tester) async {
      const playerCount = 10;
      await setupAndReachDiscussion(tester, playerCount: playerCount);

      final dynamic state = tester.state(find.byType(GamePage));
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');

      // 50 questions = 5 complete 10-player derangement rounds
      for (int step = 0; step < 50; step++) {
        expect(state.questionTurnIdx, equals(step));

        final askers = state.questionAskers as List<int>;
        final targets = state.questionTargets as List<int>;

        expect(askers[step], isNot(equals(targets[step])),
            reason: '10-player Step $step: Zero self-asking ($askers[step] != $targets[step])');

        await tester.tap(nextQuestionBtn);
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Another round').evaluate().isNotEmpty) {
          await tester.tap(find.text('Another round'));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      expect(state.questionTurnIdx, equals(50));
      final finalAskers = state.questionAskers as List<int>;
      final finalTargets = state.questionTargets as List<int>;

      for (int round = 0; round < 5; round++) {
        final roundAskers = finalAskers.sublist(round * 10, (round + 1) * 10);
        final roundTargets = finalTargets.sublist(round * 10, (round + 1) * 10);

        expect(roundAskers.toSet().length, equals(playerCount),
            reason: '10-player Round $round: All 10 players must ask');
        expect(roundTargets.toSet().length, equals(playerCount),
            reason: '10-player Round $round: All 10 players must be asked');
      }

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 4: OPTIONS DIALOG VIA THREE-DOTS ICON ACTIONS VERIFICATION
  // =========================================================================
  group('Challenger M2 R2: Options Dialog Via Three-Dots Icon Suite', () {
    testWidgets('OD.1: Three-dots icon opens options dialog and "Cancel" dismisses without state change',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Advance to turn 2
      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');
      await tester.tap(nextQuestionBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.questionTurnIdx, equals(1));

      // Tap three-dots icon
      final optionsIconFinder = find.byIcon(Icons.more_vert);
      expect(optionsIconFinder, findsOneWidget);
      await tester.tap(optionsIconFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog contents
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Restart round'), findsOneWidget);
      expect(find.text('Change players'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog dismissed, remains on discuss with same turn index
      expect(find.text('Options'), findsNothing);
      expect(state.screen.toString(), contains('discuss'));
      expect(state.questionTurnIdx, equals(1));
    });

    testWidgets('OD.2: "Restart round" resets round cleanly from discussion',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final optionsIconFinder = find.byIcon(Icons.more_vert);
      await tester.tap(optionsIconFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Restart round
      await tester.tap(find.text('Restart round'));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Restart').evaluate().isNotEmpty) {
        await tester.tap(find.text('Restart'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Lands on Screen.pass for player 0
      expect(state.screen.toString(), contains('pass'));
      expect(state.passIdx, equals(0));
      expect(find.text('Pass the phone'), findsOneWidget);
    });

    testWidgets('OD.3: "Change players" navigates to Screen.players preserving player list',
        (WidgetTester tester) async {
      final customPlayers = ['Alice', 'Bob', 'Charlie', 'Diana'];
      await setupAndReachDiscussion(
        tester,
        playerCount: 4,
        customNames: customPlayers,
      );

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final optionsIconFinder = find.byIcon(Icons.more_vert);
      await tester.tap(optionsIconFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Change players
      await tester.tap(find.text('Change players'));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Change').evaluate().isNotEmpty) {
        await tester.tap(find.text('Change'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Lands on Screen.players
      expect(state.screen.toString(), contains('players'));
      expect(find.text('Players'), findsOneWidget);

      // Player names are preserved
      for (final p in customPlayers) {
        expect(find.text(p), findsOneWidget);
      }
    });

    testWidgets('OD.4: "Back to main menu" safely resets to Screen.home',
        (WidgetTester tester) async {
      await setupAndReachDiscussion(tester, playerCount: 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final optionsIconFinder = find.byIcon(Icons.more_vert);
      await tester.tap(optionsIconFinder);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Confirm').evaluate().isNotEmpty) {
        await tester.tap(find.text('Confirm'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Lands on Screen.home
      expect(state.screen.toString(), contains('home'));
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);
    });
  });
}
