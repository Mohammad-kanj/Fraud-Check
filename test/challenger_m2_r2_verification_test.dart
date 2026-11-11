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

  /// Helper: Pass reveal for all players and enter discussion
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

  group('M2 Acceptance Criteria 7: Mathematical & Algorithmic Invariants Oracle', () {
    test('16,000 derangement simulations across player counts 3 to 10 strictly satisfy all invariants', () {
      final rng = Random(12345);

      for (int n = 3; n <= 10; n++) {
        final pairFrequencies = <String, int>{};

        for (int iter = 0; iter < 2000; iter++) {
          final pairing = generateRandomQuestioningRound(n, rng);

          // 1. Length invariant
          expect(pairing.askers.length, equals(n),
              reason: 'Asker length must be exactly $n');
          expect(pairing.targets.length, equals(n),
              reason: 'Target length must be exactly $n');

          // 2. Zero self-questioning invariant: A_k != T_k for all k
          for (int k = 0; k < n; k++) {
            expect(pairing.askers[k], isNot(equals(pairing.targets[k])),
                reason: 'Player ${pairing.askers[k]} cannot ask themselves at turn $k (n=$n)');
            final key = '${pairing.askers[k]}->${pairing.targets[k]}';
            pairFrequencies[key] = (pairFrequencies[key] ?? 0) + 1;
          }

          // 3. Every player asks exactly once per round
          final askersSet = pairing.askers.toSet();
          expect(askersSet.length, equals(n),
              reason: 'Every player must ask exactly once in a round (n=$n)');

          // 4. Every player is asked exactly once per round
          final targetsSet = pairing.targets.toSet();
          expect(targetsSet.length, equals(n),
              reason: 'Every player must be asked exactly once in a round (n=$n)');
        }

        // 5. Full directed edge connectivity coverage: all n*(n-1) pairs must occur
        final expectedPairsCount = n * (n - 1);
        expect(pairFrequencies.length, equals(expectedPairsCount),
            reason: 'All $expectedPairsCount directed pairings must occur across 2000 rounds for $n players');
      }
    });

    test('Random variation across rounds: successive derangements are not fixed or deterministic cycles', () {
      final rng = Random(98765);
      const n = 4;
      final distinctRounds = <String>{};

      for (int r = 0; r < 100; r++) {
        final pairing = generateRandomQuestioningRound(n, rng);
        final signature = List.generate(n, (i) => '${pairing.askers[i]}:${pairing.targets[i]}').join(',');
        distinctRounds.add(signature);
      }

      // Out of 100 rounds with 4 players, there are 9 possible derangements * 24 orderings = 216 combinations.
      // We expect significant variety, definitely > 20 distinct round signatures.
      expect(distinctRounds.length, greaterThan(25),
          reason: 'Successive rounds must exhibit random variation rather than repeated deterministic cycles');
    });

    test('Boundary edge cases: n=2 produces valid mutual pairing, n<=1 produces empty safely', () {
      final rng = Random(42);

      // n = 2
      for (int i = 0; i < 20; i++) {
        final pairing2 = generateRandomQuestioningRound(2, rng);
        expect(pairing2.askers.length, equals(2));
        expect(pairing2.targets.length, equals(2));
        expect(pairing2.askers[0], isNot(equals(pairing2.targets[0])));
        expect(pairing2.askers[1], isNot(equals(pairing2.targets[1])));
        expect(pairing2.askers.toSet().length, equals(2));
        expect(pairing2.targets.toSet().length, equals(2));
      }

      // n = 1
      final pairing1 = generateRandomQuestioningRound(1, rng);
      expect(pairing1.askers, isEmpty);
      expect(pairing1.targets, isEmpty);

      // n = 0
      final pairing0 = generateRandomQuestioningRound(0, rng);
      expect(pairing0.askers, isEmpty);
      expect(pairing0.targets, isEmpty);
    });
  });

  group('M2 Acceptance Criteria 1 to 6: Discussion Screen UI & Flow Verification', () {
    testWidgets('Criteria 1: Light box container renders behind "Discuss!" with card2 background preventing blend',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4);
      await passThroughAllPlayers(tester, 4);

      // We are now on Screen.discuss
      final discussTitleFinder = find.text('Discuss!');
      expect(discussTitleFinder, findsOneWidget);

      // Find ancestor Container of 'Discuss!'
      final containerFinder = find.ancestor(
        of: discussTitleFinder,
        matching: find.byType(Container),
      ).first;

      final Container containerWidget = tester.widget<Container>(containerFinder);
      expect(containerWidget.decoration, isA<BoxDecoration>());
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;

      // Assert background color is card2 (Color(0xFF1E2448))
      expect(decoration.color, equals(card2),
          reason: 'Light box behind "Discuss!" must have card2 background color');
      expect(decoration.borderRadius, equals(BorderRadius.circular(16)),
          reason: 'Light box must have rounded corners');
      expect(decoration.border, isNotNull,
          reason: 'Light box must have border styling');
    });

    testWidgets('Criteria 2: Asking player and target player display vertically in separate boxes',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4);
      await passThroughAllPlayers(tester, 4);

      // On Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);

      final asksFinder = find.text('asks');
      expect(asksFinder, findsOneWidget,
          reason: '"asks" connector must be present between vertical boxes');

      // The legacy single-line text format must not exist
      expect(find.textContaining('asks Player'), findsNothing,
          reason: 'Combined horizontal asks text must be replaced with separate boxes');

      // Identify the Asker and Responder boxes
      final defaultPlayers = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
      final playerTextFinders = defaultPlayers
          .map((p) => find.text(p))
          .where((f) => tester.any(f))
          .toList();

      expect(playerTextFinders.length, equals(2),
          reason: 'Exactly two players must be rendered on the questioning card (asker and target)');

      final firstPlayerFinder = playerTextFinders[0];
      final secondPlayerFinder = playerTextFinders[1];

      final firstBox = tester.widget<Container>(find.ancestor(
        of: firstPlayerFinder,
        matching: find.byType(Container),
      ).first);

      final secondBox = tester.widget<Container>(find.ancestor(
        of: secondPlayerFinder,
        matching: find.byType(Container),
      ).first);

      // Both must be inside separate Container boxes with card2 background
      expect((firstBox.decoration as BoxDecoration).color, equals(card2));
      expect((secondBox.decoration as BoxDecoration).color, equals(card2));

      // Check vertical layout geometry:
      final firstPos = tester.getCenter(firstPlayerFinder);
      final asksPos = tester.getCenter(asksFinder);
      final secondPos = tester.getCenter(secondPlayerFinder);

      final topBoxPos = firstPos.dy < secondPos.dy ? firstPos : secondPos;
      final bottomBoxPos = firstPos.dy < secondPos.dy ? secondPos : firstPos;

      // The asking player box is vertically above 'asks' connector, and the target box is vertically below 'asks'
      expect(topBoxPos.dy, lessThan(asksPos.dy),
          reason: 'Top player box (asker) must be positioned vertically above "asks"');
      expect(asksPos.dy, lessThan(bottomBoxPos.dy),
          reason: '"asks" must be positioned vertically above bottom player box (target)');
    });

    testWidgets('Criteria 3: "Previous question" button is completely removed from discussion screen',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4);
      await passThroughAllPlayers(tester, 4);

      // On Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);

      // Verify "Previous question" is NOT found anywhere
      expect(find.text('Previous question'), findsNothing,
          reason: '"Previous question" button text must be removed');
      expect(find.widgetWithText(OutlinedButton, 'Previous question'), findsNothing,
          reason: 'OutlinedButton with "Previous question" must be removed');

      // Verify "Next question" button is present and occupies full width
      final nextBtnFinder = find.widgetWithText(ElevatedButton, 'Next question');
      expect(nextBtnFinder, findsOneWidget);

      final SizedBox parentSizedBox = tester.widget<SizedBox>(
        find.ancestor(of: nextBtnFinder, matching: find.byType(SizedBox)).first,
      );
      expect(parentSizedBox.width, equals(double.infinity),
          reason: '"Next question" button should occupy full width');
    });

    testWidgets('Criteria 4: Three-dots icon for settings/options appears in top-right of discussion screen and opens dialog',
        (WidgetTester tester) async {
      await startRoundWithPlayerCount(tester, targetCount: 4);
      await passThroughAllPlayers(tester, 4);

      // On Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);

      // Verify three-dots options icon exists
      final optionsIconFinder = find.byIcon(Icons.more_vert);
      expect(optionsIconFinder, findsOneWidget,
          reason: 'Three-dots icon (Icons.more_vert) must appear on discussion screen');

      // Verify it is positioned in the top-right corner above "Discuss!"
      final iconCenter = tester.getCenter(optionsIconFinder);
      final discussCenter = tester.getCenter(find.text('Discuss!'));
      expect(iconCenter.dx, greaterThan(discussCenter.dx),
          reason: 'Options icon must be aligned to the right of the title');
      expect(iconCenter.dy, lessThan(tester.getTopLeft(find.text('Discuss!')).dy),
          reason: 'Options icon must be in top bar above "Discuss!"');

      // Tap options icon and verify pass options dialog opens
      await tester.tap(optionsIconFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Restart round'), findsOneWidget);
      expect(find.text('Change players'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap cancel to dismiss dialog and return safely to discussion
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('Criteria 5 & 6: Infinite questioning progression maintains random derangements across rounds',
        (WidgetTester tester) async {
      const playerCount = 4;
      await startRoundWithPlayerCount(tester, targetCount: playerCount);
      await passThroughAllPlayers(tester, playerCount);

      expect(find.text('Discuss!'), findsOneWidget);

      final nextQuestionBtn = find.widgetWithText(ElevatedButton, 'Next question');

      // We will cycle through 12 questions (3 full rounds of 4 questions each)
      final askersSeen = <int, Set<String>>{};
      final targetsSeen = <int, Set<String>>{};

      for (int round = 0; round < 3; round++) {
        askersSeen[round] = <String>{};
        targetsSeen[round] = <String>{};

        for (int q = 0; q < playerCount; q++) {
          final defaultPlayers = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
          final visiblePlayers = defaultPlayers.where((p) => tester.any(find.text(p))).toList();
          expect(visiblePlayers.length, equals(2),
              reason: 'Round $round Question $q: exactly 2 players rendered');

          final asksPos = tester.getCenter(find.text('asks'));
          final p1Pos = tester.getCenter(find.text(visiblePlayers[0]));
          final p2Pos = tester.getCenter(find.text(visiblePlayers[1]));

          final bool p1IsAsker = p1Pos.dy < asksPos.dy;
          expect(p1IsAsker ? p2Pos.dy > asksPos.dy : p2Pos.dy < asksPos.dy, isTrue,
              reason: 'One player must be above "asks" and the other below');

          final String asker = p1IsAsker ? visiblePlayers[0] : visiblePlayers[1];
          final String target = p1IsAsker ? visiblePlayers[1] : visiblePlayers[0];

          // Strict zero self-questioning invariant
          expect(asker, isNot(equals(target)),
              reason: 'Asker and target must never be the same player ($asker asks $target)');

          askersSeen[round]!.add(asker);
          targetsSeen[round]!.add(target);

          // Advance turn
          await tester.tap(nextQuestionBtn);
          await tester.pump(const Duration(milliseconds: 100));
          if (find.text('Another round').evaluate().isNotEmpty) {
            await tester.tap(find.text('Another round'));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        // Verify every player asked at least once in this round
        expect(askersSeen[round]!.length, equals(playerCount),
            reason: 'In round $round, all $playerCount players must ask questions');

        // Verify every player was asked at least once in this round
        expect(targetsSeen[round]!.length, equals(playerCount),
            reason: 'In round $round, all $playerCount players must be asked questions');
      }

      // Verify that questioning can continue indefinitely to Vote
      final voteBtn = find.widgetWithText(ElevatedButton, 'Vote');
      expect(voteBtn, findsOneWidget);
      await tester.tap(voteBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Successfully transitioned to Vote stage
      if (find.text('Pass the phone').evaluate().isNotEmpty) {
        expect(find.text('Pass the phone'), findsOneWidget);
      }
      expect(find.text('Vote 1 of 4'), findsOneWidget);
    });
  });
}
