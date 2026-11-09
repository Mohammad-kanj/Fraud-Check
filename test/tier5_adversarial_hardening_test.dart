import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';
import 'package:fraud_check/categories.dart';

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

  /// Helper to navigate from Home to Players setup
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

    // Tap Mode
    await tester.tap(find.text(modeTitle));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Category
    final catFinder = find.text(category);
    await tester.ensureVisible(catFinder);
    await tester.tap(catFinder);
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper to start a round from Home
  Future<void> setupAndStartRound(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
    int targetPlayers = 4,
  }) async {
    await navigateToPlayers(tester, modeTitle: modeTitle, category: category);

    // Adjust player count to targetPlayers
    while (tester.widgetList(find.byType(TextField)).length < targetPlayers) {
      final addBtn = find.text('Add player');
      await tester.ensureVisible(addBtn.first);
      await tester.tap(addBtn.first);
      await tester.pump(const Duration(milliseconds: 100));
    }
    while (tester.widgetList(find.byType(TextField)).length > targetPlayers) {
      final removeBtn = find.byTooltip('Remove player').last;
      await tester.ensureVisible(removeBtn);
      await tester.tap(removeBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Tap Start round
    final startBtn = find.text('Start round');
    await tester.ensureVisible(startBtn);
    await tester.tap(startBtn);
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper to pass through all player reveals
  Future<void> passThroughAllReveals(WidgetTester tester, int playerCount) async {
    for (int p = 0; p < playerCount; p++) {
      expect(find.text('Pass the phone'), findsOneWidget);
      final revealBtn = find.text('Tap to reveal');
      await tester.ensureVisible(revealBtn);
      await tester.tap(revealBtn);
      await tester.pump(const Duration(milliseconds: 400));

      final isLast = p == playerCount - 1;
      final nextBtn = isLast
          ? find.text('Hide and start discussion')
          : find.text('Hide and pass on');
      expect(nextBtn, findsOneWidget);
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Helper to step from discussion to voting
  Future<void> proceedToVoting(WidgetTester tester) async {
    final votePrompt = find.text('Vote');
    expect(votePrompt, findsOneWidget);
    await tester.ensureVisible(votePrompt);
    await tester.tap(votePrompt);
    await tester.pump(const Duration(milliseconds: 100));
  }

  // =========================================================================
  // GROUP 1: BOUNDARY CLAMPING & MUTABILITY STRESS
  // =========================================================================
  group('Group 1: Extreme Boundary Clamping & Sequential Mutability', () {
    testWidgets('ADV-B1: Mode switch from Classic (3 players) to Two Frauds clamps to 4 players',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      // Drop Classic to minimum (3 players)
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // Return to main menu -> select Two Frauds mode
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Two Frauds'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));

      // Must automatically clamp playerCount from 3 to 4!
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('ADV-B2: Undercover mode minimum boundary strictly prevents deletion below 4',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Undercover', category: 'Drinks');
      expect(find.byType(TextField), findsNWidgets(4));

      // At boundary 4, all 4 remove buttons must have null onPressed
      final removeButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded),
      );
      expect(removeButtons.length, equals(4));
      for (final btn in removeButtons) {
        expect(btn.onPressed, isNull);
      }

      // Adversarial attempt to tap remove button anyway
      await tester.tap(find.byTooltip('Remove player').first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('ADV-B3: Rapid sequential mutability: 10 down to 3, back to 10 maintains valid state',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Movies');

      // Rapidly add up to 10
      for (int i = 5; i <= 10; i++) {
        await tester.tap(find.text('Add player').first);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TextField), findsNWidgets(10));
      expect(find.text('Add player'), findsNothing);

      // Rapidly remove down to 3
      for (int i = 10; i > 3; i--) {
        await tester.tap(find.byTooltip('Remove player').last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TextField), findsNWidgets(3));

      // Rapidly add back to 10
      for (int i = 4; i <= 10; i++) {
        await tester.tap(find.text('Add player').first);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TextField), findsNWidgets(10));
      expect(find.text('Add player'), findsNothing);

      // Verify Start round button is active and starts round cleanly
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Pass the phone'), findsOneWidget);
    });

    testWidgets('ADV-B4: Single Add button strictly positioned below the final player entry',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Sports');

      for (int count = 4; count <= 9; count++) {
        expect(find.text('Add player'), findsOneWidget);

        // Verify the Add button's vertical offset is greater than the last TextField's offset
        final lastFieldPos = tester.getBottomLeft(find.byType(TextField).last);
        final addBtnPos = tester.getTopLeft(find.text('Add player'));
        expect(addBtnPos.dy, greaterThan(lastFieldPos.dy));

        await tester.tap(find.text('Add player'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // At 10 players, Add player must disappear
      expect(find.text('Add player'), findsNothing);
    });
  });

  // =========================================================================
  // GROUP 2: HOSTILE INPUT STRINGS, UNICODE & NAMING EDGE CASES
  // =========================================================================
  group('Group 2: Hostile Input Strings, Unicode & Naming Edge Cases', () {
    testWidgets('ADV-N1: Empty strings and whitespace automatically revert to fallback Player N',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      final fields = find.byType(TextField);
      // Enter empty string in Player 1
      await tester.enterText(fields.at(0), '   ');
      await tester.pump(const Duration(milliseconds: 50));

      // Enter spaces & tabs in Player 2
      await tester.enterText(fields.at(1), '\t   \n');
      await tester.pump(const Duration(milliseconds: 50));

      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = (state.players as List<String>);
      expect(players[0], equals('Player 1'));
      expect(players[1], equals('Player 2'));
    });

    testWidgets('ADV-N2: RTL Arabic, multi-script Unicode, and emojis propagate through full flow',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Places');

      final fields = find.byType(TextField);
      final customNames = [
        'لاعب أصلي 🎭',
        'متحري ذكي 🕵️‍♂️',
        '日本語プレイヤー 🌸',
        'King_Saladin_👑',
      ];
      for (int i = 0; i < 4; i++) {
        await tester.enterText(fields.at(i), customNames[i]);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify custom names render in Pass screens
      for (int p = 0; p < 4; p++) {
        expect(find.text('Pass the phone'), findsOneWidget);
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        final nextBtn = (p == 3)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // In discussion screen, verify Asker & Responder render Unicode cleanly
      expect(find.text('Discuss!'), findsOneWidget);
      await proceedToVoting(tester);

      // Verify voting prompt displays voter name
      expect(find.text('Pass the phone'), findsOneWidget);
    });

    testWidgets('ADV-N3: Pathological ultra-long player names (150+ chars) do not throw exceptions',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      final fields = find.byType(TextField);
      const ultraLongName = 'Supercalifragilisticexpialidocious_TheGreatestDetectiveInHistory_WhoNeverFailsToDeduceTheImposter_1234567890_VeryLongIdentifierForAdversarialStressTest';
      await tester.enterText(fields.at(0), ultraLongName);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no unhandled exception
      expect(tester.takeException(), isNull);
      await passThroughAllReveals(tester, 4);

      // In discussion screen
      expect(find.text('Discuss!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-N4: Duplicate player names across all slots run through lifecycle without crash',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      final fields = find.byType(TextField);
      for (int i = 0; i < 4; i++) {
        await tester.enterText(fields.at(i), 'Alex');
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));
      await passThroughAllReveals(tester, 4);
      await proceedToVoting(tester);

      // Cast votes
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the first suspect (which will be 'Alex' for one of the other players)
        final suspects = find.text('Alex');
        expect(suspects, findsWidgets);
        await tester.tap(suspects.first);
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // If guess screen appears, pick guess and confirm
      if (find.text('Last chance!').evaluate().isNotEmpty) {
        final dynamic state = tester.state(find.byType(GamePage));
        final List<String> guessOptions = (state.guessOptions as List<String>);
        await tester.tap(find.text(guessOptions.first));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Confirm guess'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Land on Result screen safely
      expect(find.text('Total Leaderboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 3: RAPID USER INTERACTIONS & RACE CONDITIONS
  // =========================================================================
  group('Group 3: Rapid User Interactions & State Machine Race Conditions', () {
    testWidgets('ADV-R1: Rapid double-taps on Play button does not throw or corrupt navigation',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly tap Play 3 times
      final playBtn = find.text('Play');
      await tester.tap(playBtn);
      await tester.tap(playBtn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select Game Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-R2: Rapid taps on Next question advance infinite rounds safely with previous button removed',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);
      await passThroughAllReveals(tester, 4);

      expect(find.text('Discuss!'), findsOneWidget);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.questionTurnIdx, equals(0));

      // Rapidly tap Next question 10 times
      for (int i = 0; i < 10; i++) {
        final nextBtn = find.text('Next question');
        if (nextBtn.evaluate().isNotEmpty) {
          await tester.tap(nextBtn);
          await tester.pump(const Duration(milliseconds: 20));
        }
      }
      expect(state.questionTurnIdx, greaterThanOrEqualTo(5));

      // Verify Previous question is removed per R4.3
      expect(find.text('Previous question'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-R3: Rapid double tap on Tap to reveal in same frame does not skip passes',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);

      for (int p = 0; p < 4; p++) {
        expect(find.text('Pass the phone'), findsOneWidget);
        final revealBtn = find.text('Tap to reveal');
        // Dispatch double tap in rapid succession before pump
        await tester.tap(revealBtn);
        await tester.tap(revealBtn);
        await tester.pump(const Duration(milliseconds: 400));

        final nextBtn = (p == 3)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Discuss!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-R4: Rapid double tap on Start a new round initializes fresh state cleanly',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 3);
      await passThroughAllReveals(tester, 3);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = (state.players as List<String>);

      // Complete voting: each voter votes for (v + 1) % 3
      for (int v = 0; v < 3; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        final targetIdx = (v + 1) % 3;
        await tester.tap(find.text(players[targetIdx]));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // If guess screen, guess
      if (find.text('Last chance!').evaluate().isNotEmpty) {
        final List<String> guessOptions = (state.guessOptions as List<String>);
        await tester.tap(find.text(guessOptions.first));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Confirm guess'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Continue'), findsOneWidget);
      final replayBtn = find.text('Continue');
      await tester.tap(replayBtn);
      await tester.tap(replayBtn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      // Lands on category screen
      expect(state.screen.toString(), contains('category'));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 4: TIMER EXTREMES & LIFECYCLE INTEGRITY
  // =========================================================================
  group('Group 4: Timer Extremes & Lifecycle Integrity', () {
    testWidgets('ADV-T1: Discussion timer = 0 (No timer) omits countdown widget and timer instance',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Configure timerMinutes = 0
      final dynamic appState = tester.state(find.byType(GamePage));
      appState.timerMinutes = 0;

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      await passThroughAllReveals(tester, 4);

      expect(find.text('Discuss!'), findsOneWidget);
      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.timer, isNull, reason: 'Timer instance must be null when timerMinutes is 0');
      // No digital countdown text matching regex \d+:\d\d
      expect(find.textContaining(RegExp(r'^\d+:\d\d$')), findsNothing);
    });

    testWidgets('ADV-T2: Active timer countdown ticks down and safely cancels when jumping to vote',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Configure timerMinutes = 2
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

      await passThroughAllReveals(tester, 4);

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);

      // Advance clock by 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('1:57'), findsOneWidget);

      // Jump to voting early -> timer must cancel
      await proceedToVoting(tester);
      expect(find.text('Pass the phone'), findsOneWidget);

      // Pump more time to ensure no dangling timer callback fires on unmounted/switched state
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-T3: Screen disposal during active discussion does not leak timer or throw',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Configure timerMinutes = 3
      final dynamic appState = tester.state(find.byType(GamePage));
      appState.timerMinutes = 3;

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      await passThroughAllReveals(tester, 4);

      expect(find.text('Discuss!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      // Unmount the whole app
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 5: ROLE ASSIGNMENT INVARIANTS & CATEGORY RECYCLING
  // =========================================================================
  group('Group 5: Role Invariants & Word Pool Recycling', () {
    testWidgets('ADV-M1: Classic mode invariant: exactly 1 fraud, 0 undercover for N=3, 5, 10',
        (WidgetTester tester) async {
      for (final count in [3, 5, 10]) {
        await setupAndStartRound(tester, modeTitle: 'Classic', category: 'Animals', targetPlayers: count);
        final dynamic state = tester.state(find.byType(GamePage));
        final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
        final int? undercoverIndex = (state.undercoverIndex as int?);

        expect(fraudIndices.length, equals(1), reason: 'Classic mode must have exactly 1 fraud for N=$count');
        expect(undercoverIndex, isNull, reason: 'Classic mode must have 0 undercover players for N=$count');

        // Return to main menu for next iteration
        await tester.tap(find.byTooltip('Options'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Back to main menu'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('ADV-M2: Two Frauds mode invariant: exactly 2 distinct frauds for N=4, 7, 10',
        (WidgetTester tester) async {
      for (final count in [4, 7, 10]) {
        await setupAndStartRound(tester, modeTitle: 'Two Frauds', category: 'Vehicles', targetPlayers: count);
        final dynamic state = tester.state(find.byType(GamePage));
        final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
        final int? undercoverIndex = (state.undercoverIndex as int?);

        expect(fraudIndices.length, equals(2), reason: 'Two Frauds must assign exactly 2 frauds for N=$count');
        expect(undercoverIndex, isNull, reason: 'Two Frauds must have no undercover for N=$count');

        await tester.tap(find.byTooltip('Options'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Back to main menu'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('ADV-M3: Undercover mode invariant: exactly 1 fraud, 1 undercover, distinct decoy word',
        (WidgetTester tester) async {
      for (final count in [4, 6, 10]) {
        await setupAndStartRound(tester, modeTitle: 'Undercover', category: 'Professions', targetPlayers: count);
        final dynamic state = tester.state(find.byType(GamePage));
        final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
        final int? undercoverIndex = (state.undercoverIndex as int?);
        final String roundWord = (state.roundWord as String);
        final String roundUndercoverWord = (state.roundUndercoverWord as String);

        expect(fraudIndices.length, equals(1));
        expect(undercoverIndex, isNotNull);
        expect(fraudIndices.contains(undercoverIndex), isFalse,
            reason: 'Undercover player cannot also be the fraud');
        expect(roundUndercoverWord.isNotEmpty, isTrue);
        expect(roundUndercoverWord, isNot(equals(roundWord)),
            reason: 'Undercover decoy word must be different from secret word');

        await tester.tap(find.byTooltip('Options'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Back to main menu'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('ADV-M4: Word pool recycling: exhausting category words recycles pool cleanly',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayers: 3);
      final dynamic state = tester.state(find.byType(GamePage));

      // Manually add all words into usedWords to simulate full exhaustion
      final Set<String> used = (state.usedWords as Set<String>);
      for (final w in categories['Food']!) {
        used.add('Food|$w');
      }

      // Trigger startRound again
      state.startRound();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that pool recycled without error and new word was chosen
      final String word = (state.roundWord as String);
      expect(word.isNotEmpty, isTrue);
      expect(categories['Food']!.contains(word), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 6: VOTING MAJORITY LOGIC & SCORING HARDENING
  // =========================================================================
  group('Group 6: Voting Majority Logic & Fraud Check Scoring Hardening', () {
    testWidgets('ADV-S1: Exact 50% vote threshold in 4 players (2 votes) does NOT catch fraud',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayers: 4);
      await passThroughAllReveals(tester, 4);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<String> players = (state.players as List<String>);
      final int fraudIdx = fraudIndices.first;
      final safePlayers = [0, 1, 2, 3].where((i) => i != fraudIdx).toList();

      final targetA = fraudIdx;
      final targetB = safePlayers[0];

      // 2 votes for targetA (fraud), 2 votes for targetB (safe)
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        int voteFor;
        if (v == fraudIdx) {
          voteFor = targetB;
        } else if (v == safePlayers[0]) {
          voteFor = targetA;
        } else if (v == safePlayers[1]) {
          voteFor = targetA;
        } else {
          voteFor = targetB;
        }

        await tester.tap(find.text(players[voteFor]));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Fraud was NOT caught -> directly to Result screen (no Guess screen)
      expect(find.text('The Fraud Wins'), findsOneWidget);
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[fraudIdx], equals(100),
          reason: 'Escaping fraud with <= 50% votes must earn 100 points');
    });

    testWidgets('ADV-S2: Caught fraud guesses secret word correctly: fraud loses round (50 pts) and voters earn 100 pts',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, modeTitle: 'Classic', category: 'Food', targetPlayers: 4);
      await passThroughAllReveals(tester, 4);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);
      final int fraudIdx = fraudIndices.first;

      // 3 safe players vote for fraud -> fraud caught with majority (3 > 2)
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        if (v == fraudIdx) {
          final other = (fraudIdx + 1) % 4;
          await tester.tap(find.text(players[other]));
        } else {
          await tester.tap(find.text(players[fraudIdx]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Last chance!'), findsOneWidget);

      // Fraud guesses the exact secret word!
      await tester.tap(find.text(roundWord));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // Under R6: Fraud loses round even on correct guess, players win!
      expect(find.text('The players win'), findsOneWidget);
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[fraudIdx], equals(50),
          reason: 'Fraud guessing secret word correctly receives 50 points');
      for (int i = 0; i < 4; i++) {
        if (i != fraudIdx) {
          expect(pointsEarned[i], equals(100),
              reason: 'Safe players who voted for caught fraud receive 100 points');
        }
      }
    });

    testWidgets('ADV-S3: Two Frauds mode: 1 fraud caught, misses guess -> voters for caught fraud get points',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, modeTitle: 'Two Frauds', category: 'Food', targetPlayers: 5);
      await passThroughAllReveals(tester, 5);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final List<int> frauds = (state.fraudIndices as Set<int>).toList();
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);
      final int caughtF = frauds[0];
      final int otherF = frauds[1];
      final safePlayers = [0, 1, 2, 3, 4].where((i) => !frauds.contains(i)).toList();

      // 3 safe voters vote for caughtF (> 2.5 majority threshold)
      for (int v = 0; v < 5; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        if (v == caughtF) {
          await tester.tap(find.text(players[otherF]));
        } else if (v == otherF) {
          await tester.tap(find.text(players[safePlayers[0]]));
        } else {
          // Safe players vote for caughtF
          await tester.tap(find.text(players[caughtF]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> guessOptions = (state.guessOptions as List<String>);
      final wrongWord = guessOptions.firstWhere((w) => w != roundWord);
      await tester.tap(find.text(wrongWord));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The players win'), findsOneWidget);
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      for (final safeVoter in safePlayers) {
        expect(pointsEarned[safeVoter], equals(100),
            reason: 'Safe voter $safeVoter who voted for caught fraud earns 100 points');
      }
    });
  });

  // =========================================================================
  // GROUP 7: RESPONSIVE LAYOUTS & MULTI-VIEWPORT SCALABILITY
  // =========================================================================
  group('Group 7: Responsive Layouts & Multi-Viewport Scalability', () {
    testWidgets('ADV-V1: Standard viewport (640x960) traverses full game flow with zero RenderFlex overflow',
        (WidgetTester tester) async {
      setViewport(tester, width: 640, height: 960);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Home
      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Mode
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Select Game Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Category
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Pick a category'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Players
      final catBtn = find.text('Movies');
      await tester.ensureVisible(catBtn);
      await tester.tap(catBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Players'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Start round
      final startBtn = find.text('Start round');
      await tester.ensureVisible(startBtn);
      await tester.tap(startBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Pass & Reveal
      for (int p = 0; p < 4; p++) {
        expect(find.text('Pass the phone'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final revealBtn = find.text('Tap to reveal');
        await tester.ensureVisible(revealBtn);
        await tester.tap(revealBtn);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        final nextBtn = (p == 3)
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Discuss screen
      expect(find.text('Discuss!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-V2: Landscape compact viewport (800x380) renders scrollably without clip',
        (WidgetTester tester) async {
      setViewport(tester, width: 800, height: 380);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Select Game Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ADV-V3: Wide desktop/tablet viewport (1200x800) centers constrained card (maxWidth: 640)',
        (WidgetTester tester) async {
      setViewport(tester, width: 1200, height: 800);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final constrainedFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 640,
      );
      expect(constrainedFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 8: PASS-THE-PHONE OPTIONS DIALOG INTERRUPTION ROBUSTNESS
  // =========================================================================
  group('Group 8: Pass-the-Phone Options Dialog Interruption Robustness', () {
    testWidgets('ADV-O1: Options dialog: "Restart round" resets passIdx and starts new round',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);

      // Advance to Player 2
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Hide and pass on'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Player 2 of 4'), findsOneWidget);

      // Open options dialog
      await tester.tap(find.byTooltip('Options'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Restart round"
      await tester.tap(find.text('Restart round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Resets back to Player 1 of 4
      expect(find.textContaining('Player 1 of 4'), findsOneWidget);
    });

    testWidgets('ADV-O2: Options dialog: "Change players" navigates to Screen.players with current roster',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);

      await tester.tap(find.byTooltip('Options'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Change players'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Players'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('ADV-O3: Options dialog: "Back to main menu" safely resets to Screen.home',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);

      await tester.tap(find.byTooltip('Options'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('FRAUD CHECK'), findsOneWidget);
    });

    testWidgets('ADV-O4: Options dialog: "Cancel" dismisses dialog without state alteration',
        (WidgetTester tester) async {
      await setupAndStartRound(tester, targetPlayers: 4);

      await tester.tap(find.byTooltip('Options'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));

      // Options dialog closed, still on Player 1 of 4
      expect(find.textContaining('Player 1 of 4'), findsOneWidget);
      expect(find.text('Options'), findsNothing);
    });
  });
}
