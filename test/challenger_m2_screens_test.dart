import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/categories.dart';
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

  // =========================================================================
  // Group 1: Requirement R2 / Feature F6 - Main Menu Redesign
  // =========================================================================
  group('Challenger M2: Requirement R2 / F6 Main Menu Redesign Adversarial Suite', () {
    testWidgets('MM.1: Play button renders with play icon, yellow party background, and transitions to mode selection',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Locate Play button
      final playBtnFinder = find.widgetWithText(ElevatedButton, 'Play');
      expect(playBtnFinder, findsOneWidget, reason: 'ElevatedButton with label "Play" must exist');

      final elevatedBtn = tester.widget<ElevatedButton>(playBtnFinder);
      final bg = elevatedBtn.style?.backgroundColor?.resolve({});
      expect(bg, const Color(0xFFFFC837), reason: 'Play button must use signature yellow party color');

      // 2. Verify Icons.play_arrow_rounded inside Play button
      expect(
        find.descendant(of: playBtnFinder, matching: find.byIcon(Icons.play_arrow_rounded)),
        findsOneWidget,
        reason: 'Play button must contain Icons.play_arrow_rounded',
      );

      // 3. Tap Play and verify transition to mode selection
      await tester.tap(playBtnFinder);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select Game Mode'), findsOneWidget,
          reason: 'Tapping Play must navigate to Game Mode selection screen');
    });

    testWidgets('MM.2: Dual action cards render Settings and Rules with respective icons in a balanced Row',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify existence of Settings and Rules
      final settingsFinder = find.text('Settings');
      final rulesFinder = find.text('Rules');
      expect(settingsFinder, findsOneWidget);
      expect(rulesFinder, findsOneWidget);

      // 2. Verify icons
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

      // 3. Verify horizontal alignment in a Row
      final settingsRect = tester.getRect(settingsFinder);
      final rulesRect = tester.getRect(rulesFinder);

      expect(
        (settingsRect.center.dy - rulesRect.center.dy).abs(),
        lessThan(3.0),
        reason: 'Settings and Rules action buttons must be horizontally aligned in a Row',
      );
      expect(
        settingsRect.right,
        lessThan(rulesRect.left),
        reason: 'Settings action card must be positioned to the left of Rules action card',
      );

      // 4. Test Settings navigation
      await tester.tap(settingsFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Audio Feedback'), findsOneWidget);
      expect(find.text('Screen Brightness'), findsOneWidget);

      // Return to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Test Rules navigation
      await tester.tap(find.text('Rules'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Roles & Objectives'), findsOneWidget);
    });

    testWidgets('MM.3: Arcade tagline badge "WHO IS THE FRAUD?" renders with rounded gold pill styling',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final badgeTextFinder = find.text('WHO IS THE FRAUD?');
      expect(badgeTextFinder, findsOneWidget, reason: 'Tagline badge "WHO IS THE FRAUD?" must be present');

      // Verify text style
      final textWidget = tester.widget<Text>(badgeTextFinder);
      expect(textWidget.style?.color, const Color(0xFFFFC837), reason: 'Tagline text must use yellow party accent');
      expect(textWidget.style?.fontWeight, FontWeight.w900);
      expect(textWidget.style?.letterSpacing, greaterThanOrEqualTo(1.2));

      // Verify pill container wrapping tagline
      final containerFinder = find.ancestor(of: badgeTextFinder, matching: find.byType(Container)).first;
      final container = tester.widget<Container>(containerFinder);
      final boxDeco = container.decoration as BoxDecoration?;
      expect(boxDeco, isNotNull);
      expect(boxDeco?.borderRadius, BorderRadius.circular(20));
      expect(boxDeco?.border, isNotNull);
    });

    testWidgets('MM.4: Strict absence: legacy phrases do not exist on Main Menu',
        (WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final legacyFull = ['the', 'english', 'barra', 'el', 'salfa'].join(' ');
      final legacyShort = ['barra', 'el', 'salfa'].join(' ');

      // Inspect every Text widget rendered on the screen
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final textData = (t.data ?? '').toLowerCase();
        expect(
          textData.contains(legacyFull),
          isFalse,
          reason: 'Main menu contains forbidden legacy subtitle: "${t.data}"',
        );
        expect(
          textData.contains(legacyShort),
          isFalse,
          reason: 'Main menu should not contain legacy text: "${t.data}"',
        );
      }
    });

    testWidgets('MM.5: Multi-viewport stress test: Main Menu renders without layout overflow down to 320px width',
        (WidgetTester tester) async {
      final viewports = [
        const Size(320, 568),  // iPhone SE 1st gen
        const Size(375, 667),  // iPhone 8
        const Size(390, 844),  // iPhone 13/14
        const Size(412, 915),  // Modern Android
        const Size(768, 1024), // Tablet
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 50));

        // Assert 0 layout overflow exceptions
        expect(tester.takeException(), isNull, reason: 'Layout overflowed on viewport $vp');

        // Play, Settings, Rules, Tagline must all be present and visible
        expect(find.text('Play'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Rules'), findsOneWidget);
        expect(find.text('WHO IS THE FRAUD?'), findsOneWidget);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  // =========================================================================
  // Group 2: Requirement R2 / Feature F7 - Settings Screen Redesign
  // =========================================================================
  group('Challenger M2: Requirement R2 / F7 Settings Screen Redesign Adversarial Suite', () {
    Future<void> navigateToSettings(WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('SET.1: Audio Feedback card renders volume icon, subtitle, toggleable SwitchListTile, and volume Slider',
        (WidgetTester tester) async {
      await navigateToSettings(tester);

      expect(find.byIcon(Icons.volume_up_rounded), findsWidgets);
      expect(find.text('Audio Feedback'), findsOneWidget);
      expect(find.text('Playful arcade sound effects and master volume'), findsOneWidget);

      final switchFinder = find.widgetWithText(SwitchListTile, 'Sound effects');
      expect(switchFinder, findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.activeThumbColor, const Color(0xFFFFC837),
          reason: 'SwitchListTile activeThumbColor must be yellow');

      // Adversarial toggle verification: toggle false -> true -> false
      expect(Sound.enabled, isFalse);
      await tester.tap(find.text('Sound effects'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(Sound.enabled, isTrue, reason: 'Tapping toggle when false must set Sound.enabled to true');

      await tester.tap(find.text('Sound effects'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(Sound.enabled, isFalse, reason: 'Tapping toggle when true must set Sound.enabled to false');
    });

    testWidgets('SET.2: Discussion timer card removed, replaced by in-app Screen Brightness slider',
        (WidgetTester tester) async {
      await navigateToSettings(tester);

      // Verify discussion timer is absent
      expect(find.byIcon(Icons.timer_rounded), findsNothing);
      expect(find.text('Discussion timer'), findsNothing);

      // Verify Screen Brightness card
      expect(find.byIcon(Icons.brightness_6_rounded), findsOneWidget);
      expect(find.text('Screen Brightness'), findsOneWidget);
      expect(find.text('Adjust in-app visual overlay brightness'), findsOneWidget);

      final dynamic state = tester.state(find.byType(GamePage));
      expect(state.brightness, equals(1.0));
    });

    testWidgets('SET.3: Session data reset card strictly absent from Settings screen',
        (WidgetTester tester) async {
      await navigateToSettings(tester);

      expect(find.text('Session Data'), findsNothing);
      expect(find.text('Reset scores and used words'), findsNothing);
    });
  });

  // =========================================================================
  // Group 3: Requirement R2 / Feature F9 - Pick Category UI Redesign
  // =========================================================================
  group('Challenger M2: Requirement R2 / F9 Pick Category UI Redesign Adversarial Suite', () {
    Future<void> navigateToCategory(WidgetTester tester) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('CAT.1: Header micro-badges render active mode and total category count',
        (WidgetTester tester) async {
      await navigateToCategory(tester);

      expect(find.text('Mode: Classic'), findsOneWidget);
      expect(find.text('${categories.length} Categories'), findsOneWidget);
      expect(find.text('Pick a category'), findsOneWidget);
    });

    testWidgets('CAT.2: All category cards render squircle emoji avatar (44x44, r:12) and word count micro-pills',
        (WidgetTester tester) async {
      await navigateToCategory(tester);

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<GridView>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2, reason: 'Category grid must be 2 columns');
      expect(delegate.childAspectRatio, 1.25, reason: 'Category grid cards must use 1.25 aspect ratio');

      // Verify every category has squircle emoji container and micro-pill scoped to its card
      for (final cat in categories.keys) {
        final catTextFinder = find.text(cat);
        expect(catTextFinder, findsOneWidget, reason: 'Category name "$cat" must be displayed');

        final cardFinder = find.ancestor(of: catTextFinder, matching: find.byType(InkWell)).first;

        final expectedWordCount = categories[cat]!.length;
        expect(
          find.descendant(of: cardFinder, matching: find.text('🏷️ $expectedWordCount words')),
          findsOneWidget,
          reason: 'Word count micro-pill "🏷️ $expectedWordCount words" must exist for $cat',
        );

        final expectedEmoji = categoryIcons[cat] ?? '🎭';
        expect(
          find.descendant(of: cardFinder, matching: find.text(expectedEmoji)),
          findsOneWidget,
          reason: 'Squircle avatar emoji "$expectedEmoji" must be present for $cat',
        );
      }
    });

    testWidgets('CAT.3: Selected category card renders gold border (2.2px) and gold checkmark badge',
        (WidgetTester tester) async {
      await navigateToCategory(tester);

      final dynamic state = tester.state(find.byType(GamePage));

      // Initially no category is chosen
      expect(state.chosenCat, isNull);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
          reason: 'Initially, no checkmark badge should appear when chosenCat is null');

      // Set chosenCat to 'Food' without changing screen
      state.setState(() {
        state.chosenCat = 'Food';
      });
      await tester.pump(const Duration(milliseconds: 50));

      // Assert gold checkmark badge appears strictly once
      final checkmarkFinder = find.byIcon(Icons.check_circle_rounded);
      expect(checkmarkFinder, findsOneWidget, reason: 'Exactly one gold checkmark badge must appear for selected category');

      final checkIcon = tester.widget<Icon>(checkmarkFinder);
      expect(checkIcon.color, const Color(0xFFFFC837), reason: 'Selection checkmark icon must be gold/yellow');
      expect(checkIcon.size, 20);

      // Verify checkmark is contained within the Food card
      final foodCardText = find.text('Food');
      final foodRect = tester.getRect(foodCardText);
      final checkRect = tester.getRect(checkmarkFinder);

      expect(checkRect.right, greaterThan(foodRect.right));
      expect(checkRect.top, lessThan(foodRect.top));
    });

    testWidgets('CAT.4: Tapping category updates state and advances to player setup screen',
        (WidgetTester tester) async {
      await navigateToCategory(tester);

      final dynamic state = tester.state(find.byType(GamePage));

      // Tap 'Animals' category
      await tester.tap(find.text('Animals'));
      await tester.pump(const Duration(milliseconds: 100));

      // State is updated
      expect(state.chosenCat, 'Animals');
      // Screen advanced to Players setup
      expect(find.text('Players'), findsOneWidget);
      expect(find.text('Animals'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 4: Requirement R2 / Feature F10 - End Screen Redesign
  // =========================================================================
  group('Challenger M2: Requirement R2 / F10 End Screen Redesign Adversarial Suite', () {
    Future<dynamic> setupEndScreen(
      WidgetTester tester, {
      required bool fraudCaught,
      required bool fraudGuessedCorrectly,
      int fraudIndex = 2,
      int? undercoverIndex,
      String roundWord = 'Sushi',
      String roundCat = 'Food',
      String undercoverWord = '',
      Map<String, int>? scores,
    }) async {
      setViewport(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));
      state.setState(() {
        state.players = ['Alice', 'Bob', 'Charlie', 'Diana'];
        state.playerCount = 4;
        state.roundCat = roundCat;
        state.roundWord = roundWord;
        state.fraudIndices = {fraudIndex};
        state.undercoverIndex = undercoverIndex;
        state.roundUndercoverWord = undercoverWord;
        state.fraudCaughtByMajority = fraudCaught;

        if (fraudCaught && fraudGuessedCorrectly) {
          state.guessingFraudIndex = fraudIndex;
          state.guessOptions = [roundWord, 'Taco', 'Burger'];
          state.guessPick = 0; // index of roundWord
        } else if (fraudCaught && !fraudGuessedCorrectly) {
          state.guessingFraudIndex = fraudIndex;
          state.guessOptions = [roundWord, 'Taco', 'Burger'];
          state.guessPick = 1; // wrong decoy
        } else {
          state.guessPick = null;
        }

        // Round points
        state.pointsEarnedThisRound = {
          0: fraudCaught && !fraudGuessedCorrectly ? 100 : 0,
          1: fraudCaught && !fraudGuessedCorrectly ? 100 : 0,
          2: (!fraudCaught || fraudGuessedCorrectly) ? 100 : 0,
          3: fraudCaught && !fraudGuessedCorrectly ? 100 : 0,
        };

        state.caughtFrauds = fraudCaught ? {fraudIndex} : <int>{};
        state.playerVotes = {0: fraudIndex, 1: fraudIndex, 2: 0, 3: fraudIndex};
        state.voteCounts = {fraudIndex: 3, 0: 1};
        state.allVotes = [fraudIndex, fraudIndex, 0, fraudIndex];

        if (scores != null) {
          state.scores.clear();
          state.scores.addAll(scores);
        } else {
          state.scores['Alice'] = 200;
          state.scores['Bob'] = 100;
          state.scores['Charlie'] = 300;
          state.scores['Diana'] = 0;
        }

        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));
      return state;
    }

    testWidgets('END.1: Victory Hero Banner renders trophy icon, green styling, and players win headline',
        (WidgetTester tester) async {
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
      );

      // Verify victory banner headline (no emoji)
      expect(find.text('PLAYERS IN THE KNOW WIN!'), findsOneWidget);
      expect(find.text('The players in the know win!'), findsOneWidget);
      expect(
        find.text('The fraud was caught by majority vote and failed to guess the secret word.'),
        findsOneWidget,
      );

      // Verify headline text color is green
      final headline = tester.widget<Text>(find.text('PLAYERS IN THE KNOW WIN!'));
      expect(headline.style?.color, const Color(0xFF10B981));
    });

    testWidgets('END.2: Defeat Hero Banner renders red styling, and fraud escaped headline',
        (WidgetTester tester) async {
      // Scenario A: Fraud escaped without being caught
      await setupEndScreen(
        tester,
        fraudCaught: false,
        fraudGuessedCorrectly: false,
      );

      expect(find.text('THE FRAUD ESCAPED!'), findsOneWidget);
      expect(find.text('The fraud wins!'), findsOneWidget);

      final headlineA = tester.widget<Text>(find.text('THE FRAUD ESCAPED!'));
      expect(headlineA.style?.color, const Color(0xFFFF3B5C));

      // Scenario B: Fraud caught by majority but stole the round by guessing secret word
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: true,
      );

      expect(find.text('THE FRAUD ESCAPED!'), findsOneWidget);
      expect(find.text('The fraud escapes!'), findsOneWidget);
    });

    testWidgets('END.3: Secret Word Reveal Card displays category squircle, mode badge, secret word, and fraud badge',
        (WidgetTester tester) async {
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
        roundWord: 'Falafel',
        roundCat: 'Food',
      );

      // Category squircle icon & category name
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Mode: Classic'), findsOneWidget);

      // Secret Word bold text in dimensional box
      expect(find.text('SECRET WORD'), findsOneWidget);
      final wordFinder = find.text('Falafel');
      expect(wordFinder, findsOneWidget);
      final wordText = tester.widget<Text>(wordFinder);
      expect(wordText.style?.fontSize, 32);
      expect(wordText.style?.fontWeight, FontWeight.w900);

      // Fraud identity badge in container
      final fraudBadge = find.text('Fraud: Charlie');
      expect(fraudBadge, findsOneWidget);
    });

    testWidgets('END.4: Undercover Mode reveal card displays purple undercover badge with decoy word',
        (WidgetTester tester) async {
      final state = await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
        undercoverIndex: 1, // Bob is undercover
        undercoverWord: 'Hummus',
      );

      state.setState(() {
        state.selectedMode = availableGameModes[2]; // undercover mode
      });
      await tester.pump(const Duration(milliseconds: 50));

      final underBadge = find.text('Undercover: Bob (Word: "Hummus")');
      expect(underBadge, findsOneWidget);
    });

    testWidgets('END.5: Legacy points card purged; round score delta (+100) rendered in leaderboard',
        (WidgetTester tester) async {
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
        fraudIndex: 2, // Charlie is fraud
      );

      // Legacy points card must be completely purged
      final legacyCardTitle = ['Barra', 'El', 'Salfa', 'Points', 'This', 'Round'].join(' ');
      expect(find.text(legacyCardTitle), findsNothing);

      // Round score deltas rendered next to current scores in leaderboard
      expect(find.text('+100'), findsNWidgets(3), reason: 'Three players earned +100 this round');
    });

    testWidgets('END.6: Ranked Podium renders clean numeric ranks (1., 2., 3., 4., 5.) and sorted scores',
        (WidgetTester tester) async {
      // 5-player test: Eve, Charlie, Alice, Bob, Diana
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
        scores: {
          'Eve': 500,     // 1st -> 1.
          'Charlie': 300, // 2nd -> 2.
          'Alice': 200,   // 3rd -> 3.
          'Bob': 100,     // 4th -> 4.
          'Diana': 0,     // 5th -> 5.
        },
      );

      expect(find.text('Total Leaderboard'), findsOneWidget);

      // Verify clean numeric ranks (no medal emojis)
      expect(find.text('🥇'), findsNothing);
      expect(find.text('🥈'), findsNothing);
      expect(find.text('🥉'), findsNothing);

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      expect(find.text('5.'), findsOneWidget);

      final lbCard = find.ancestor(
        of: find.text('Total Leaderboard'),
        matching: find.byType(Container),
      ).first;

      // Verify score chips inside Total Leaderboard card
      expect(find.descendant(of: lbCard, matching: find.text('500 pts')), findsOneWidget);
      expect(find.descendant(of: lbCard, matching: find.text('300 pts')), findsOneWidget);
      expect(find.descendant(of: lbCard, matching: find.text('200 pts')), findsOneWidget);
      expect(find.descendant(of: lbCard, matching: find.text('100 pts')), findsOneWidget);
      expect(find.descendant(of: lbCard, matching: find.text('0 pts')), findsOneWidget);

      // Verify vertical ordering: 1st is above 2nd, 2nd above 3rd, etc.
      final rect1 = tester.getRect(find.text('1.'));
      final rect2 = tester.getRect(find.text('2.'));
      final rect3 = tester.getRect(find.text('3.'));
      final rect4 = tester.getRect(find.text('4.'));
      final rect5 = tester.getRect(find.text('5.'));

      expect(rect1.top, lessThan(rect2.top));
      expect(rect2.top, lessThan(rect3.top));
      expect(rect3.top, lessThan(rect4.top));
      expect(rect4.top, lessThan(rect5.top));
    });

    testWidgets('END.7: Actions: "Continue" and "Return to main menu" properly navigate',
        (WidgetTester tester) async {
      final state = await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
      );

      // Verify button labels & icons
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(find.text('Return to main menu'), findsOneWidget);

      // Test Continue navigates to Screen.category preserving cumulative scores
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pick a category'), findsOneWidget);
      expect(state.scores['Alice'], equals(200));

      // Go back to end screen and test Return to main menu
      state.setState(() {
        state.screen = Screen.result;
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Return to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('WHO IS THE FRAUD?'), findsOneWidget);
    });

    testWidgets('END.8: Results screen layout hardening on narrow 320px viewport with Wrap badges and Expanded leaderboard player names',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longName = 'Sir Reginald Longname the Third of Fraudland';
      await setupEndScreen(
        tester,
        fraudCaught: true,
        fraudGuessedCorrectly: false,
        scores: {
          longName: 500,
          'Player Two': 250,
        },
      );

      // Verify Wrap is used for category and mode pills
      final wrapFinder = find.byType(Wrap);
      expect(wrapFinder, findsWidgets);

      final wrapWidget = tester.widget<Wrap>(find.descendant(
        of: find.byType(Column),
        matching: find.byWidgetPredicate((w) => w is Wrap && w.alignment == WrapAlignment.center && w.spacing == 8 && w.runSpacing == 6),
      ).first);
      expect(wrapWidget.alignment, equals(WrapAlignment.center));
      expect(wrapWidget.spacing, equals(8));
      expect(wrapWidget.runSpacing, equals(6));

      // Verify player name has TextOverflow.ellipsis and is wrapped in Expanded
      final longNameFinder = find.text(longName);
      expect(longNameFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(longNameFinder);
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));

      final expandedAncestor = find.ancestor(of: longNameFinder, matching: find.byType(Expanded));
      expect(expandedAncestor, findsWidgets);

      // Zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });
  });
}
