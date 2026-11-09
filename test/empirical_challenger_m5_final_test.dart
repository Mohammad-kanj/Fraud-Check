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

  group('CHALLENGER STRESS: Questioning Derangement Engine Invariant Proofs', () {
    test('CH-Q1: 10,000 Monte Carlo derangement iterations across N in [3..10] strictly adhere to derangement axioms', () {
      final rng = Random(42);
      for (int n = 3; n <= 10; n++) {
        for (int iter = 0; iter < 1000; iter++) {
          final pairing = generateRandomQuestioningRound(n, rng);
          expect(pairing.askers.length, equals(n));
          expect(pairing.targets.length, equals(n));

          // Axiom 1: All players ask exactly once
          final askersSet = pairing.askers.toSet();
          expect(askersSet.length, equals(n), reason: 'All N players must ask once at iteration $iter for N=$n');
          for (int p = 0; p < n; p++) {
            expect(askersSet.contains(p), isTrue);
          }

          // Axiom 2: All players are asked exactly once
          final targetsSet = pairing.targets.toSet();
          expect(targetsSet.length, equals(n), reason: 'All N players must be asked once at iteration $iter for N=$n');
          for (int p = 0; p < n; p++) {
            expect(targetsSet.contains(p), isTrue);
          }

          // Axiom 3: Strictly no self-asking (A_k != T_k for all k)
          for (int k = 0; k < n; k++) {
            expect(pairing.askers[k], isNot(equals(pairing.targets[k])),
                reason: 'Player ${pairing.askers[k]} cannot ask themselves at question $k for N=$n');
          }
        }
      }
    });

    test('CH-Q2: Edge cases for N=1 and N=2 derangement generator', () {
      final rng = Random(123);
      // N=1 cannot have a derangement
      final p1 = generateRandomQuestioningRound(1, rng);
      expect(p1.askers, isEmpty);
      expect(p1.targets, isEmpty);

      // N=2 derangement must be (0 asks 1, 1 asks 0) or (1 asks 0, 0 asks 1)
      for (int i = 0; i < 20; i++) {
        final p2 = generateRandomQuestioningRound(2, rng);
        expect(p2.askers.length, equals(2));
        expect(p2.targets.length, equals(2));
        expect(p2.askers[0], isNot(equals(p2.targets[0])));
        expect(p2.askers[1], isNot(equals(p2.targets[1])));
      }
    });
  });

  group('CHALLENGER STRESS: R1 - R4 UI Negative Invariants & Structural Precision', () {
    testWidgets('CH-UI1: Main menu settings/rules buttons contain zero emojis and clean text', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Main menu check
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);

      // Verify no emoji variants exist
      expect(find.textContaining('⚙️'), findsNothing);
      expect(find.textContaining('📜'), findsNothing);
      expect(find.textContaining('📖'), findsNothing);
    });

    testWidgets('CH-UI2: Settings screen audio label strictly displays "Audio" and not "Audio feedback"', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Audio'), findsOneWidget);
      expect(find.textContaining('Audio feedback'), findsNothing);
      expect(find.textContaining('Audio Feedback'), findsNothing);
    });

    testWidgets('CH-UI3: Rules screen houses 4 distinct rounded cards with zero emojis', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Rules'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Roles & Objectives'), findsOneWidget);
      expect(find.text('Questioning Phase'), findsOneWidget);
      expect(find.text('Voting & Scoring'), findsOneWidget);

      // Negative emoji check in rules
      expect(find.textContaining('🎭'), findsNothing);
      expect(find.textContaining('🕵️'), findsNothing);
      expect(find.textContaining('🔍'), findsNothing);
      expect(find.textContaining('🏆'), findsNothing);
    });

    testWidgets('CH-UI4: Role reveal: category has no emoji, no lock icon when revealed, fraud has 👁️ FRAUD badge', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<int> passOrder = (state.passOrder as List<int>);

      for (int p = 0; p < 4; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);

        // On pass screen, lock icon is present
        expect(find.byIcon(Icons.lock_person_rounded), findsOneWidget);

        // Tap reveal
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // Category displayed without emoji
        expect(find.text('Category: Food'), findsOneWidget);
        expect(find.textContaining('🍔 Category:'), findsNothing);

        // Once revealed, lock icon is strictly REMOVED
        expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
        expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
        expect(find.byIcon(Icons.lock_person_rounded), findsNothing);

        if (isFraud) {
          expect(find.text('👁️ FRAUD'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        } else {
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
        }

        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('CH-UI5: Discussion screen light box, vertical prompt with "asks", three-dots icon, no previous button', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Pass all reveals
      for (int p = 0; p < 4; p++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check Discuss screen elements
      expect(find.text('Discuss!'), findsOneWidget);
      expect(find.text('asks'), findsOneWidget);
      expect(find.text('Next question'), findsOneWidget);
      expect(find.text('Previous question'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Verify Options dialog opens and dismisses
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsNothing);
    });
  });

  group('CHALLENGER STRESS: R5 & R6 Leaderboard & Complex Scoring Mechanics', () {
    testWidgets('CH-SC1: Caught fraud guesses secret word correctly -> fraud 50 pts, voters 100 pts, players win banner', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      for (int p = 0; p < 4; p++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final int fraudIdx = (state.fraudIndices as Set<int>).first;
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);

      // All 3 non-frauds vote for fraud; fraud votes for someone else
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        if (v == fraudIdx) {
          final target = (fraudIdx + 1) % 4;
          await tester.tap(find.text(players[target]));
        } else {
          await tester.tap(find.text(players[fraudIdx]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Last chance!'), findsOneWidget);
      // Guess secret word correctly
      await tester.tap(find.text(roundWord));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // Result screen assertions
      expect(find.text('The players win'), findsOneWidget);

      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[fraudIdx], equals(50));
      for (int i = 0; i < 4; i++) {
        if (i != fraudIdx) {
          expect(pointsEarned[i], equals(100));
        }
      }

      // Leaderboard voter indication
      expect(find.text('voted ${players[fraudIdx]}'), findsNWidgets(3));
      final fraudTarget = (fraudIdx + 1) % 4;
      expect(find.text('voted ${players[fraudTarget]}'), findsOneWidget);
    });

    testWidgets('CH-SC2: Caught fraud misses guess -> fraud 0 pts, voters 100 pts, players win banner', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      for (int p = 0; p < 4; p++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final int fraudIdx = (state.fraudIndices as Set<int>).first;
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);

      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        if (v == fraudIdx) {
          final target = (fraudIdx + 1) % 4;
          await tester.tap(find.text(players[target]));
        } else {
          await tester.tap(find.text(players[fraudIdx]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> options = (state.guessOptions as List<String>);
      final wrongOption = options.firstWhere((w) => w != roundWord);
      await tester.tap(find.text(wrongOption));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The players win'), findsOneWidget);

      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[fraudIdx], equals(0));
      for (int i = 0; i < 4; i++) {
        if (i != fraudIdx) {
          expect(pointsEarned[i], equals(100));
        }
      }
    });

    testWidgets('CH-SC3: Multi-round score accumulation preserves cumulative totals across round types', (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // ROUND 1: Caught fraud guesses correctly (fraud +50, voters +100)
      for (int p = 0; p < 4; p++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final int fraud1 = (state.fraudIndices as Set<int>).first;
      final List<String> players = (state.players as List<String>);
      final String word1 = (state.roundWord as String);

      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        if (v == fraud1) {
          await tester.tap(find.text(players[(fraud1 + 1) % 4]));
        } else {
          await tester.tap(find.text(players[fraud1]));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(find.text(word1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      final Map<String, int> scoresAfterR1 = Map<String, int>.from(state.scores as Map<String, int>);
      expect(scoresAfterR1[players[fraud1]], equals(50));

      // Tap Continue -> Select Category Drinks -> Start round 2
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Drinks'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // ROUND 2: Frauds escape! (no one votes for fraud)
      for (int p = 0; p < 4; p++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = (p == 3) ? find.text('Hide and start discussion') : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      final int fraud2 = (state.fraudIndices as Set<int>).first;
      final safeTarget = [0, 1, 2, 3].firstWhere((i) => i != fraud2);

      // Everyone votes for safeTarget
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));
        final target = (v == safeTarget) ? ((safeTarget + 1) % 4) : safeTarget;
        await tester.tap(find.text(players[target]));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Fraud escaped!
      expect(find.text('The Fraud Wins'), findsOneWidget);
      final Map<String, int> scoresAfterR2 = (state.scores as Map<String, int>);
      expect(scoresAfterR2[players[fraud2]], equals((scoresAfterR1[players[fraud2]] ?? 0) + 100));
    });
  });
}
