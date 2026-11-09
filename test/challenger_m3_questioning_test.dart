import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  void setViewport(WidgetTester tester, {double width = 800, double height = 2400}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Helper: Navigate from Home to Players setup screen
  Future<void> navigateToPlayers(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    setViewport(tester);
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

  /// Helper: Start round from Home with specific player count, mode, and category
  Future<void> startRoundWithPlayerCount(
    WidgetTester tester, {
    required int targetCount,
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    await navigateToPlayers(tester, modeTitle: modeTitle, category: category);

    // Initial default is 4 players
    while (tester.widgetList(find.byType(TextField)).length < targetCount) {
      await tester.tap(find.text('Add player'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.widgetList(find.byType(TextField)).length > targetCount) {
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(TextField), findsNWidgets(targetCount));

    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper: Pass reveal for all players
  Future<void> passThroughAllPlayers(WidgetTester tester, int playerCount) async {
    for (int p = 0; p < playerCount; p++) {
      expect(find.text('Pass the phone'), findsOneWidget);
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400));

      final isLast = p == playerCount - 1;
      final nextBtn = isLast
          ? find.text('Hide and start discussion')
          : find.text('Hide and pass on');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // =========================================================================
  // GROUP 1: MATHEMATICAL & ROUND-ROBIN PAIRING INVARIANTS (ORACLE 3-10 PLAYERS)
  // =========================================================================
  group('Empirical Challenger M3: Group 1 - Random Derangement Invariants Oracle (3 to 10 players)', () {
    test('QR.1.1: Oracle verifies random derangement pairings for 3 to 10 players across 800 permutations', () {
      final rng = Random(42);

      for (int n = 3; n <= 10; n++) {
        for (int iteration = 0; iteration < 100; iteration++) {
          final pairing = generateRandomQuestioningRound(n, rng);
          final askers = pairing.askers;
          final targets = pairing.targets;

          // 1. Length invariant
          expect(askers.length, equals(n),
              reason: 'Turn count must strictly equal player count $n');
          expect(targets.length, equals(n),
              reason: 'Target count must strictly equal player count $n');

          // 2. Strict inequality invariant: Asker != Responder on every turn
          for (int t = 0; t < n; t++) {
            expect(askers[t], isNot(equals(targets[t])),
                reason: 'Turn $t: Asker (${askers[t]}) must not equal Responder (${targets[t]}) for $n players');
          }

          // 3. Permutation completeness: Every player asks exactly once
          final askerSet = askers.toSet();
          expect(askerSet.length, equals(n),
              reason: 'Every player must ask questions exactly once');

          // 4. Permutation completeness: Every player is asked exactly once
          final targetSet = targets.toSet();
          expect(targetSet.length, equals(n),
              reason: 'Every player must be asked questions exactly once');
        }
      }
    });
  });

  // =========================================================================
  // GROUP 2: SIMPLIFIED QUESTIONING DISPLAY & CONTROLS (N=3, R4)
  // =========================================================================
  group('Empirical Challenger M3: Group 2 - Simplified Questioning & Controls (N=3)', () {
    testWidgets('QR.2.1: Questioning UI correctly renders vertical indicator boxes, infinite progression, and Vote button',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 3, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 3);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final List<int> askers = (state.questionAskers as List<int>);
      final List<int> targets = (state.questionTargets as List<int>);
      final List<String> players = (state.players as List<String>);

      // Invariant: No question counter, no "Questioning Round", no ASKER/RESPONDER labels
      expect(find.text('Question 1 of 3'), findsNothing);
      expect(find.text('Questioning Round'), findsNothing);
      expect(find.text('ASKER'), findsNothing);
      expect(find.text('RESPONDER'), findsNothing);

      // Light box instruction container and Discuss header are present
      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('Give clues and ask each other questions. Do not say your secret word!'), findsOneWidget);

      // Top bar options menu icon is present matching voting screen
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byTooltip('Options'), findsOneWidget);

      // TURN 1: Vertical prompt (asker and responder in separate boxes separated by 'asks')
      final asker0 = players[askers[0]];
      final target0 = players[targets[0]];
      expect(find.text(asker0), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(target0), findsOneWidget);
      expect(find.text('$asker0 asks $target0'), findsNothing);

      // Controls on turn 1: Previous question button is completely removed
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('Previous question'), findsNothing,
          reason: 'Previous question button must be removed per R4.3');

      // Bottom voting button is strictly labeled 'Vote'
      expect(find.text('Vote'), findsOneWidget);

      // ADVANCE TO TURN 2
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      final asker1 = players[state.questionAskers[1]];
      final target1 = players[state.questionTargets[1]];
      expect(find.text(asker1), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(target1), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
      expect(find.text('Next question'), findsOneWidget);

      // ADVANCE TO TURN 3
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      final asker2 = players[state.questionAskers[2]];
      final target2 = players[state.questionTargets[2]];
      expect(find.text(asker2), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(target2), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
      expect(find.text('Next question'), findsOneWidget);

      // ADVANCE TO TURN 4 (Subsequent round generation)
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      // In Round 2, new pairings are appended (total length becomes 6)
      expect(state.questionTurnIdx, equals(3));
      expect(state.questionAskers.length, equals(6));
      expect(state.questionTargets.length, equals(6));

      final asker3 = players[state.questionAskers[3]];
      final target3 = players[state.questionTargets[3]];
      expect(find.text(asker3), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(target3), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
      expect(find.text('Next question'), findsOneWidget);
    });

    testWidgets('QR.2.2: Discussion screen top bar includes three-dots options menu matching voting',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 3, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 3);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Verify three-dots menu icon exists in top bar
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byTooltip('Options'), findsOneWidget);

      // Tap options icon to display modal dialog
      await tester.tap(find.byTooltip('Options'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Restart round'), findsOneWidget);
      expect(find.text('Change players'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel dismisses dialog without state change
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsNothing);
      expect(state.screen.toString(), contains('discuss'));
    });
  });

  // =========================================================================
  // GROUP 3: BOUNDARY MAXIMUM SCALE (N=10 PLAYERS FULL TRAVERSAL)
  // =========================================================================
  group('Empirical Challenger M3: Group 3 - Maximum Player Scale (N=10)', () {
    testWidgets('QR.3.1: Sequential 10-player questioning traversal verifies vertical prompt, derangements, and round 2 progression',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 10, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 10);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final List<int> askers = (state.questionAskers as List<int>);
      final List<int> targets = (state.questionTargets as List<int>);
      final List<String> players = (state.players as List<String>);

      expect(askers.length, equals(10));
      expect(targets.length, equals(10));

      // Step forward through all 10 questions in Round 1
      for (int step = 1; step <= 10; step++) {
        final currentAsker = players[askers[step - 1]];
        final currentTarget = players[targets[step - 1]];
        expect(currentAsker, isNot(equals(currentTarget)),
            reason: 'Step $step: Asker must differ from Responder');

        expect(find.text(currentAsker), findsOneWidget);
        expect(find.text('asks'), findsOneWidget);
        expect(find.text(currentTarget), findsOneWidget);

        // Previous question is removed per R4.3
        expect(find.text('Previous question'), findsNothing);

        // Infinite cycling: Next question is always available
        expect(find.text('Next question'), findsOneWidget);
        if (step < 10) {
          await tester.tap(find.text('Next question'));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // Advance to Question 11 (entering Round 2 with 10 players)
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.questionTurnIdx, equals(10));
      expect(state.questionAskers.length, equals(20));
      expect(state.questionTargets.length, equals(20));

      // Verify Round 2 derangement invariants across all 10 players
      final round2Askers = (state.questionAskers as List<int>).sublist(10, 20);
      final round2Targets = (state.questionTargets as List<int>).sublist(10, 20);
      expect(round2Askers.toSet().length, equals(10));
      expect(round2Targets.toSet().length, equals(10));
      for (int t = 0; t < 10; t++) {
        expect(round2Askers[t], isNot(equals(round2Targets[t])),
            reason: 'Round 2 Turn $t: Asker must not equal Responder');
      }

      final r2FirstAsker = players[round2Askers[0]];
      final r2FirstTarget = players[round2Targets[0]];
      expect(find.text(r2FirstAsker), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(r2FirstTarget), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
      expect(find.text('Next question'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: EARLY, MID, AND LATE VOTING TRANSITIONS
  // =========================================================================
  group('Empirical Challenger M3: Group 4 - Voting Transitions at Any Turn', () {
    testWidgets('QR.4.1: Voting transition is operable immediately on Turn 1 (Early Voting)',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Tap 'Vote' directly
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // Successfully transitioned to Screen.vote
      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('vote'));
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.text('Vote 1 of 4'), findsOneWidget);
    });

    testWidgets('QR.4.2: Voting transition is operable mid-way on Turn 2 of 4',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Advance to Turn 2
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Vote'
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('vote'));
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.text('Vote 1 of 4'), findsOneWidget);
    });

    testWidgets('QR.4.3: Voting transition is operable on later turns',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Step forward 3 turns
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Tap 'Vote'
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('vote'));
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.text('Vote 1 of 4'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 5: DISCUSSION TIMER CANCELLATION AND TEARDOWN
  // =========================================================================
  group('Empirical Challenger M3: Group 5 - Timer Cancellation on Voting Start', () {
    testWidgets('QR.5.1: Discussion timer is cancelled immediately when voting starts',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Set discussion timer to 2 minutes directly on state
      final dynamic appState = tester.state(find.byType(GamePage));
      appState.timerMinutes = 2;

      // 2. Start game
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Pass through all 4 players
      await passThroughAllPlayers(tester, 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // 4. Verify timer is currently active and counting down
      expect(state.timer, isNotNull);
      expect(state.timer.isActive, isTrue,
          reason: 'Timer must be actively running during discussion');
      expect(state.secondsLeft, inInclusiveRange(115, 120));

      // Advance 1 question
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify timer is still active
      expect(state.timer.isActive, isTrue);

      // 5. Tap 'Vote' to transition to voting
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Verify transition and timer cancellation
      expect(state.screen.toString(), contains('vote'));
      expect(state.timer.isActive, isFalse,
          reason: 'Discussion timer must be cancelled immediately when startVoting() is called');

      // 7. Advance time by 10 virtual seconds: ensure no background timer callbacks fire or crash
      await tester.pump(const Duration(seconds: 10));
      expect(state.timer.isActive, isFalse);
    });

    testWidgets('QR.5.2: Timer reaching 0 allows continuous questioning and clean voting transition',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Configure timer to 2 min
      final dynamic appState = tester.state(find.byType(GamePage));
      appState.timerMinutes = 2;

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      await passThroughAllPlayers(tester, 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Simulate timer ticking down to 0
      state.secondsLeft = 1;
      await tester.pump(const Duration(seconds: 1));

      expect(state.secondsLeft, equals(0));
      expect(state.timer.isActive, isFalse, reason: 'Timer should cancel upon reaching 0');

      // Questioning controls still function smoothly
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      // Voting button still functions smoothly
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));
    });
  });

  // =========================================================================
  // GROUP 6: ADVERSARIAL STRESS: UNICODE, SPECIAL CHARS & GAME MODES
  // =========================================================================
  group('Empirical Challenger M3: Group 6 - Unicode Names, Game Modes & Multi-Round Reset', () {
    testWidgets('QR.6.1: Non-ASCII, Arabic, and emoji player names render cleanly in Asker/Responder cards',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));

      final customNames = ['سالم 🎭', 'مريم الفهد', 'عبد العزيز الطويل جدا جدا جدا', 'Player 4'];
      for (int i = 0; i < 4; i++) {
        await tester.enterText(textFields.at(i), customNames[i]);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      await passThroughAllPlayers(tester, 4);

      // Verify questioning cards render without layout crashes
      final dynamic state = tester.state(find.byType(GamePage));
      final int firstAskerIdx = (state.questionAskers as List<int>)[0];
      final int firstTargetIdx = (state.questionTargets as List<int>)[0];

      expect(find.text(customNames[firstAskerIdx]), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(customNames[firstTargetIdx]), findsOneWidget);

      // Tap through turns to verify no overflow exceptions occur with long Arabic names
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Next question'), findsOneWidget);
    });

    testWidgets('QR.6.2: Questioning rounds operate identically in Two Frauds mode (5 players)',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 5, modeTitle: 'Two Frauds', category: 'Animals');
      await passThroughAllPlayers(tester, 5);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final List<int> askers = (state.questionAskers as List<int>);
      final List<int> targets = (state.questionTargets as List<int>);
      expect(askers.length, equals(5));
      expect(targets.length, equals(5));
      expect(find.text(state.players[askers[0]]), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text(state.players[targets[0]]), findsOneWidget);

      // Verify Asker != Responder across all 5 turns
      for (int t = 0; t < 5; t++) {
        expect(askers[t], isNot(equals(targets[t])));
      }

      // Step to final turn and beyond (infinite cycling)
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Next question'), findsOneWidget);
    });

    testWidgets('QR.6.3: Multi-round questioning state isolation resets cleanly on subsequent round',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // In Round 1 discussion, advance to turn 3
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 50));

      // Proceed to vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);

      // Complete voting: voters vote for the fraud (fraud votes for another player)
      final fraudTargetIdx = fraudIndices.first;
      for (int v = 0; v < 4; v++) {
        expect(find.text('Tap to vote'), findsOneWidget);
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 50));

        if (v == fraudTargetIdx) {
          final alternateIdx = (fraudTargetIdx + 1) % 4;
          await tester.tap(find.text(state.players[alternateIdx]));
        } else {
          await tester.tap(find.text(state.players[fraudTargetIdx]));
        }
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Catch fraud -> Guess screen -> pick wrong word
      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> guessOptions = (state.guessOptions as List<String>);
      final wrongWord = guessOptions.firstWhere((w) => w != state.roundWord);
      await tester.tap(find.text(wrongWord));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 50));

      // Now on Result screen
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Continue to next round (category selection)
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen.toString(), contains('category'));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Pass reveal for Round 2
      await passThroughAllPlayers(tester, 4);

      // Round 2 discussion: questionTurnIdx must be reset to 0
      expect(state.questionTurnIdx, equals(0),
          reason: 'questionTurnIdx must cleanly reset to 0 in a new round');
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
    });

    testWidgets('QR.6.4: Uninitialized or corrupted pairing state falls back gracefully without throwing',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Adversarially corrupt questionAskers and questionTargets to empty lists with setState
      state.setState(() {
        state.questionAskers = <int>[];
        state.questionTargets = <int>[];
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Defensive fallback must engage: Player 1 asks Player 2 rendered cleanly in vertical layout
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);

      // Verify navigation still functions cleanly under fallback
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);

      // Verify voting transition works cleanly
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));
    });
  });
}
