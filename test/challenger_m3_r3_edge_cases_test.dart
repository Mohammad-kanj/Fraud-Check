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

  group('Challenger M3 R3: Deep Edge Cases & Adversarial Invariants', () {
    // -------------------------------------------------------------------------
    // EDGE 1: 4 Players 2-2 Tie Vote -> Fraud Escapes without Exception
    // -------------------------------------------------------------------------
    testWidgets('EDGE-1: 2-2 tie vote in 4-player game results in fraud escaping, +100 to fraud, and clean UI',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie', 'David'];
        state.playerCount = 4;
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = null;
        // Votes: Alice votes David (1 vote), Bob, Charlie & David vote Alice (3 votes)
        state.playerVotes = {0: 3, 1: 0, 2: 0, 3: 0};
        state.voteCounts = {3: 1, 0: 3};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'David': 0});
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(state.fraudCaughtByMajority, isFalse);
      expect(state.scores['David'], equals(100));
      expect(state.scores['Alice'], equals(0));
      expect(state.scores['Bob'], equals(0));
      expect(state.scores['Charlie'], equals(0));

      expect(find.text('THE FRAUD ESCAPED'), findsOneWidget);
      expect(find.text('voted David'), findsNWidgets(1));
      expect(find.text('voted Alice'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // EDGE 2: Zero-Voter / Empty Votes State
    // -------------------------------------------------------------------------
    testWidgets('EDGE-2: Zero votes / empty vote mapping handles tallying and leaderboard rendering without crash',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.playerCount = 3;
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {2}; // Charlie is fraud
        state.undercoverIndex = null;
        state.playerVotes = <int, int>{};
        state.voteCounts = <int, int>{};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0});
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(state.fraudCaughtByMajority, isFalse);
      expect(state.scores['Charlie'], equals(100));
      expect(find.text('THE FRAUD ESCAPED'), findsOneWidget);
      expect(find.textContaining('voted'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // EDGE 3: Undercover Survives when Fraud Escapes
    // -------------------------------------------------------------------------
    testWidgets('EDGE-3: Fraud escapes and Undercover receives <= majority votes: BOTH Fraud and Undercover earn +100',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        // 5 players: Alice(0)=Safe, Bob(1)=Safe, Charlie(2)=Undercover, David(3)=Fraud, Eve(4)=Safe
        state.players = ['Alice', 'Bob', 'Charlie', 'David', 'Eve'];
        state.playerCount = 5;
        state.roundCat = 'Places';
        state.roundWord = 'Tokyo';
        state.roundUndercoverWord = 'Kyoto';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = 2; // Charlie is undercover
        state.selectedMode = availableGameModes[2]; // Undercover mode

        // Votes: 2 for David, 2 for Alice, 1 for Charlie (majority of 5 is > 2.5)
        // No one gets > 2.5 votes. Charlie gets 1 vote (<= 2.5).
        state.playerVotes = {0: 3, 1: 3, 2: 0, 3: 0, 4: 2};
        state.voteCounts = {3: 2, 0: 2, 2: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'David': 0, 'Eve': 0});
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(state.fraudCaughtByMajority, isFalse);

      // David (fraud) earns 100
      expect(state.scores['David'], equals(100));
      expect(state.pointsEarnedThisRound[3], equals(100));

      // Charlie (undercover) survived without majority against him -> earns 100!
      expect(state.scores['Charlie'], equals(100));
      expect(state.pointsEarnedThisRound[2], equals(100));

      // Safe players earn 0
      expect(state.scores['Alice'], equals(0));
      expect(state.scores['Bob'], equals(0));
      expect(state.scores['Eve'], equals(0));

      expect(find.text('+100'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // EDGE 4: Undercover Busted with Majority Votes when Fraud Escapes
    // -------------------------------------------------------------------------
    testWidgets('EDGE-4: Fraud escapes, Undercover caught: Undercover guesses and voters earn 100 pts',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        // 4 players: Alice(0)=Safe, Bob(1)=Safe, Charlie(2)=Undercover, David(3)=Fraud
        state.players = ['Alice', 'Bob', 'Charlie', 'David'];
        state.playerCount = 4;
        state.roundCat = 'Places';
        state.roundWord = 'Tokyo';
        state.roundUndercoverWord = 'Kyoto';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = 2; // Charlie is undercover
        state.selectedMode = availableGameModes.firstWhere((m) => m.id == GameModeId.undercover); // Chaos mode

        // Votes: 3 for Charlie (Undercover caught!), 1 for David (Fraud escapes)
        // Majority of 4 is > 2. Charlie gets 3 votes (> 2). David gets 1 vote.
        state.playerVotes = {0: 2, 1: 2, 2: 3, 3: 2};
        state.voteCounts = {2: 3, 3: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'David': 0});
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);
      expect(state.guessingFraudIndex, 2);

      // Charlie misses guess
      state.setState(() {
        state.guessPick = state.guessOptions.indexWhere((w) => w != 'Tokyo');
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);

      // David (fraud who escaped) earns 100
      expect(state.scores['David'], equals(100));
      expect(state.pointsEarnedThisRound[3], equals(100));

      // Charlie (undercover) missed guess -> earns 0!
      expect(state.scores['Charlie'], equals(0));
      expect(state.pointsEarnedThisRound[2], equals(0));

      // Alice and Bob who voted for caught undercover earn 100
      expect(state.scores['Alice'], equals(100));
      expect(state.scores['Bob'], equals(100));

      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // EDGE 5: Caught Fraud Guesses Correctly with Ultra-Wide and Ultra-Narrow Viewports
    // -------------------------------------------------------------------------
    testWidgets('EDGE-5: R6 scoring UI verified on ultra-narrow (320px) and ultra-wide (1200px) displays without overflow',
        (WidgetTester tester) async {
      // 1. Narrow 320px
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.playerCount = 3;
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.fraudIndices = {2};
        state.fraudCaughtByMajority = true;
        state.guessingFraudIndex = 2;
        state.guessOptions = ['Pizza', 'Burger', 'Taco'];
        state.guessPick = 0; // Correct
        state.playerVotes = {0: 2, 1: 2, 2: 0};
        state.voteCounts = {2: 2, 0: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0});
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(state.scores['Charlie'], equals(50));
      expect(state.scores['Alice'], equals(100));
      expect(state.scores['Bob'], equals(100));
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('+100'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // 2. Wide 1200px
      tester.view.physicalSize = const Size(1200, 1600);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
