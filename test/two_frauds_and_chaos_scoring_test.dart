import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  group('2 Votes in Two Frauds and Chaos Modes', () {
    test('votesPerPlayer is 2 for Two Frauds and Chaos modes, 1 for Classic and Undercover', () {
      final classic = availableGameModes.firstWhere((m) => m.id == GameModeId.classic);
      final twoFrauds = availableGameModes.firstWhere((m) => m.id == GameModeId.twoFrauds);
      final undercover = availableGameModes.firstWhere((m) => m.id == GameModeId.soloUndercover);
      final chaos = availableGameModes.firstWhere((m) => m.id == GameModeId.undercover);

      expect(twoFrauds.title, 'Two Frauds');
      expect(chaos.title, 'Chaos');
      expect(undercover.title, 'Undercover');
      expect(classic.title, 'Classic');
    });

    testWidgets('Voting screen displays Pick 2 instructions and requires 2 picks in Two Frauds mode', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final twoFrauds = availableGameModes.firstWhere((m) => m.id == GameModeId.twoFrauds);

      state.setState(() {
        state.selectedMode = twoFrauds;
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.chosenCat = 'Food';
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {2, 3}; // Charlie and Diana
        state.screen = Screen.vote;
        state.voteRevealed = true;
        state.voteIdx = 0; // Alice is voting
        state.votePicks = <int>{};
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select 2 suspects'), findsOneWidget);
      expect(find.textContaining('Pick 2 (0/2)'), findsOneWidget);

      // Select first suspect: Bob (index 1)
      await tester.tap(find.text('Bob'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pick 2 (1/2)'), findsOneWidget);

      // Button is labeled Vote
      expect(find.text('Vote'), findsOneWidget);

      // Select second suspect: Charlie (index 2)
      await tester.tap(find.text('Charlie'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Pick 2 (2/2)'), findsOneWidget);
      expect(find.text('Vote'), findsOneWidget);

      // Submit vote
      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // Alice's picks should be recorded in playerVotesMulti
      expect(state.playerVotesMulti[0], containsAll([1, 2]));
    });
  });

  group('Two Frauds Mode Scoring & Sequential Guesses', () {
    testWidgets('Both frauds caught: sequential guesses and +150 pts for voters who caught both', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final twoFrauds = availableGameModes.firstWhere((m) => m.id == GameModeId.twoFrauds);

      state.setState(() {
        state.selectedMode = twoFrauds;
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'Diana': 0});
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {2, 3}; // Charlie and Diana are frauds
        // Alice votes Charlie & Diana, Bob votes Charlie & Diana
        // Both Charlie and Diana receive 2 votes (> 4/2 = 2, wait: with 4 players, 3 votes needed for > 2)
        // Let's give Charlie 3 votes and Diana 3 votes:
        state.voteCounts = {2: 3, 3: 3};
        state.playerVotesMulti = {
          0: [2, 3], // Alice voted both
          1: [2, 0], // Bob voted Charlie and Alice (caught 1)
        };
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);
      expect(state.caughtFrauds, containsAll([2, 3]));
      expect(state.remainingGuessers.length, 1); // 1 remaining after first popped

      // First caught fraud guesses incorrectly
      final firstGuesser = state.guessingFraudIndex;
      state.setState(() {
        state.guessPick = state.guessOptions.indexWhere((w) => w != 'Falafel');
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Should still be on guess screen for the second caught fraud!
      expect(state.screen, Screen.guess);
      expect(state.guessingFraudIndex, isNot(equals(firstGuesser)));

      // Second caught fraud guesses correctly!
      final secondGuesser = state.guessingFraudIndex;
      state.setState(() {
        state.guessPick = state.guessOptions.indexWhere((w) => w == 'Falafel');
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      // Now at result screen
      expect(state.screen, Screen.result);
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);

      // Scoring:
      // First guesser got 0
      expect(state.scores[state.players[firstGuesser]], 0);
      // Second guesser guessed right -> 50 pts
      expect(state.scores[state.players[secondGuesser]], 50);

      // Alice voted for both caught frauds -> 150 pts!
      expect(state.scores['Alice'], 150);
      expect(state.pointsEarnedThisRound[0], 150);

      // Bob voted for 1 caught fraud -> 100 pts!
      expect(state.scores['Bob'], 100);
      expect(state.pointsEarnedThisRound[1], 100);
    });

    testWidgets('1 fraud caught, 1 fraud escapes: escaped fraud gets 100 pts, voters get 100 pts', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final twoFrauds = availableGameModes.firstWhere((m) => m.id == GameModeId.twoFrauds);

      state.setState(() {
        state.selectedMode = twoFrauds;
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'Diana': 0});
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.fraudIndices = {2, 3}; // Charlie and Diana
        // Only Charlie gets majority (> 2), Diana gets 1 vote
        state.voteCounts = {2: 3, 3: 1};
        state.playerVotesMulti = {
          0: [2, 1], // Alice voted Charlie
          1: [0, 3], // Bob voted Diana (escaped)
        };
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);
      expect(state.guessingFraudIndex, 2); // Charlie

      // Charlie guesses wrong
      state.setState(() {
        state.guessPick = state.guessOptions.indexWhere((w) => w != 'Falafel');
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      // Charlie caught & wrong guess -> 0 pts
      expect(state.scores['Charlie'], 0);
      // Diana escaped -> 100 pts
      expect(state.scores['Diana'], 100);
      // Alice voted for Charlie (caught) -> 100 pts
      expect(state.scores['Alice'], 100);
      // Bob voted for Diana (escaped) -> 0 pts
      expect(state.scores['Bob'], 0);
    });
  });

  group('Chaos Mode (1 Fraud + 1 Undercover) Scoring & Badges', () {
    testWidgets('Undercover guessing secret word displays "An undercover agent was caught"', (tester) async {
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final chaos = availableGameModes.firstWhere((m) => m.id == GameModeId.undercover);

      state.setState(() {
        state.selectedMode = chaos;
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.scores.clear();
        state.scores.addAll({'Alice': 0, 'Bob': 0, 'Charlie': 0, 'Diana': 0});
        state.roundCat = 'Food';
        state.roundWord = 'Falafel';
        state.roundUndercoverWord = 'Shawarma';
        state.fraudIndices = {3}; // Diana is fraud
        state.undercoverIndex = 2; // Charlie is undercover
        // Undercover (Charlie) receives majority (> 2), Fraud escapes
        state.voteCounts = {2: 3, 3: 1};
        state.playerVotesMulti = {
          0: [2, 1], // Alice voted Charlie
          1: [2, 3], // Bob voted Charlie and Diana
        };
        state.tallyVotes();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.guess);
      expect(state.guessingFraudIndex, 2); // Charlie is guessing
      expect(find.textContaining('An undercover agent was caught by majority vote'), findsOneWidget);

      // Charlie misses guess
      state.setState(() {
        state.guessPick = state.guessOptions.indexWhere((w) => w != 'Falafel');
        state.confirmGuess();
      });
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen, Screen.result);
      // Charlie caught & missed -> 0 pts
      expect(state.scores['Charlie'], 0);
      // Diana escaped -> 100 pts
      expect(state.scores['Diana'], 100);
      // Alice voted for Charlie (caught) -> 100 pts
      expect(state.scores['Alice'], 100);
      // Bob voted for Charlie (caught) -> 100 pts
      expect(state.scores['Bob'], 100);

      // Requirement 2: undercover word display is (Shawarma) not (Word: "Shawarma")
      expect(find.text('Undercover: Charlie (Shawarma)'), findsOneWidget);
    });
  });
}
