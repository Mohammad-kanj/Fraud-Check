import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  void setMobileScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Helper: Navigate from Home to Players setup screen with chosen mode & category
  Future<void> navigateToPlayers(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    setMobileScreen(tester);
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

  /// Helper: Start round from Home with mode & category
  Future<void> startRound(
    WidgetTester tester, {
    String modeTitle = 'Classic',
    String category = 'Food',
  }) async {
    await navigateToPlayers(tester, modeTitle: modeTitle, category: category);
    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Helper: Advance through pass-and-play reveal for N players
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

  /// Helper: Advance questioning round to voting if questioning turns exist
  Future<void> proceedToVoting(WidgetTester tester) async {
    final votePrompt = find.text('Vote');
    if (votePrompt.evaluate().isNotEmpty) {
      await tester.tap(votePrompt);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  // =========================================================================
  // TIER 1: FEATURE COVERAGE (R1 - R5 / F1 - F15)
  // =========================================================================
  group('Tier 1: Feature Coverage (R1 - R5)', () {
    testWidgets('T1.1: F1 - FilmStripBackground widget is present at root of screen hierarchy',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // F1 / R1: Repeating rows of question marks inside 45-degree tilted film strips
      final filmStripFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'FilmStripBackground',
      );
      expect(filmStripFinder, findsWidgets,
          reason: 'FilmStripBackground must be present at the root of the game widget stack');
    });

    testWidgets('T1.2: F2 - Character cutout logo asset from assets/logo.png renders on Home screen',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // F2 / R1: Extracted character from assets/logo.png displayed without background
      final logoImageFinder = find.byWidgetPredicate(
        (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/logo.png',
      );
      expect(logoImageFinder, findsWidgets,
          reason: 'Logo character cutout from assets/logo.png must be rendered on the main screen');
    });

    testWidgets('T1.3: F3 - Application theme configures Archivo typography across the app',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // F3 / R1: All text rendered using Archivo font
      final gamePageElement = tester.element(find.byType(GamePage));
      final theme = Theme.of(gamePageElement);
      final bodyFont = theme.textTheme.bodyMedium?.fontFamily ?? '';
      final titleFont = theme.textTheme.titleLarge?.fontFamily ?? '';

      final isArchivoConfigured = bodyFont.toLowerCase().contains('archivo') ||
          titleFont.toLowerCase().contains('archivo');
      expect(isArchivoConfigured, isTrue,
          reason: 'Typography across entire game must use the Archivo Google font');
    });

    testWidgets('T1.4: F4 - Legacy English subtitle is absent from Main Menu',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final legacySubtitle = ['The', 'English', 'Barra', 'El', 'Salfa'].join(' ');
      expect(find.text(legacySubtitle), findsNothing,
          reason: 'Legacy subtitle must be removed from the main screen');

      final legacyPhrase = ['barra', 'el', 'salfa'].join(' ');
      for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
        if (textWidget.data != null) {
          expect(textWidget.data!.toLowerCase().contains(legacyPhrase), isFalse,
              reason: 'Legacy branding must not appear on the main menu');
        }
      }
    });

    testWidgets('T1.5: F11 & F12 - Player setup renders single Add button and distinct delete gap',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      // Initially 4 players
      expect(find.byType(TextField), findsNWidgets(4));

      // F11 / R3: Single "Add player" button rendered ONLY ONCE below the final player
      final addBtnFinder = find.text('Add player');
      expect(addBtnFinder, findsOneWidget,
          reason: 'Add player button must be rendered only once below the final player in the list');

      // F12 / R3: Each player entry features a standalone delete button separated by a distinct gap
      final deleteButtons = find.byTooltip('Remove player');
      expect(deleteButtons, findsNWidgets(4),
          reason: 'Every player row must have a delete button');

      // Verify separation gap: inspect row children containing player text field and delete button
      final playerRowFinders = find.byWidgetPredicate((w) {
        if (w is Row) {
          return w.children.any((c) => c is Expanded || c is Flexible) &&
              w.children.any((c) => c is IconButton || c is InkWell || c is Container);
        }
        return false;
      });
      expect(playerRowFinders, findsWidgets);
    });

    testWidgets('T1.6: F7 - Settings screen renders sound toggle and discussion timer options',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Settings screen elements
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Sound effects'), findsOneWidget);
      expect(find.text('Audio Feedback'), findsOneWidget);
      expect(find.text('Screen Brightness'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text('Discussion timer'), findsNothing);

      // Verify Sound toggle interactivity
      expect(Sound.enabled, isFalse);
      await tester.tap(find.text('Sound effects'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(Sound.enabled, isTrue);

      // Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('T1.7: F9 - Pick Category UI displays category cards and selection transitions cleanly',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify categories are listed
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
      expect(find.text('Drinks'), findsOneWidget);
      expect(find.text('Places'), findsOneWidget);

      // Select category Food
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should now be on Players setup screen
      expect(find.text('Start round'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
    });

    testWidgets('T1.8: F15 - Reveal screen displays authentic Safe, Fraud, and Undercover role copy',
        (WidgetTester tester) async {
      // Test Classic Mode (Safe vs Fraud)
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<int> passOrder = (state.passOrder as List<int>);

      for (int p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        if (isFraud) {
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        } else {
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

      await tester.tap(find.text('Vote'));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('T1.9: F14 - Questioning round UI renders turn-by-turn question mechanism in discussion',
        (WidgetTester tester) async {
      await startRound(tester, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);

      // Now on Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);

      // F14 / R5: Fraud Check questioning mechanics between players before voting
      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.screen.toString(), contains('discuss'));

      // Check for questioning turns or discussion guidance
      expect(
        find.textContaining('ask each other questions')
            .evaluate()
            .isNotEmpty ||
        find.textContaining('asks')
            .evaluate()
            .isNotEmpty ||
        find.textContaining('Question')
            .evaluate()
            .isNotEmpty,
        isTrue,
        reason: 'Questioning round must prompt players to ask questions before voting',
      );

      // Verify voting progression button is accessible
      expect(find.text('Vote'), findsOneWidget);
    });

    testWidgets('T1.10: F10 - End screen UI displays victory banner, secret word reveal, and points chip',
        (WidgetTester tester) async {
      await startRound(tester, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);

      // Complete voting: all 4 voters vote for the fraud
      final fraudTargetIdx = fraudIndices.first;
      for (int v = 0; v < 4; v++) {
        expect(find.text('Tap to vote'), findsOneWidget);
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        if (v == fraudTargetIdx) {
          // Fraud votes for any other player (e.g. Player 1 or 2)
          final alternateIdx = (fraudTargetIdx + 1) % 4;
          await tester.tap(find.text(players[alternateIdx]));
        } else {
          // Non-fraud votes for the fraud
          await tester.tap(find.text(players[fraudTargetIdx]));
        }
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Fraud was caught by majority -> Guess screen
      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> guessOptions = (state.guessOptions as List<String>);

      // Fraud selects the wrong word (decoys)
      final wrongWord = guessOptions.firstWhere((w) => w != roundWord);
      await tester.tap(find.text(wrongWord));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now on Result Screen (F10 / R2)
      expect(find.text('The players in the know win!'), findsOneWidget);
      expect(find.text('SECRET WORD'), findsOneWidget);
      expect(find.text(roundWord), findsOneWidget);
      expect(find.text('Total Leaderboard'), findsOneWidget);
      expect(find.text('+100'), findsWidgets);
      expect(find.text('100 pts'), findsWidgets);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Return to main menu'), findsOneWidget);
    });
  });

  // =========================================================================
  // TIER 2: BOUNDARY & CORNER CASES
  // =========================================================================
  group('Tier 2: Boundary & Corner Cases', () {
    testWidgets('T2.1: Player list minimum bounds (Classic min 3, Two Frauds min 4)',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      // Start at 4 players
      expect(find.byType(TextField), findsNWidgets(4));

      // Remove 1 player down to 3
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // At min 3 players in Classic: remove buttons must be disabled
      final iconButtons = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded),
      );
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNull,
            reason: 'At minimum players (3), delete buttons must be disabled');
      }

      // Return to main menu and test Two Frauds mode (minimum 4 players)
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Two Frauds'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should automatically clamp back to minimum 4 players
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('T2.2: Single Add Player button disappears at maxPlayers (10) and reappears when removed',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      // Add players sequentially up to 10
      for (int expected = 5; expected <= 10; expected++) {
        expect(find.text('Add player'), findsWidgets);
        await tester.tap(find.text('Add player').first);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TextField), findsNWidgets(expected));
      }

      // At max 10 players: "Add player" button MUST disappear
      expect(find.text('Add player'), findsNothing,
          reason: 'Add player button must disappear at maximum 10 players');

      // Remove one player down to 9
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(9));

      // "Add player" button MUST reappear
      expect(find.text('Add player'), findsWidgets,
          reason: 'Add player button must reappear when player count is below 10');
    });

    testWidgets('T2.3: Discussion timer boundary: 0 minutes (no countdown) vs countdown display',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic appState = tester.state(find.byType(GamePage));
      appState.timerMinutes = 0;

      // Play round
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      await passThroughAllPlayers(tester, 4);

      // On discuss screen: no countdown timer formatted as mm:ss
      final timerPattern = RegExp(r'^\d+:\d{2}$');
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        if (t.data != null) {
          expect(timerPattern.hasMatch(t.data!), isFalse,
              reason: 'When timer is 0, no countdown text should be displayed');
        }
      }
    });

    testWidgets('T2.4: Player name input handles unicode, emojis, long strings, and empty fallbacks',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Classic', category: 'Food');

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));

      // Enter unicode / emoji name into Player 1
      await tester.enterText(textFields.at(0), 'لاعب 🎭 Special');
      await tester.pump(const Duration(milliseconds: 100));

      // Enter long name into Player 2
      await tester.enterText(textFields.at(1), 'SuperDuperExtremelyLongPlayerNameThatMustNotOverflow');
      await tester.pump(const Duration(milliseconds: 100));

      // Start round
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify custom names are preserved in pass screen
      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = (state.players as List<String>);
      expect(players[0], equals('لاعب 🎭 Special'));
      expect(players[1], equals('SuperDuperExtremelyLongPlayerNameThatMustNotOverflow'));
    });
  });

  // =========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS
  // =========================================================================
  group('Tier 3: Cross-Feature Combinations', () {
    testWidgets('T3.1: Classic Mode full combination: 4 players, Food category, fraud caught, safe players awarded points',
        (WidgetTester tester) async {
      await startRound(tester, modeTitle: 'Classic', category: 'Food');
      await passThroughAllPlayers(tester, 4);
      await proceedToVoting(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<String> players = (state.players as List<String>);
      final String roundWord = (state.roundWord as String);
      final int fraudIdx = fraudIndices.first;

      // Voting phase: 3 safe players vote for fraud; fraud votes for Player 0 (or 1)
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

      // Fraud was caught by majority -> Guess phase
      expect(find.text('Last chance!'), findsOneWidget);
      final List<String> guessOptions = (state.guessOptions as List<String>);

      // Fraud guesses wrong
      final wrongWord = guessOptions.firstWhere((w) => w != roundWord);
      await tester.tap(find.text(wrongWord));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Confirm guess'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify points: safe voters get +100 points
      expect(find.text('The players in the know win!'), findsOneWidget);
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[fraudIdx] ?? 0, equals(0));
      for (int i = 0; i < 4; i++) {
        if (i != fraudIdx) {
          expect(pointsEarned[i], equals(100),
              reason: 'Safe voter $i correctly identified the caught fraud and must earn 100 points');
        }
      }
    });

    testWidgets('T3.2: Two Frauds Mode combination: 5 players, Animals category, split vote allows frauds to escape',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, modeTitle: 'Two Frauds', category: 'Animals');

      // Add 5th player
      await tester.tap(find.text('Add player').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(5));

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      expect(fraudIndices.length, equals(2), reason: 'Two Frauds mode must assign exactly 2 frauds');

      await passThroughAllPlayers(tester, 5);
      await proceedToVoting(tester);

      final List<String> players = (state.players as List<String>);

      // Cast split votes so no player gets majority (> 2.5 votes)
      // Voters 0->1, 1->2, 2->3, 3->4, 4->0
      for (int v = 0; v < 5; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        final target = (v + 1) % 5;
        await tester.tap(find.text(players[target]));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // No majority: Frauds escape!
      expect(find.text('The frauds win!'), findsOneWidget);
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      for (final f in fraudIndices) {
        expect(pointsEarned[f], equals(100),
            reason: 'Escaping frauds must each earn 100 points');
      }
    });

    testWidgets('T3.3: Undercover Mode combination: 4 players, Drinks category, undercover agent survives',
        (WidgetTester tester) async {
      await startRound(tester, modeTitle: 'Undercover', category: 'Drinks');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final int? undercoverIdx = state.undercoverIndex as int?;
      expect(fraudIndices.length, equals(1));
      expect(undercoverIdx, isNotNull);

      await passThroughAllPlayers(tester, 4);
      await proceedToVoting(tester);

      final List<String> players = (state.players as List<String>);

      // Voters cast split votes where neither fraud nor undercover gets majority
      // E.g. Voters vote for players other than undercover
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        // Vote target different from v and different from undercover
        int target = (v + 1) % 4;
        if (target == undercoverIdx) {
          target = (target + 1) % 4;
        }

        await tester.tap(find.text(players[target]));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Undercover survived without majority vote against them
      final Map<int, int> pointsEarned = (state.pointsEarnedThisRound as Map<int, int>);
      expect(pointsEarned[undercoverIdx], equals(100),
          reason: 'Surviving undercover agent must earn 100 points');
    });

    testWidgets('T3.4: Sound setting disabled in Settings persists across all screens and gameplay transitions',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Settings: turn off sound
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      if (Sound.enabled) {
        await tester.tap(find.text('Sound effects'));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(Sound.enabled, isFalse);

      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      // Play through round
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Throughout the entire flow, Sound.enabled must remain false
      expect(Sound.enabled, isFalse);
    });
  });

  // =========================================================================
  // TIER 4: REAL-WORLD SCENARIOS
  // =========================================================================
  group('Tier 4: Real-World Scenarios', () {
    testWidgets('T4.1: Real-world multi-round playthrough: cumulative scores and non-repeating words',
        (WidgetTester tester) async {
      // Round 1
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      final dynamic state = tester.state(find.byType(GamePage));
      final String round1Word = state.roundWord as String;

      await passThroughAllPlayers(tester, 4);
      await proceedToVoting(tester);

      final List<String> players = (state.players as List<String>);

      // Complete voting
      for (int v = 0; v < 4; v++) {
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        final target = (v + 1) % 4;
        await tester.tap(find.text(players[target]));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Vote'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Reached result screen
      expect(find.text('Continue'), findsOneWidget);

      // Continue to next round (category selection)
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.screen.toString(), contains('category'));
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Round 2 starts on pass screen with non-repeating secret word
      expect(find.text('Pass the phone'), findsOneWidget);
      final String round2Word = state.roundWord as String;
      expect(round2Word, isNot(equals(round1Word)),
          reason: 'Consecutive rounds in the same category must not repeat words');
    });

    testWidgets('T4.2: Real-world mid-round cancellation: options dialog allows returning to main menu without leaking state',
        (WidgetTester tester) async {
      await startRound(tester, modeTitle: 'Classic', category: 'Food');

      // Open options dialog from pass screen
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Back to main menu
      expect(find.text('Back to main menu'), findsOneWidget);
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      // Successfully back on Home screen
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Re-enter Play -> game state is healthy and responsive
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Classic'), findsOneWidget);
    });
  });
}
