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
  group('Empirical Challenger M3: Group 1 - Round-Robin Invariants Oracle (3 to 10 players)', () {
    test('QR.1.1: Oracle verifies round-robin pairings for 3 to 10 players across 800 permutations', () {
      final rng = Random(42);

      for (int n = 3; n <= 10; n++) {
        for (int iteration = 0; iteration < 100; iteration++) {
          final order = List.generate(n, (i) => i)..shuffle(rng);
          final askers = List<int>.from(order);
          final targets = List.generate(n, (i) => order[(i + 1) % n]);

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

          // 5. Single Hamiltonian Cycle: Traversing askers[i] -> targets[i] visits all players
          final visited = <int>{};
          int current = askers[0];
          for (int step = 0; step < n; step++) {
            expect(visited.contains(current), isFalse,
                reason: 'Cycle must not prematurely repeat player $current before visiting all $n players');
            visited.add(current);

            // Find index of current as asker
            final turnIdx = askers.indexOf(current);
            expect(turnIdx, isNot(equals(-1)));
            current = targets[turnIdx];
          }

          expect(visited.length, equals(n),
              reason: 'Traversing the questioning chain must visit all $n players');
          expect(current, equals(askers[0]),
              reason: 'Traversing $n edges must return to the initial asker');

          // 6. Direct forward link: Responder of turn t is the Asker of turn (t+1)%n
          for (int t = 0; t < n; t++) {
            final nextTurn = (t + 1) % n;
            expect(targets[t], equals(askers[nextTurn]),
                reason: 'Responder of turn $t must be the Asker of turn $nextTurn');
          }
        }
      }
    });
  });

  // =========================================================================
  // GROUP 2: UI TURN COUNTER & NAVIGATION CONTROLS (N=3, BOUNDARY MINIMUM)
  // =========================================================================
  group('Empirical Challenger M3: Group 2 - Turn Counter & Controls (N=3)', () {
    testWidgets('QR.2.1: Questioning UI correctly renders turn counter, cards, directional arrow, and controls',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 3, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 3);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      final List<int> askers = (state.questionAskers as List<int>);
      final List<int> targets = (state.questionTargets as List<int>);
      final List<String> players = (state.players as List<String>);

      // =====================================================================
      // TURN 1: "Question 1 of 3"
      // =====================================================================
      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('Questioning Round'), findsOneWidget);
      expect(find.text('ASKER'), findsOneWidget);
      expect(find.text('RESPONDER'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);

      final asker0 = players[askers[0]];
      final target0 = players[targets[0]];
      expect(find.text(asker0), findsWidgets);
      expect(find.text(target0), findsWidgets);
      expect(find.text('$asker0 asks $target0 a question about the secret word.'), findsOneWidget);

      // Verify Icons
      expect(find.byIcon(Icons.record_voice_over_rounded), findsOneWidget);
      expect(find.byIcon(Icons.hearing_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

      // Controls on turn 1
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('Previous question'), findsNothing,
          reason: 'Previous question button must not be visible on turn 1');
      expect(find.text('✓ All questions asked! Ready to vote.'), findsNothing,
          reason: 'Completion badge must not be visible on turn 1');

      // Bottom voting button is always present
      expect(find.text('Vote: who is the fraud?'), findsOneWidget);

      // =====================================================================
      // ADVANCE TO TURN 2: "Question 2 of 3"
      // =====================================================================
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Question 2 of 3'), findsOneWidget);
      final asker1 = players[askers[1]];
      final target1 = players[targets[1]];
      expect(find.text('$asker1 asks $target1 a question about the secret word.'), findsOneWidget);

      // Both Previous and Next buttons are present on intermediate turn
      expect(find.text('Previous question'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('✓ All questions asked! Ready to vote.'), findsNothing);

      // =====================================================================
      // ADVANCE TO TURN 3: "Question 3 of 3" (FINAL TURN)
      // =====================================================================
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Question 3 of 3'), findsOneWidget);
      final asker2 = players[askers[2]];
      final target2 = players[targets[2]];
      expect(find.text('$asker2 asks $target2 a question about the secret word.'), findsOneWidget);

      // Final turn: Next question is replaced by completion indicator
      expect(find.text('Next question'), findsNothing,
          reason: 'Next question must be replaced by completion badge on the final turn');
      expect(find.text('✓ All questions asked! Ready to vote.'), findsOneWidget,
          reason: 'Completion badge must appear on the final turn');
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      // Previous question button remains available
      expect(find.text('Previous question'), findsOneWidget);

      // =====================================================================
      // STEP BACK TO TURN 2
      // =====================================================================
      await tester.tap(find.text('Previous question'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Question 2 of 3'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget,
          reason: 'Next question must reappear when stepping back from the final turn');
      expect(find.text('✓ All questions asked! Ready to vote.'), findsNothing);

      // =====================================================================
      // STEP BACK TO TURN 1
      // =====================================================================
      await tester.tap(find.text('Previous question'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Question 1 of 3'), findsOneWidget);
      expect(find.text('Previous question'), findsNothing,
          reason: 'Previous question must disappear again when returned to turn 1');
      expect(find.text('Next question'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: BOUNDARY MAXIMUM SCALE (N=10 PLAYERS FULL TRAVERSAL)
  // =========================================================================
  group('Empirical Challenger M3: Group 3 - Maximum Player Scale (N=10)', () {
    testWidgets('QR.3.1: Sequential 10-player questioning traversal verifies counter, pairs, and boundaries',
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

      // Step forward through all 10 questions
      for (int step = 1; step <= 10; step++) {
        expect(find.text('Question $step of 10'), findsOneWidget);

        final currentAsker = players[askers[step - 1]];
        final currentTarget = players[targets[step - 1]];
        expect(currentAsker, isNot(equals(currentTarget)),
            reason: 'Step $step: Asker must differ from Responder');

        expect(find.text('$currentAsker asks $currentTarget a question about the secret word.'), findsOneWidget);

        if (step < 10) {
          expect(find.text('Next question'), findsOneWidget);
          await tester.tap(find.text('Next question'));
          await tester.pump(const Duration(milliseconds: 100));
        } else {
          // Final question (step 10)
          expect(find.text('Next question'), findsNothing);
          expect(find.text('✓ All questions asked! Ready to vote.'), findsOneWidget);
          expect(find.text('Previous question'), findsOneWidget);
        }
      }

      // Step backward all the way from 10 back to 1
      for (int step = 10; step >= 2; step--) {
        expect(find.text('Question $step of 10'), findsOneWidget);
        await tester.tap(find.text('Previous question'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Back at Question 1 of 10
      expect(find.text('Question 1 of 10'), findsOneWidget);
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

      // On Question 1 of 4
      expect(find.text('Question 1 of 4'), findsOneWidget);

      // Tap 'Vote: who is the fraud?' directly
      await tester.tap(find.text('Vote: who is the fraud?'));
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

      // Advance to Question 2 of 4
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Question 2 of 4'), findsOneWidget);

      // Tap 'Vote: who is the fraud?'
      await tester.tap(find.text('Vote: who is the fraud?'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('vote'));
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.text('Vote 1 of 4'), findsOneWidget);
    });

    testWidgets('QR.4.3: Voting transition is operable after completion badge on final turn',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Step to final turn (Question 4 of 4)
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Question 4 of 4'), findsOneWidget);
      expect(find.text('✓ All questions asked! Ready to vote.'), findsOneWidget);

      // Tap 'Vote: who is the fraud?'
      await tester.tap(find.text('Vote: who is the fraud?'));
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

      // 1. Set discussion timer to 2 minutes in Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('2 min'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

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
      expect(find.text('Question 2 of 4'), findsOneWidget);

      // Verify timer is still active
      expect(state.timer.isActive, isTrue);

      // 5. Tap 'Vote: who is the fraud?' to transition to voting
      await tester.tap(find.text('Vote: who is the fraud?'));
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
      expect(find.text('Question 2 of 4'), findsOneWidget);

      // Voting button still functions smoothly
      await tester.tap(find.text('Vote: who is the fraud?'));
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
      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.text('ASKER'), findsOneWidget);
      expect(find.text('RESPONDER'), findsOneWidget);

      final dynamic state = tester.state(find.byType(GamePage));
      final int firstAskerIdx = (state.questionAskers as List<int>)[0];
      final int firstTargetIdx = (state.questionTargets as List<int>)[0];

      expect(find.text(customNames[firstAskerIdx]), findsWidgets);
      expect(find.text(customNames[firstTargetIdx]), findsWidgets);

      // Tap through all 4 turns to verify no overflow exceptions occur with long Arabic names
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Question 4 of 4'), findsOneWidget);
      expect(find.text('✓ All questions asked! Ready to vote.'), findsOneWidget);
    });

    testWidgets('QR.6.2: Questioning rounds operate identically in Two Frauds mode (5 players)',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 5, modeTitle: 'Two Frauds', category: 'Animals');
      await passThroughAllPlayers(tester, 5);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));
      expect(find.text('Question 1 of 5'), findsOneWidget);

      final List<int> askers = (state.questionAskers as List<int>);
      final List<int> targets = (state.questionTargets as List<int>);
      expect(askers.length, equals(5));
      expect(targets.length, equals(5));

      // Verify Asker != Responder across all 5 turns
      for (int t = 0; t < 5; t++) {
        expect(askers[t], isNot(equals(targets[t])));
      }

      // Step to final turn
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Question 5 of 5'), findsOneWidget);
      expect(find.text('✓ All questions asked! Ready to vote.'), findsOneWidget);
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
      expect(find.text('Question 3 of 4'), findsOneWidget);

      // Proceed to vote
      await tester.tap(find.text('Vote: who is the fraud?'));
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

        await tester.tap(find.textContaining('Confirm vote'));
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
      expect(find.text('The players in the know win!'), findsOneWidget);
      expect(find.text('Start a new round'), findsOneWidget);

      // Start new round
      await tester.tap(find.text('Start a new round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Pass reveal for Round 2
      await passThroughAllPlayers(tester, 4);

      // Round 2 discussion: questionTurnIdx must be reset to 0 ("Question 1 of 4")
      expect(find.text('Question 1 of 4'), findsOneWidget);
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

      // Defensive fallback must engage: Question 1 of 4 rendered cleanly
      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.text('Player 1 asks Player 2 a question about the secret word.'), findsOneWidget);

      // Verify Asker != Responder under fallback
      expect(find.text('ASKER'), findsOneWidget);
      expect(find.text('RESPONDER'), findsOneWidget);
      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);

      // Verify navigation still functions cleanly under fallback
      await tester.tap(find.text('Next question'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Question 2 of 4'), findsOneWidget);
      expect(find.text('Player 2 asks Player 3 a question about the secret word.'), findsOneWidget);

      // Verify voting transition works cleanly
      await tester.tap(find.text('Vote: who is the fraud?'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));
    });
  });
}
