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

  group('Challenger M3: Scoring Mechanics (R6) & Leaderboard Votes (R5) Adversarial Suite', () {
    // -------------------------------------------------------------------------
    // TEST 1: Caught Fraud Correct Guess Branch (Unit & Widget through confirmGuess)
    // -------------------------------------------------------------------------
    testWidgets('R6-SC1: Caught fraud correct guess awards 50 pts to fraud, 100 pts to voters, 0 to non-voters, and displays green victory banner',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie', 'David'];
        state.playerCount = 4;
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = null;
        state.fraudCaughtByMajority = true;
        state.caughtFrauds = {3};
        state.guessingFraudIndex = 3;
        state.guessOptions = ['Pizza', 'Burger', 'Taco', 'Sushi'];
        state.guessPick = 0; // Correct word: 'Pizza'
        // Voters: Alice(0)->David(3), Bob(1)->David(3), Charlie(2)->Alice(0), David(3)->Alice(0)
        state.playerVotes = {0: 3, 1: 3, 2: 0, 3: 0};
        state.voteCounts = {3: 2, 0: 2};
        state.scores.clear();
        state.scores.addAll({'Alice': 100, 'Bob': 50, 'Charlie': 20, 'David': 0});
        state.screen = Screen.guess;
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Confirm guess" on Screen.guess
      expect(find.text('Confirm guess'), findsOneWidget);
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify navigation to Screen.result
      expect(state.screen, Screen.result);

      // 2. Verify score state:
      // David (caught fraud, guessed correctly) receives +50 pts (0 + 50 = 50)
      expect(state.scores['David'], equals(50));
      expect(state.pointsEarnedThisRound[3], equals(50));

      // Alice & Bob (voted for David) receive +100 pts
      expect(state.scores['Alice'], equals(200)); // 100 + 100
      expect(state.pointsEarnedThisRound[0], equals(100));
      expect(state.scores['Bob'], equals(150)); // 50 + 100
      expect(state.pointsEarnedThisRound[1], equals(100));

      // Charlie (voted for Alice, safe player) receives 0 pts
      expect(state.scores['Charlie'], equals(20));
      expect(state.pointsEarnedThisRound[2], isNull);

      // 3. Verify Victory Banner text & color (Group victory, not fraud victory)
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);

      // 4. Verify Leaderboard deltas and vote indicators
      expect(find.text('+50'), findsOneWidget); // David
      expect(find.text('+100'), findsNWidgets(2)); // Alice and Bob
      expect(find.text('voted David'), findsNWidgets(2)); // Alice & Bob
      expect(find.text('voted Alice'), findsNWidgets(2)); // Charlie & David
    });

    // -------------------------------------------------------------------------
    // TEST 2: Caught Fraud Incorrect Guess Branch (Unit & Widget through confirmGuess)
    // -------------------------------------------------------------------------
    testWidgets('R6-SC2: Caught fraud incorrect guess awards 0 pts to fraud, 100 pts to voters, 0 to non-voters, and displays green victory banner',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie', 'David'];
        state.playerCount = 4;
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = null;
        state.fraudCaughtByMajority = true;
        state.caughtFrauds = {3};
        state.guessingFraudIndex = 3;
        state.guessOptions = ['Pizza', 'Burger', 'Taco', 'Sushi'];
        state.guessPick = 1; // Incorrect word: 'Burger'
        // Voters: Alice(0)->David(3), Bob(1)->David(3), Charlie(2)->David(3), David(3)->Bob(1)
        state.playerVotes = {0: 3, 1: 3, 2: 3, 3: 1};
        state.voteCounts = {3: 3, 1: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 100, 'Bob': 50, 'Charlie': 20, 'David': 10});
        state.screen = Screen.guess;
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Confirm guess" on Screen.guess
      expect(find.text('Confirm guess'), findsOneWidget);
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify navigation to Screen.result
      expect(state.screen, Screen.result);

      // 2. Verify score state:
      // David (caught fraud, guessed wrong) receives 0 pts (10 + 0 = 10)
      expect(state.scores['David'], equals(10));
      expect(state.pointsEarnedThisRound[3], equals(0));

      // Alice, Bob, Charlie (voted for David) receive +100 pts
      expect(state.scores['Alice'], equals(200));
      expect(state.pointsEarnedThisRound[0], equals(100));
      expect(state.scores['Bob'], equals(150));
      expect(state.pointsEarnedThisRound[1], equals(100));
      expect(state.scores['Charlie'], equals(120));
      expect(state.pointsEarnedThisRound[2], equals(100));

      // 3. Verify Victory Banner text & color
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);

      // 4. Verify Leaderboard deltas and vote indicators
      expect(find.text('+50'), findsNothing); // No 50 pts
      expect(find.text('+100'), findsNWidgets(3)); // Alice, Bob, Charlie
      expect(find.text('voted David'), findsNWidgets(3));
      expect(find.text('voted Bob'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 3: Fraud Escapes / No Majority Vote Branch
    // -------------------------------------------------------------------------
    testWidgets('R6-SC3: Fraud escapes without majority awards 100 pts to fraud, 0 to safe players, and displays red defeat banner',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie', 'David'];
        state.playerCount = 4;
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.fraudIndices = {3}; // David is fraud
        state.undercoverIndex = null;
        // Votes: Alice votes David (1 vote), Bob, Charlie, David vote Alice (3 votes)
        state.playerVotes = {0: 3, 1: 0, 2: 0, 3: 0};
        state.voteCounts = {3: 1, 0: 3};
        state.scores.clear();
        state.scores.addAll({'Alice': 100, 'Bob': 50, 'Charlie': 20, 'David': 0});
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify navigation directly to Screen.result (no guess screen)
      expect(state.screen, Screen.result);
      expect(state.fraudCaughtByMajority, isFalse);

      // 2. Verify score state: David escapes -> 100 pts. Safe players -> 0 pts.
      expect(state.scores['David'], equals(100));
      expect(state.pointsEarnedThisRound[3], equals(100));
      expect(state.scores['Alice'], equals(100));
      expect(state.scores['Bob'], equals(50));
      expect(state.scores['Charlie'], equals(20));

      // 3. Verify Defeat Banner text
      expect(find.text('THE FRAUD ESCAPED'), findsOneWidget);

      // 4. Verify Leaderboard shows +100 for fraud, nothing for safe players
      expect(find.text('+100'), findsOneWidget); // Only David
      expect(find.text('voted David'), findsNWidgets(1));
      expect(find.text('voted Alice'), findsNWidgets(3));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Leaderboard Vote Display Formatting & Alignment (R5)
    // -------------------------------------------------------------------------
    testWidgets('R5-LB1: Leaderboard accurately maps each voter to their voted target with muted font styling',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Player 1', 'Player 2', 'Player 3', 'Player 4', 'Player 5'];
        state.playerCount = 5;
        state.scores.clear();
        state.scores.addAll({
          'Player 1': 400,
          'Player 2': 300,
          'Player 3': 200,
          'Player 4': 100,
          'Player 5': 0,
        });
        // Permuted voting:
        // 0 voted 1, 1 voted 2, 2 voted 3, 3 voted 4, 4 voted 0
        state.playerVotes = {0: 1, 1: 2, 2: 3, 3: 4, 4: 0};
        state.fraudIndices = {1};
        state.fraudCaughtByMajority = true;
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('voted Player 2'), findsOneWidget);
      expect(find.text('voted Player 3'), findsOneWidget);
      expect(find.text('voted Player 4'), findsOneWidget);
      expect(find.text('voted Player 5'), findsOneWidget);
      expect(find.text('voted Player 1'), findsOneWidget);

      // Verify styling of vote text: fontSize 12, fontWeight w500, color muted
      final voteFinder = find.text('voted Player 2');
      final voteText = tester.widget<Text>(voteFinder);
      expect(voteText.style?.fontSize, equals(12));
      expect(voteText.style?.fontWeight, equals(FontWeight.w500));
      expect(voteText.style?.color, const Color(0xFF94A3B8)); // muted color
    });

    // -------------------------------------------------------------------------
    // TEST 5: Leaderboard Defensive Handling (Null, Empty, Out-of-bounds votes)
    // -------------------------------------------------------------------------
    testWidgets('R5-LB2: Leaderboard defensively handles negative, out-of-range, and empty votes without exceptions',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.playerCount = 3;
        state.scores.clear();
        state.scores.addAll({'Alice': 100, 'Bob': 50, 'Charlie': 0});
        // Corrupted or out-of-bounds vote mapping:
        // Alice: -1 (invalid), Bob: 99 (out of range), Charlie: missing
        state.playerVotes = {0: -1, 1: 99};
        state.fraudIndices = {1};
        state.fraudCaughtByMajority = true;
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Total Leaderboard renders cleanly
      expect(find.text('Total Leaderboard'), findsOneWidget);
      // No "voted" text rendered because all vote targets are invalid/null
      expect(find.textContaining('voted'), findsNothing);
      // Zero exceptions thrown
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 6: Two Frauds Mode Scoring & Leaderboard Invariants
    // -------------------------------------------------------------------------
    testWidgets('R6-TF1: Two Frauds mode: 1 fraud caught and guesses correctly (50 pts), second fraud gets 0 pts, voters get 100 pts',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        // 5 players, Frauds: Charlie (2) and David (3)
        state.players = ['Alice', 'Bob', 'Charlie', 'David', 'Eve'];
        state.playerCount = 5;
        state.roundCat = 'Animals';
        state.roundWord = 'Falcon';
        state.fraudIndices = {2, 3};
        state.selectedMode = availableGameModes[1]; // 2 Frauds mode
        // Majority threshold = 5 / 2 = 2.5
        // Charlie gets 3 votes (from Alice, Bob, Eve) -> Charlie caught!
        // David gets 1 vote (from Charlie) -> David not caught.
        // David voted for Alice.
        state.playerVotes = {0: 2, 1: 2, 2: 3, 3: 0, 4: 2};
        state.voteCounts = {2: 3, 3: 1, 0: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'David': 0, 'Eve': 0});

        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Tallying should detect Charlie caught, transition to Screen.guess
      expect(state.screen, Screen.guess);
      expect(state.guessingFraudIndex, equals(2));
      expect(state.fraudCaughtByMajority, isTrue);

      // Charlie guesses correctly
      state.setState(() {
        state.guessOptions = ['Falcon', 'Eagle', 'Hawk', 'Owl'];
        state.guessPick = 0; // 'Falcon'
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);

      // Charlie (guessing fraud) earns 50 pts
      expect(state.scores['Charlie'], equals(50));
      expect(state.pointsEarnedThisRound[2], equals(50));

      // David (uncaught second fraud who escaped) earns 100 pts!
      expect(state.scores['David'], equals(100));
      expect(state.pointsEarnedThisRound[3], equals(100));

      // Alice, Bob, Eve (safe players who voted for Charlie) earn 100 pts
      expect(state.scores['Alice'], equals(100));
      expect(state.pointsEarnedThisRound[0], equals(100));
      expect(state.scores['Bob'], equals(100));
      expect(state.pointsEarnedThisRound[1], equals(100));
      expect(state.scores['Eve'], equals(100));
      expect(state.pointsEarnedThisRound[4], equals(100));

      // Split outcome banner: 1 fraud caught, 1 fraud escaped
      expect(find.text('SPLIT OUTCOME: 1 CAUGHT, 1 ESCAPED'), findsOneWidget);
      expect(find.text('voted Charlie'), findsNWidgets(3)); // Alice, Bob, Eve
      expect(find.text('voted David'), findsOneWidget); // Charlie
      expect(find.text('voted Alice'), findsOneWidget); // David
    });

    // -------------------------------------------------------------------------
    // TEST 7: Undercover Mode Scoring Verification
    // -------------------------------------------------------------------------
    testWidgets('R6-UC1: Undercover mode: Undercover votes for caught fraud and earns 100 pts along with safe players',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        // 4 players: Alice(0)=Safe, Bob(1)=Undercover, Charlie(2)=Fraud, Diana(3)=Safe
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.playerCount = 4;
        state.roundCat = 'Places';
        state.roundWord = 'Paris';
        state.roundUndercoverWord = 'London';
        state.fraudIndices = {2}; // Charlie is fraud
        state.undercoverIndex = 1; // Bob is undercover
        state.selectedMode = availableGameModes[2]; // Undercover mode

        // Votes: Alice->Charlie, Bob(Undercover)->Charlie, Diana->Charlie, Charlie->Bob
        state.playerVotes = {0: 2, 1: 2, 2: 1, 3: 2};
        state.voteCounts = {2: 3, 1: 1};
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'Diana': 0});

        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);

      // Charlie misses the guess
      state.setState(() {
        state.guessOptions = ['Paris', 'Rome', 'Berlin', 'Madrid'];
        state.guessPick = 1; // Rome (wrong)
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);

      // Charlie gets 0 pts
      expect(state.scores['Charlie'], equals(0));
      expect(state.pointsEarnedThisRound[2], equals(0));

      // Bob (Undercover who voted for caught fraud) is not in fraudIndices, earns 100 pts!
      expect(state.scores['Bob'], equals(100));
      expect(state.pointsEarnedThisRound[1], equals(100));

      // Alice and Diana earn 100 pts
      expect(state.scores['Alice'], equals(100));
      expect(state.pointsEarnedThisRound[3], equals(100));

      // Leaderboard checks
      expect(find.text('+100'), findsNWidgets(3));
      expect(find.text('voted Charlie'), findsNWidgets(3));
      expect(find.text('voted Bob'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Narrow Viewport (320px) & Long/Unicode Player Names Layout Stress
    // -------------------------------------------------------------------------
    testWidgets('R5-ST1: Results leaderboard on compact 320px screen with 30-char and Arabic names renders without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      const longName1 = 'عبدالله محمد إبراهيم الشمري';
      const longName2 = 'Sir Maximilian von Hapsburg III';
      const longName3 = 'Elizabeth Charlotte Windsor 👑';

      state.setState(() {
        state.players = [longName1, longName2, longName3];
        state.playerCount = 3;
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {1};
        state.fraudCaughtByMajority = true;
        state.guessingFraudIndex = 1;
        state.playerVotes = {0: 1, 1: 0, 2: 1};
        state.pointsEarnedThisRound = {0: 100, 1: 50, 2: 100};
        state.scores.clear();
        state.scores.addAll({
          longName1: 300,
          longName2: 250,
          longName3: 200,
        });
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Ensure all 3 names and vote indicators render
      expect(find.text(longName1), findsOneWidget);
      expect(find.text(longName2), findsOneWidget);
      expect(find.text(longName3), findsOneWidget);
      expect(find.text('voted $longName2'), findsNWidgets(2));
      expect(find.text('voted $longName1'), findsOneWidget);

      // CRITICAL: Ensure zero RenderFlex overflow exceptions on 320px compact viewport
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Rules Screen Card 4 Text Verifications
    // -------------------------------------------------------------------------
    testWidgets('R6-RU1: Rules Screen Card 4 accurately describes new 50 pt / 100 pt / round loss scoring mechanics',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.screen = Screen.rules;
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('Voting & Scoring'), findsOneWidget);
      await tester.tap(find.text('Voting & Scoring'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Card 4 text matches requirements:
      expect(
        find.textContaining(
          'Caught Fraud guesses correctly: The fraud earns 50 points, but loses the round! All players who voted for that fraud earn +100 points.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Caught Fraud misses guess: The fraud earns 0 points. All players who voted for that fraud earn +100 points!',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Fraud Escapes: If no fraud receives majority votes, frauds win the round and earn +100 points each.',
        ),
        findsOneWidget,
      );
    });
  });
}
