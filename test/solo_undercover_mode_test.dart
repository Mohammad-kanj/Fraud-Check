import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  group('Requirement 1: Undercover Mode (Solo)', () {
    test('GameModeId.soloUndercover exists with fraudCount=0 and hasUndercover=true', () {
      final mode = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);
      expect(mode.title, 'Undercover');
      expect(mode.subtitle, '1 undercover agent with a secret decoy word. No frauds!');
      expect(mode.fraudCount, 0);
      expect(mode.hasUndercover, isTrue);
      expect(mode.minPlayers, 3);
      expect(mode.maxPlayers, 10);
    });

    test('GameModeId.undercover exists as Chaos mode', () {
      final mode = availableGameModes.firstWhere((m) => m.id == GameModeId.undercover);
      expect(mode.title, 'Chaos');
      expect(mode.fraudCount, 1);
      expect(mode.hasUndercover, isTrue);
    });

    testWidgets('Mode selection screen displays Undercover card with "1 Undercover" badge', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.go(Screen.mode);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Undercover'), findsOneWidget);
      expect(find.text('Chaos'), findsOneWidget);
      expect(find.text('1 Undercover'), findsOneWidget);
      expect(find.text('3 to 10 players'), findsNWidgets(2)); // Classic and Undercover (solo)
    });

    testWidgets('Starting round in Solo Undercover mode assigns 0 frauds and 1 undercover', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final soloMode = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);

      state.setState(() {
        state.selectedMode = soloMode;
        state.players = ['Player 1', 'Player 2', 'Player 3'];
        state.chosenCat = 'Food';
        state.startRound();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.fraudIndices.isEmpty, isTrue);
      expect(state.undercoverIndex, isNotNull);
      expect(state.undercoverIndex! >= 0 && state.undercoverIndex! < 3, isTrue);
      expect(state.roundUndercoverWord.isNotEmpty, isTrue);
      expect(state.roundWord.isNotEmpty, isTrue);
      expect(state.roundUndercoverWord, isNot(equals(state.roundWord)));
    });

    testWidgets('Solo Undercover role reveal: Undercover sees decoy word, safe players see secret word', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final soloMode = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);

      state.setState(() {
        state.selectedMode = soloMode;
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.roundUndercoverWord = 'Burger';
        state.fraudIndices = <int>{};
        state.undercoverIndex = 1; // Bob is undercover
        state.passOrder = [0, 1, 2];
        state.passIdx = 0; // Alice (safe)
        state.screen = Screen.reveal;
      });
      // Pump 500ms for reveal card flip animation
      await tester.pump(const Duration(milliseconds: 500));

      // Alice sees safe screen
      expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);

      // Advance to Bob (undercover)
      state.setState(() {
        state.passIdx = 1;
        state.screen = Screen.reveal;
      });
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
      expect(find.text('👁️ UNDERCOVER'), findsOneWidget);
      expect(find.text('Burger'), findsOneWidget);
    });

    testWidgets('Solo Undercover voting: Undercover caught by majority and misses guess -> voters get 100 pts', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final soloMode = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);

      state.setState(() {
        state.selectedMode = soloMode;
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0});
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.roundUndercoverWord = 'Burger';
        state.fraudIndices = <int>{};
        state.undercoverIndex = 1; // Bob
        state.playerVotes = {0: 1, 1: 0, 2: 1}; // 2 votes for Bob (> 1.5 majority)
        state.voteCounts = {1: 2, 0: 1};
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);
      expect(state.fraudCaughtByMajority, isTrue);
      expect(state.guessingFraudIndex, 1);

      // Bob picks wrong word
      state.setState(() {
        final wrongIdx = state.guessOptions.indexWhere((w) => w != 'Pizza');
        state.guessPick = wrongIdx;
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);
      expect(state.scores['Bob'], 0);
      expect(state.scores['Alice'], 100);
      expect(state.scores['Charlie'], 100);
    });

    testWidgets('Solo Undercover voting: Undercover survives without majority -> undercover wins 100 pts', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final soloMode = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);

      state.setState(() {
        state.selectedMode = soloMode;
        state.players = ['Alice', 'Bob', 'Charlie'];
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0});
        state.roundCat = 'Food';
        state.roundWord = 'Pizza';
        state.roundUndercoverWord = 'Burger';
        state.fraudIndices = <int>{};
        state.undercoverIndex = 1; // Bob
        state.playerVotes = {0: 2, 1: 0, 2: 0}; // Bob received 0 votes
        state.voteCounts = {2: 1, 0: 2};
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      expect(state.fraudCaughtByMajority, isFalse);
      expect(find.text('THE UNDERCOVER WINS'), findsOneWidget);
      expect(state.scores['Bob'], 100);
      expect(state.scores['Alice'], 0);
      expect(state.scores['Charlie'], 0);
    });
  });

  group('Requirements 2, 3, 4: Result Screen Text and Badges', () {
    testWidgets('Category and Mode are completely absent from final screen', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Player 1', 'Player 2', 'Player 3'];
        state.roundCat = 'Animals';
        state.roundWord = 'Lion';
        state.fraudIndices = {0};
        state.scores.addAll({'Player 1': 0, 'Player 2': 100, 'Player 3': 100});
        state.pointsEarnedThisRound.addAll({1: 100, 2: 100});
        state.playerVotes.addAll({0: 1, 1: 0, 2: 0});
        state.fraudCaughtByMajority = true;
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Category and mode pills should not exist on final screen
      expect(find.text('Mode: Classic'), findsNothing);
      expect(find.text('Mode: Two Frauds'), findsNothing);
      expect(find.text('Mode: Undercover'), findsNothing);
      expect(find.text('Mode: Chaos'), findsNothing);
      expect(find.text('Animals'), findsNothing);
      expect(find.text('SECRET WORD'), findsOneWidget);
      expect(find.text('Lion'), findsOneWidget);
    });

    testWidgets('Fraud wins box shows single sentence "THE FRAUD WINS" with golden text and no text under', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Player 1', 'Player 2', 'Player 3'];
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {0};
        state.scores.addAll({'Player 1': 100, 'Player 2': 0, 'Player 3': 0});
        state.pointsEarnedThisRound.addAll({0: 100});
        state.playerVotes.addAll({0: 1, 1: 2, 2: 1});
        state.fraudCaughtByMajority = false;
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('THE FRAUD WINS'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('THE FRAUD WINS'));
      expect(textWidget.style?.color, equals(yellow));
      // Ensure old multi-line texts are absent
      expect(find.text('THE FRAUD ESCAPED!'), findsNothing);
      expect(find.text('The fraud wins!'), findsNothing);
      expect(find.textContaining('takes the round'), findsNothing);
    });

    testWidgets('Players win box shows single sentence "THE PLAYERS WIN" with golden text and no text under', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Player 1', 'Player 2', 'Player 3'];
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {0};
        state.scores.addAll({'Player 1': 0, 'Player 2': 100, 'Player 3': 100});
        state.pointsEarnedThisRound.addAll({1: 100, 2: 100});
        state.playerVotes.addAll({0: 1, 1: 0, 2: 0});
        state.fraudCaughtByMajority = true;
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('THE PLAYERS WIN'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('THE PLAYERS WIN'));
      expect(textWidget.style?.color, equals(yellow));
      // Ensure old banners and explanations are absent
      expect(find.text('PLAYERS IN THE KNOW WIN!'), findsNothing);
      expect(find.text('The players in the know win!'), findsNothing);
      expect(find.textContaining('was caught by majority vote and failed to guess'), findsNothing);
    });
  });

  group('Requirement 5: FilmStrip Background Speed', () {
    testWidgets('FilmStripBackground animates smoothly over 10s period', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: FilmStripBackground(),
      ));
      expect(find.byType(FilmStripBackground), findsOneWidget);

      final customPaintFinder = find.descendant(
        of: find.byType(FilmStripBackground),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      final initialPainter = tester.widget<CustomPaint>(customPaintFinder).painter as FilmStripPainter;
      expect(initialPainter.progress, 0.0);

      // Pump 5 seconds (50% progress in a 10s animation)
      await tester.pump(const Duration(seconds: 5));
      final midPainter = tester.widget<CustomPaint>(customPaintFinder).painter as FilmStripPainter;
      expect(midPainter.progress, closeTo(0.5, 0.01));

      // Pump another 5 seconds (completes 10s loop)
      await tester.pump(const Duration(seconds: 5));
      final endPainter = tester.widget<CustomPaint>(customPaintFinder).painter as FilmStripPainter;
      expect(endPainter.progress, closeTo(0.0, 0.05));
    });
  });
}
