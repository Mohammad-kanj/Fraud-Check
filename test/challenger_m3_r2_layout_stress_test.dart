import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  /// Helper to configure a given viewport size and pixel ratio with automatic cleanup
  void setViewport(WidgetTester tester, {required double width, required double height, double pixelRatio = 1.0}) {
    tester.view.physicalSize = Size(width * pixelRatio, height * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Helper to directly configure GamePage state to Screen.result with customized properties
  void configureResultState(
    WidgetTester tester, {
    required List<String> playerList,
    required Map<String, int> scoresMap,
    required Map<int, int> roundPoints,
    required Map<int, int> votesMap,
    required Set<int> frauds,
    int? undercoverIdx,
    String category = 'Food',
    String word = 'Pizza',
    String undercoverWord = 'Burger',
    bool caughtByMajority = true,
    bool fraudGuessedRight = false,
    GameMode? mode,
  }) {
    final dynamic state = tester.state(find.byType(GamePage));
    state.setState(() {
      state.screen = Screen.result;
      state.players = List<String>.from(playerList);
      state.playerCount = playerList.length;
      state.scores.clear();
      state.scores.addAll(scoresMap);
      state.pointsEarnedThisRound.clear();
      state.pointsEarnedThisRound.addAll(roundPoints);
      state.playerVotes.clear();
      state.playerVotes.addAll(votesMap);
      state.roundCat = category;
      state.roundWord = word;
      state.roundUndercoverWord = undercoverWord;
      state.fraudIndices = frauds;
      state.undercoverIndex = undercoverIdx;
      state.fraudCaughtByMajority = caughtByMajority;
      state.caughtFrauds = caughtByMajority ? frauds : <int>{};
      state.guessingFraudIndex = frauds.isNotEmpty ? frauds.first : 0;
      state.selectedMode = mode ?? availableGameModes[0];
    });
  }

  // =========================================================================
  // GROUP 1: MULTI-VIEWPORT MATRIX TESTS (320px to 1080px)
  // =========================================================================
  group('Group 1: Multi-Viewport Matrix Tests on Results Screen (_result)', () {
    final viewports = <String, Size>{
      'Ultra-compact mobile (320x480)': const Size(320, 480),
      'iPhone SE (375x667)': const Size(375, 667),
      'Pixel Android (412x915)': const Size(412, 915),
      'Tablet / iPad (768x1024)': const Size(768, 1024),
      'Desktop Full HD (1080x1920)': const Size(1080, 1920),
    };

    for (final entry in viewports.entries) {
      testWidgets('VP.1: Zero RenderFlex overflow and full element rendering on ${entry.key}',
          (WidgetTester tester) async {
        setViewport(tester, width: entry.value.width, height: entry.value.height);

        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        final scores = {'Alice': 150, 'Bob': 200, 'Charlie': 50, 'Diana': 100};
        final points = {0: 100, 1: 50, 2: 0, 3: 100};
        final votes = {0: 1, 2: 1, 3: 1, 1: 0}; // 1 is caught fraud

        configureResultState(
          tester,
          playerList: players,
          scoresMap: scores,
          roundPoints: points,
          votesMap: votes,
          frauds: {1},
          category: 'Food',
          word: 'Shawarma',
        );
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Assert zero exceptions / zero RenderFlex overflows
        expect(tester.takeException(), isNull,
            reason: 'Must render results screen without RenderFlex overflow on ${entry.key}');

        // 2. Assert Hero Victory Banner
        expect(find.text('THE PLAYERS WIN'), findsOneWidget);

        // 3. Assert Dimensional Summary Section
        expect(find.text('SECRET WORD'), findsOneWidget);
        expect(find.text('Shawarma'), findsOneWidget);
        expect(find.text('Fraud: Bob'), findsOneWidget);

        // 4. Assert Leaderboard components
        expect(find.text('Total Leaderboard'), findsOneWidget);
        expect(find.text('1.'), findsOneWidget);
        expect(find.text('2.'), findsOneWidget);
        expect(find.text('3.'), findsOneWidget);
        expect(find.text('4.'), findsOneWidget);

        // Leaderboard vote indicators
        expect(find.text('voted Bob'), findsNWidgets(3)); // Alice, Charlie, Diana voted Bob
        expect(find.text('voted Alice'), findsOneWidget); // Bob voted Alice

        // Leaderboard score deltas
        expect(find.text('+100'), findsNWidgets(2)); // Alice and Diana earned +100
        expect(find.text('+50'), findsOneWidget); // Bob earned +50

        // Buttons
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Return to main menu'), findsOneWidget);
      });
    }

    testWidgets('VP.2: Defeat hero banner layout scaling on 320x480 viewport', (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 480);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Player 1', 'Player 2', 'Player 3'],
        scoresMap: {'Player 1': 100, 'Player 2': 0, 'Player 3': 0},
        roundPoints: {0: 100, 1: 0, 2: 0},
        votesMap: {0: 1, 1: 2, 2: 0}, // No majority
        frauds: {0},
        caughtByMajority: false,
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('THE FRAUD ESCAPED'), findsOneWidget);
    });

    testWidgets('VP.3: Undercover role pill rendering and scaling across viewports', (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 480);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Alice', 'Bob', 'Charlie', 'Diana'],
        scoresMap: {'Alice': 100, 'Bob': 100, 'Charlie': 100, 'Diana': 0},
        roundPoints: {0: 100, 1: 100, 2: 100, 3: 0},
        votesMap: {0: 3, 1: 3, 2: 3, 3: 0},
        frauds: {3},
        undercoverIdx: 1,
        mode: availableGameModes.firstWhere((m) => m.hasUndercover),
        word: 'Espresso',
        undercoverWord: 'Cappuccino',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Undercover: Bob (Cappuccino)'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 2: EXTREME TEXT, LONG NAMES, UNICODE & MAX PLAYERS
  // =========================================================================
  group('Group 2: Extreme Text, Long Names, Unicode & Max Players Stress', () {
    testWidgets('EX.1: 30+ character names with "voted <target>" on 320px viewport without overflow',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final extremeNames = [
        'MaximilianAlexanderTheThirdSuperLong',
        'ConstantineBartholomewTheGreatest',
        'PrincessAnastasiaSeraphinaRosewood',
        'ArchdukeFerdinandLeopoldMaximilian',
      ];

      final scores = {
        extremeNames[0]: 9990,
        extremeNames[1]: 8500,
        extremeNames[2]: 7200,
        extremeNames[3]: 5000,
      };
      final points = {0: 100, 1: 100, 2: 100, 3: 50};
      final votes = {0: 3, 1: 3, 2: 3, 3: 0};

      configureResultState(
        tester,
        playerList: extremeNames,
        scoresMap: scores,
        roundPoints: points,
        votesMap: votes,
        frauds: {3},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Long 30+ char names with voted indicators must not overflow 320px viewport');

      // Verify that all 4 leaderboard entries exist
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);

      // Verify the voted texts exist in widget tree
      expect(find.text('voted ${extremeNames[3]}'), findsNWidgets(3));
      expect(find.text('voted ${extremeNames[0]}'), findsOneWidget);
    });

    testWidgets('EX.2: Arabic RTL, Emojis, and special characters on 320px viewport',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 568);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final arabicEmojiNames = [
        'محمد بن عبدالعزيز آل سعود 👑',
        'سارة بنت فيصل الشمري 🌟',
        'خالد_المحارب_السري_الذكي_🔥',
        'عبدالله بن فهد المنصور القحطاني 🕵️‍♂️',
      ];

      final scores = {
        arabicEmojiNames[0]: 100,
        arabicEmojiNames[1]: 200,
        arabicEmojiNames[2]: 150,
        arabicEmojiNames[3]: 50,
      };
      final points = {0: 100, 1: 100, 2: 100, 3: 50};
      final votes = {0: 3, 1: 3, 2: 3, 3: 0};

      configureResultState(
        tester,
        playerList: arabicEmojiNames,
        scoresMap: scores,
        roundPoints: points,
        votesMap: votes,
        frauds: {3},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Arabic RTL and emoji player names must not overflow or crash');

      expect(find.text('voted ${arabicEmojiNames[3]}'), findsNWidgets(3));
      expect(find.text('voted ${arabicEmojiNames[0]}'), findsOneWidget);
    });

    testWidgets('EX.3: Maximum player count (10 players) with scrolling and action button tapping',
        (WidgetTester tester) async {
      setViewport(tester, width: 375, height: 667);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final tenPlayers = List.generate(10, (i) => 'Player ${i + 1}');
      final scores = {for (int i = 0; i < 10; i++) tenPlayers[i]: (10 - i) * 100};
      final points = {for (int i = 0; i < 10; i++) i: (i % 2 == 0 ? 100 : 0)};
      final votes = {for (int i = 0; i < 10; i++) i: (i == 9 ? 0 : 9)};

      configureResultState(
        tester,
        playerList: tenPlayers,
        scoresMap: scores,
        roundPoints: points,
        votesMap: votes,
        frauds: {9},
        mode: availableGameModes[0],
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);

      // Verify all 10 ranks are in the leaderboard
      for (int i = 1; i <= 10; i++) {
        expect(find.text('$i.'), findsOneWidget);
      }

      // Scroll to bottom and tap "Continue"
      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('category'),
          reason: 'Tapping Continue on 10-player results screen safely routes to category selection');
      expect(tester.takeException(), isNull);
    });

    testWidgets('EX.4: Long Secret Word (36 chars) and long category name stress',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 480);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Alice', 'Bob', 'Charlie'],
        scoresMap: {'Alice': 100, 'Bob': 50, 'Charlie': 0},
        roundPoints: {0: 100, 1: 50, 2: 0},
        votesMap: {0: 1, 1: 0, 2: 1},
        frauds: {1},
        category: 'Extremely Long Category Name That Might Wrap',
        word: 'Hippopotomonstrosesquippedaliophobia',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Long secret words and categories must not cause RenderFlex overflow');
      expect(find.text('Hippopotomonstrosesquippedaliophobia'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: NULL-SAFETY & STATE CORRUPTION STRESS
  // =========================================================================
  group('Group 3: Null-Safety & State Corruption Stress', () {
    testWidgets('NC.1: Empty playerVotes map renders gracefully with zero exceptions',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Player 1', 'Player 2', 'Player 3', 'Player 4'],
        scoresMap: {'Player 1': 100, 'Player 2': 100, 'Player 3': 0, 'Player 4': 0},
        roundPoints: {0: 100, 1: 100, 2: 0, 3: 0},
        votesMap: {}, // Empty votes map!
        frauds: {2},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Empty playerVotes must not throw exceptions or crash');

      // No "voted" text should be present
      expect(find.textContaining('voted '), findsNothing);

      // Player names and points should still render cleanly
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.text('Player 3'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
    });

    testWidgets('NC.2: Out-of-bounds target indices (999, -1, -999) handled gracefully without crashing',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final corruptedVotes = <int, int>{
        0: 999, // Way above player count
        1: -1, // Negative target index
        2: -999, // Wildly negative target index
        3: 1, // Valid target index
      };

      configureResultState(
        tester,
        playerList: ['Player 1', 'Player 2', 'Player 3', 'Player 4'],
        scoresMap: {'Player 1': 0, 'Player 2': 0, 'Player 3': 0, 'Player 4': 100},
        roundPoints: {0: 0, 1: 0, 2: 0, 3: 100},
        votesMap: corruptedVotes,
        frauds: {1},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Corrupted target indices must be filtered out gracefully without throwing');

      // Only the valid vote (Player 4 voted Player 2) should render "voted Player 2"
      expect(find.text('voted Player 2'), findsOneWidget);
      expect(find.textContaining('voted '), findsOneWidget);
    });

    testWidgets('NC.3: Phantom voter indices not in players list do not corrupt leaderboard rendering',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final phantomVotes = <int, int>{
        999: 0,
        -10: 1,
        0: 1,
        1: 0,
      };

      configureResultState(
        tester,
        playerList: ['Alpha', 'Beta'],
        scoresMap: {'Alpha': 100, 'Beta': 50},
        roundPoints: {0: 100, 1: 50},
        votesMap: phantomVotes,
        frauds: {1},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('voted Beta'), findsOneWidget); // Alpha voted Beta
      expect(find.text('voted Alpha'), findsOneWidget); // Beta voted Alpha
    });

    testWidgets('NC.4: Empty pointsEarnedThisRound map renders without badges and without exceptions',
        (WidgetTester tester) async {
      setViewport(tester, width: 360, height: 640);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Player 1', 'Player 2'],
        scoresMap: {'Player 1': 50, 'Player 2': 0},
        roundPoints: {}, // No points earned map
        votesMap: {0: 1, 1: 0},
        frauds: {1},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('+50'), findsNothing);
      expect(find.text('+0'), findsNothing);
      expect(find.text('50 pts'), findsOneWidget);
      expect(find.text('0 pts'), findsOneWidget);
    });

    testWidgets('NC.5: Extreme delta points (+9999 pts) and large cumulative scores do not overflow',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 480);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      configureResultState(
        tester,
        playerList: ['Player 1', 'Player 2'],
        scoresMap: {'Player 1': 99999, 'Player 2': 88888},
        roundPoints: {0: 9999, 1: 8888},
        votesMap: {0: 1, 1: 0},
        frauds: {1},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Large score values and +9999 badges must not overflow 320px viewport');
      expect(find.text('+9999'), findsOneWidget);
      expect(find.text('+8888'), findsOneWidget);
      expect(find.text('99999 pts'), findsOneWidget);
      expect(find.text('88888 pts'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: INTERACTIVE PLAYTHROUGH FLOW TO RESULT SCREEN AT NARROW VIEWPORT
  // =========================================================================
  group('Group 4: Interactive Gameplay to Result Flow at Narrow Viewport', () {
    testWidgets('FLOW.1: Complete Voting -> Guess -> Result -> Continue flow at 320x568',
        (WidgetTester tester) async {
      setViewport(tester, width: 320, height: 568);

      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Home -> Mode
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Mode -> Category
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Category -> Players
      final foodBtn = find.text('Food');
      await tester.ensureVisible(foodBtn);
      await tester.tap(foodBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // 4. Start round -> Pass phone
      final startRoundBtn = find.text('Start round');
      await tester.ensureVisible(startRoundBtn);
      await tester.tap(startRoundBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final playerCount = state.playerCount as int;

      // 5. Pass reveals
      for (int p = 0; p < playerCount; p++) {
        final revealBtn = find.text('Tap to reveal');
        await tester.ensureVisible(revealBtn);
        await tester.tap(revealBtn);
        await tester.pump(const Duration(milliseconds: 400));

        final isLast = p == playerCount - 1;
        final btnText = isLast ? 'Hide and start discussion' : 'Hide and pass on';
        final nextBtn = find.text(btnText);
        await tester.ensureVisible(nextBtn);
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 6. Discussion screen -> Tap Vote
      final voteBtn = find.text('Vote');
      await tester.ensureVisible(voteBtn);
      await tester.tap(voteBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen.toString(), contains('vote'));

      // 7. Complete voting for all players
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final targetFraud = fraudIndices.first;

      for (int v = 0; v < playerCount; v++) {
        final tapVoteBtn = find.text('Tap to vote');
        await tester.ensureVisible(tapVoteBtn);
        await tester.tap(tapVoteBtn);
        await tester.pump(const Duration(milliseconds: 50));

        if (v == targetFraud) {
          final alt = (targetFraud + 1) % playerCount;
          final targetPlayer = find.text(state.players[alt]);
          await tester.ensureVisible(targetPlayer);
          await tester.tap(targetPlayer);
        } else {
          final targetPlayer = find.text(state.players[targetFraud]);
          await tester.ensureVisible(targetPlayer);
          await tester.tap(targetPlayer);
        }
        await tester.pump(const Duration(milliseconds: 50));

        final confirmBtn = find.text('Vote');
        await tester.ensureVisible(confirmBtn);
        await tester.tap(confirmBtn);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // 8. Guess screen
      expect(find.text('Last chance!'), findsOneWidget);
      final correctWord = state.roundWord as String;

      // Fraud picks correct word
      final wordFinder = find.text(correctWord);
      await tester.ensureVisible(wordFinder);
      await tester.tap(wordFinder);
      await tester.pump(const Duration(milliseconds: 50));

      final confirmGuessBtn = find.text('Confirm guess');
      await tester.ensureVisible(confirmGuessBtn);
      await tester.tap(confirmGuessBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // 9. Results screen verification
      expect(state.screen.toString(), contains('result'));
      expect(tester.takeException(), isNull,
          reason: 'Result screen arrived at via full game flow must have zero overflow at 320px');

      // Verify group victory banner even though fraud guessed correctly per R6
      expect(find.text('THE PLAYERS WIN'), findsOneWidget);

      // Verify voter display on leaderboard
      expect(find.text('voted ${state.players[targetFraud]}'), findsWidgets);

      // 10. Tap Continue -> navigates to Category screen
      final continueBtn = find.text('Continue');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen.toString(), contains('category'));
      expect(tester.takeException(), isNull);
    });
  });
}
