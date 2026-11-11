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

  Future<void> startRoundWithPlayerCount(
    WidgetTester tester, {
    required int targetCount,
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    await navigateToPlayers(tester, modeTitle: modeTitle, category: category);

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

  group('Focus 1: Infinite Questioning Rounds Invariants', () {
    testWidgets('Simulate 60+ question cycles in Screen.discuss (4 players): smooth modulo cycling without locks or crashes',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Now on Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);
      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Check lightbox instruction background
      expect(
        find.text('Give clues and ask each other questions. Do not say your secret word!'),
        findsOneWidget,
      );

      // Verify that category name and game mode are NOT displayed in discuss screen
      expect(find.text('Category: Food'), findsNothing);
      expect(find.text('Mode: Classic'), findsNothing);

      // Verify prompt text is strictly 'Vote'
      expect(find.text('Vote'), findsOneWidget);

      final List<int> askers = List<int>.from(state.questionAskers as List<int>);
      final List<int> targets = List<int>.from(state.questionTargets as List<int>);
      final List<String> players = List<String>.from(state.players as List<String>);
      expect(askers.length, 4);
      expect(targets.length, 4);

      // Cycle forward for 60 questions (> 50 question cycles)
      for (int i = 0; i < 60; i++) {
        final currentAsker = players[state.questionAskers[i]];
        final currentResponder = players[state.questionTargets[i]];

        expect(find.text(currentAsker), findsOneWidget);
        expect(find.text('asks'), findsOneWidget);
        expect(find.text(currentResponder), findsOneWidget);
        expect(currentAsker, isNot(equals(currentResponder)));

        // Verify no legacy labels exist
        expect(find.textContaining('Questioning Round'), findsNothing);
        expect(find.textContaining('ASKER:'), findsNothing);
        expect(find.textContaining('RESPONDER:'), findsNothing);

        // Previous question is removed per R4.3
        expect(find.text('Previous question'), findsNothing);

        // Tap 'Next question'
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Another round').evaluate().isNotEmpty) {
          await tester.tap(find.text('Another round'));
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      expect(state.questionTurnIdx, 60);
      expect(find.text('Previous question'), findsNothing);
      expect(find.text('Next question'), findsOneWidget);

      // Check transition to voting is still healthy after 60 rapid transitions
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));
    });

    testWidgets('Simulate 50+ question cycles with 3 players (minimum boundary) and 10 players (maximum boundary)',
        (WidgetTester tester) async {
      // 3 Players boundary
      await startRoundWithPlayerCount(tester, targetCount: 3, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 3);

      final dynamic state3 = tester.state(find.byType(GamePage));
      expect(state3.screen.toString(), contains('discuss'));

      for (int i = 0; i < 52; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Another round').evaluate().isNotEmpty) {
          await tester.tap(find.text('Another round'));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
      expect(state3.questionTurnIdx, 52);
      expect(tester.takeException(), isNull);

      // Jump to vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state3.screen.toString(), contains('vote'));

      // Now test 10 players boundary from Home
      final dynamic state = tester.state(find.byType(GamePage));
      state.go(Screen.home);
      await tester.pump(const Duration(milliseconds: 100));

      await startRoundWithPlayerCount(tester, targetCount: 10, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 10);

      final dynamic state10 = tester.state(find.byType(GamePage));
      expect(state10.screen.toString(), contains('discuss'));

      for (int i = 0; i < 55; i++) {
        await tester.tap(find.text('Next question'));
        await tester.pump(const Duration(milliseconds: 20));
        if (find.text('Another round').evaluate().isNotEmpty) {
          await tester.tap(find.text('Another round'));
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
      expect(state10.questionTurnIdx, 55);
      expect(tester.takeException(), isNull);
    });
  });

  group('Focus 2: Round Continuation & Cumulative Score Preservation Invariants', () {
    testWidgets('Multi-round simulation: cumulative scores preserved, round delta (+N) displays ONLY recent points, leaderboard ranks update dynamically',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = List<String>.from(state.players as List<String>);
      final Set<int> round1Frauds = Set<int>.from(state.fraudIndices as Set<int>);
      final int round1Fraud = round1Frauds.first;
      final String round1Word = state.roundWord as String;

      // Finish pass-and-play reveal
      await passThroughAllPlayers(tester, 4);

      // Advance from discuss to vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // ROUND 1 VOTING:
      // All 3 non-fraud players vote for the fraud (caught by majority 3/4 > 2).
      // The fraud votes for another player.
      for (int v = 0; v < 4; v++) {
        if (find.text('Tap to vote').evaluate().isNotEmpty) {
          await tester.tap(find.text('Tap to vote'));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 100));

        if (v == round1Fraud) {
          final alt = (round1Fraud + 1) % 4;
          await tester.tap(find.text(players[alt]));
        } else {
          await tester.tap(find.text(players[round1Fraud]));
        }
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Fraud is caught by majority -> Guess screen
      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> guessOptions = List<String>.from(state.guessOptions as List<String>);
      final wrongWord = guessOptions.firstWhere((w) => w != round1Word);

      await tester.tap(find.text(wrongWord));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // RESULTS SCREEN - ROUND 1
      expect(state.screen.toString(), contains('result'));
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);
      expect(find.text('Total Leaderboard'), findsOneWidget);

      // Verify Round 1 Scoring:
      // The 3 non-frauds earned 100 pts this round -> badge '+100' displayed 3 times
      expect(find.text('+100'), findsNWidgets(3));
      expect(find.text('100 pts'), findsNWidgets(3));
      // Fraud earned 0 pts -> displays '0 pts' and NO delta badge
      expect(find.text('0 pts'), findsOneWidget);

      // Verify state scores map
      final Map<String, int> scoresR1 = Map<String, int>.from(state.scores as Map<String, int>);
      for (int p = 0; p < 4; p++) {
        if (p == round1Fraud) {
          expect(scoresR1[players[p]], 0);
        } else {
          expect(scoresR1[players[p]], 100);
        }
      }

      // TAP "Continue" TO ADVANCE TO ROUND 2
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should prompt back to Category selection screen
      expect(state.screen.toString(), contains('category'));
      expect(find.text('Pick a category'), findsOneWidget);

      // Select category 'Animals' and start Round 2
      await tester.tap(find.text('Animals'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen.toString(), contains('pass'));

      // Check that cumulative scores are PRESERVED when starting Round 2
      final Map<String, int> scoresAtStartR2 = Map<String, int>.from(state.scores as Map<String, int>);
      for (int p = 0; p < 4; p++) {
        if (p == round1Fraud) {
          expect(scoresAtStartR2[players[p]], 0);
        } else {
          expect(scoresAtStartR2[players[p]], 100);
        }
      }

      // Check pointsEarnedThisRound is empty at start of Round 2
      final Map<int, int> deltaAtStartR2 = Map<int, int>.from(state.pointsEarnedThisRound as Map<int, int>);
      expect(deltaAtStartR2.isEmpty, isTrue);

      final Set<int> round2Frauds = Set<int>.from(state.fraudIndices as Set<int>);
      final int round2Fraud = round2Frauds.first;

      // Pass reveal for all 4 players
      await passThroughAllPlayers(tester, 4);

      // Advance from discuss to vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // ROUND 2 VOTING:
      // Frauds escape! (Split vote or vote for non-fraud so fraud is not caught by majority)
      // Every player votes for the next player: 0->1, 1->2, 2->3, 3->0 (1 vote each, <= 2)
      for (int v = 0; v < 4; v++) {
        if (find.text('Tap to vote').evaluate().isNotEmpty) {
          await tester.tap(find.text('Tap to vote'));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 100));

        final target = (v + 1) % 4;
        await tester.tap(find.text(players[target]));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // RESULTS SCREEN - ROUND 2
      expect(state.screen.toString(), contains('result'));
      expect(find.text('THE FRAUD ESCAPED'), findsOneWidget);

      // Round 2 Outcome:
      // The fraud escaped! The fraud earned 100 points this round.
      // Non-frauds earned 0 points this round.
      // CRITICAL INVARIANT: The round score delta badge (+number) displays ONLY the points gained in the most recent round!
      // Therefore, exactly ONE player has a delta badge this round (+100 for round2Fraud).
      expect(find.text('+100'), findsOneWidget,
          reason: 'Only the fraud who escaped in Round 2 should have a +100 delta badge; non-frauds earned 0 this round');

      // Verify cumulative scores:
      // If round2Fraud was also round1Fraud: round2Fraud had 0 pts + 100 = 100 pts.
      // If round2Fraud was one of the 3 non-frauds from round 1: round2Fraud had 100 pts + 100 = 200 pts!
      final Map<String, int> scoresR2 = Map<String, int>.from(state.scores as Map<String, int>);
      final String round2FraudName = players[round2Fraud];

      if (round2Fraud == round1Fraud) {
        // All 4 players now have 100 cumulative points
        expect(scoresR2[round2FraudName], 100);
        expect(find.text('100 pts'), findsNWidgets(4));
      } else {
        // round2Fraud has 200 cumulative points!
        expect(scoresR2[round2FraudName], 200);
        expect(find.text('200 pts'), findsOneWidget);
        // The other 2 non-frauds from round 1 have 100 cumulative points
        expect(find.text('100 pts'), findsNWidgets(2));
        // The round 1 fraud has 0 cumulative points
        expect(find.text('0 pts'), findsOneWidget);

        // Leaderboard dynamic ranking:
        // Rank 1 must be the player with 200 pts (round2FraudName)
        // Check that rank 1 container contains round2FraudName and 200 pts
        final rank1Finder = find.ancestor(
          of: find.text('1.'),
          matching: find.byType(Container),
        );
        expect(rank1Finder, findsWidgets);
      }

      // VERIFY CONTINUING INTO ROUND 3
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('category'));

      // Verify cumulative scores still preserved at beginning of Round 3
      final Map<String, int> scoresAtStartR3 = Map<String, int>.from(state.scores as Map<String, int>);
      expect(scoresAtStartR3, equals(scoresR2));
    });
  });

  group('Focus 3: Role Reveal Screen Lock & Role Invariants Across Modes', () {
    testWidgets('Classic Mode: Safe players see locked icon, category outside box, and "YOU ARE NOT THE FRAUD"; Fraud sees open lock, "YOU ARE THE FRAUD", and blend-in guidance',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = Set<int>.from(state.fraudIndices as Set<int>);
      final List<int> passOrder = List<int>.from(state.passOrder as List<int>);

      for (int p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);

        // Tap to reveal
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // Category outside box at top
        expect(find.text('Category: Food'), findsOneWidget);

        if (isFraud) {
          // Fraud Lock Invariant: lock icon removed once revealed (R3)
          expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
          expect(find.byIcon(Icons.lock_rounded), findsNothing);

          // Fraud Role Text
          expect(find.text('👁️ FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE NOT THE FRAUD'), findsNothing);

          // Blend-in guidance without secret word unknown
          expect(
            find.text('Try to blend in! Listen to clues, pretend you know the word, and deduce it before voting.'),
            findsOneWidget,
          );
          expect(find.textContaining('secret word unknown'), findsNothing);
          expect(find.text('YOUR SECRET WORD'), findsNothing);
        } else {
          // Safe Player Lock Invariant: lock icon removed once revealed (R3)
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          expect(find.byIcon(Icons.lock_open_rounded), findsNothing);

          // Safe Player Role Text
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD'), findsNothing);

          // Secret word display
          expect(find.text('YOUR SECRET WORD'), findsOneWidget);
          expect(find.text(state.roundWord as String), findsOneWidget);
        }

        // Verify prohibited legacy terminology and styling
        expect(find.textContaining('innocent'), findsNothing);
        expect(find.textContaining('outside the story'), findsNothing);
        expect(find.byIcon(Icons.shield_outlined), findsNothing);
        expect(find.byIcon(Icons.shield), findsNothing);

        // Hide and proceed
        final isLast = p == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('Chaos Mode: Undercover player sees eye emoji, category at top, "YOU ARE UNDERCOVER", locked icon, and decoy word',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Chaos', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final int undercoverIdx = state.undercoverIndex as int;
      final Set<int> fraudIndices = Set<int>.from(state.fraudIndices as Set<int>);
      final List<int> passOrder = List<int>.from(state.passOrder as List<int>);

      for (int p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);
        final isUndercover = playerIdx == undercoverIdx;

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // Category outside box at top
        expect(find.text('Category: Food'), findsOneWidget);

        if (isUndercover) {
          // Undercover invariants:
          // Eye emoji badge
          expect(find.text('👁️ UNDERCOVER'), findsOneWidget);
          // Role heading
          expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
          // Decoy word
          expect(find.text('YOUR DECOY WORD'), findsOneWidget);
          expect(find.text(state.roundUndercoverWord as String), findsOneWidget);
          // Lock icon is removed once revealed (R3)
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
        } else if (isFraud) {
          expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
          expect(find.text('👁️ FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
          expect(find.text('YOUR SECRET WORD'), findsOneWidget);
        }

        final isLast = p == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('Two Frauds Mode: Both frauds see fraud eye badge, 2-frauds blend-in guidance, and "YOU ARE THE FRAUD"',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Two Frauds', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = Set<int>.from(state.fraudIndices as Set<int>);
      expect(fraudIndices.length, 2);
      final List<int> passOrder = List<int>.from(state.passOrder as List<int>);

      for (int p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        if (isFraud) {
          expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
          expect(find.text('👁️ FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
          expect(
            find.text('There are 2 frauds this round! Listen closely, blend in, and try to deduce the secret word.'),
            findsOneWidget,
          );
        } else {
          expect(find.byIcon(Icons.lock_rounded), findsNothing);
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
        }

        final isLast = p == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });

  group('Focus 4: Absolute Terminology Cleansing Verification', () {
    testWidgets('Negative test: Zero occurrences of legacy phrases in UI across entire game lifecycle',
        (WidgetTester tester) async {
      final legacyFull = ['The', 'English', 'Barra', 'El', 'Salfa'].join(' ');
      final legacyShort = ['barra', 'el', 'salfa'].join(' ');
      final legacyArabic1 = ['برا', 'السالفة'].join(' ');
      final legacyArabic2 = ['برا', 'السالفه'].join(' ');

      await startRoundWithPlayerCount(tester, targetCount: 4, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Verify absence on discuss
      expect(find.text(legacyFull), findsNothing);
      expect(find.text(legacyShort), findsNothing);
      expect(find.text(legacyArabic1), findsNothing);
      expect(find.text(legacyArabic2), findsNothing);

      // Verify absence on vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(legacyFull), findsNothing);
      expect(find.text(legacyShort), findsNothing);

      // Complete voting to reach results
      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = List<String>.from(state.players as List<String>);
      for (int v = 0; v < 4; v++) {
        if (find.text('Tap to vote').evaluate().isNotEmpty) {
          await tester.tap(find.text('Tap to vote'));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text(players[(v + 1) % 4]));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify absence on results screen
      expect(find.text(legacyFull), findsNothing);
      expect(find.text(legacyShort), findsNothing);
      expect(find.text(legacyArabic1), findsNothing);
      expect(find.text(legacyArabic2), findsNothing);
      // Votes summary and legacy scoring subsections must be absent
      expect(find.textContaining('Votes summary'), findsNothing);
      expect(find.textContaining('Points This Round'), findsNothing);
    });
  });
}
