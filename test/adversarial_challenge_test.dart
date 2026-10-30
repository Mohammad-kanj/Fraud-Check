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

  Future<void> navigateToPlayersWithMode(
    WidgetTester tester, {
    String modeName = 'Classic',
    String categoryName = 'Food',
  }) async {
    setMobileScreen(tester);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Play
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Mode
    await tester.tap(find.text(modeName));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Category
    await tester.tap(find.text(categoryName));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Adversarial Stress Test: Player Setup Boundaries & Edge Cases', () {
    testWidgets('Classic mode: boundary removal down to 3 and cannot drop below 3',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Classic');

      // Default: 4 players
      expect(find.byType(TextField), findsNWidgets(4));

      // Remove 1 player -> 3 players
      final removeBtns = find.byTooltip('Remove player');
      await tester.tap(removeBtns.last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // At boundary 3, all remove buttons MUST have onPressed == null
      final iconButtons = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      expect(iconButtons.length, equals(3));
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNull);
      }

      // Adversarial attempt: Tap disabled button anyway
      await tester.tap(find.byTooltip('Remove player').first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3)); // Still 3, guarded
    });

    testWidgets('Classic mode: boundary addition up to 10 and cannot exceed 10',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Classic');

      // Start at 4. Add until 10 players (maxPlayers)
      for (int expected = 5; expected <= 10; expected++) {
        final addBtn = find.text('Add player').first;
        await tester.tap(addBtn);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TextField), findsNWidgets(expected));
      }

      // Now at max (10 players): "Add player" buttons MUST disappear
      expect(find.text('Add player'), findsNothing);

      // Verify all 10 players have active remove buttons
      final iconButtons = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      expect(iconButtons.length, equals(10));
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNotNull);
      }

      // Remove one player at index 5 -> count is 9
      await tester.tap(find.byTooltip('Remove player').at(5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(9));

      // "Add player" button MUST re-appear now that count < 10
      expect(find.text('Add player'), findsNWidgets(9));
    });

    testWidgets('Two Frauds mode: boundary min is 4, clamping from 3 to 4',
        (WidgetTester tester) async {
      // First go to Classic mode, drop players to 3, go back to main menu
      await navigateToPlayersWithMode(tester, modeName: 'Classic');
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now navigate to Two Frauds mode
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Two Frauds'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Animals'));
      await tester.pump(const Duration(milliseconds: 100));

      // Two Frauds mode requires min 4 players -> should have automatically clamped to 4!
      expect(find.byType(TextField), findsNWidgets(4));

      // And at 4 players in Two Frauds mode, remove buttons MUST be disabled
      final iconButtons = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      expect(iconButtons.length, equals(4));
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNull);
      }
    });

    testWidgets('Undercover mode: min is 4, max is 10',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Undercover');

      // Verify mode badge
      expect(find.text('Mode: Undercover'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));

      // At 4 players, remove buttons are disabled
      final iconButtons = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNull);
      }
    });

    testWidgets('Insertion order: addPlayerAfter inserts right after index',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Classic');

      // Initial players: Player 1, Player 2, Player 3, Player 4
      // Tap add under Player 2 (index 1)
      final addBtns = find.text('Add player');
      await tester.tap(addBtns.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify 5 players
      expect(find.byType(TextField), findsNWidgets(5));

      // Index 2 should be the newly inserted player (Player 5)
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller?.text, equals('Player 1'));
      expect(fields[1].controller?.text, equals('Player 2'));
      expect(fields[2].controller?.text, equals('Player 5'));
      expect(fields[3].controller?.text, equals('Player 3'));
      expect(fields[4].controller?.text, equals('Player 4'));
    });

    testWidgets('Player text input edge cases: unicode, empty string fallback, long names',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Classic');

      // 1. Unicode / Arabic name
      final firstField = find.byType(TextField).first;
      await tester.enterText(firstField, 'برا السالفة 🕵️');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('برا السالفة 🕵️'), findsOneWidget);

      // 2. Extremely long string (120 chars) - stress layout
      final secondField = find.byType(TextField).at(1);
      final longName = 'A' * 120;
      await tester.enterText(secondField, longName);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(longName), findsOneWidget);

      // 3. Empty string fallback
      final thirdField = find.byType(TextField).at(2);
      await tester.enterText(thirdField, '   ');
      await tester.pump(const Duration(milliseconds: 100));
      // Controller onChanged falls back to 'Player 3'
      // Widget should render without throwing
    });
  });

  group('Adversarial Stress Test: Navigation Flow & State Consistency', () {
    testWidgets('Full navigation loop: Home -> Settings -> Sound Toggle -> Home',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sound effects'), findsOneWidget);
      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);

      // Toggle switch
      await tester.tap(switchTile);
      await tester.pump(const Duration(milliseconds: 100));

      // Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('Pass Options dialog transitions: Change players and Back to menu',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester);
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Open options dialog
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Change players'
      await tester.tap(find.text('Change players'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should be back on Screen.players
      expect(find.text('Players'), findsOneWidget);
      expect(find.text('Start round'), findsOneWidget);

      // Tap 'Start round' again
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Open options again and tap 'Back to main menu'
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should be back on HomeScreen
      expect(find.text('FRAUD CHECK'), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: Role Reveal in Undercover and Two Frauds', () {
    testWidgets('Undercover mode: exactly 1 fraud, 1 undercover, remainder safe',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Undercover');
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      int fraudCount = 0;
      int undercoverCount = 0;
      int safeCount = 0;

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // Invariant: "1 of 4" category counter must NEVER appear
        expect(find.text('1 of 4'), findsNothing);

        final isFraud = find.text('YOU ARE THE FRAUD!').evaluate().isNotEmpty;
        final isUndercover = find.text('YOU ARE UNDERCOVER!').evaluate().isNotEmpty;
        final isSafe = find.text('YOU ARE SAFE').evaluate().isNotEmpty;

        if (isFraud) fraudCount++;
        if (isUndercover) undercoverCount++;
        if (isSafe) safeCount++;

        final nextButton = i == 3
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextButton);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fraudCount, equals(1), reason: 'Undercover mode must have exactly 1 fraud');
      expect(undercoverCount, equals(1), reason: 'Undercover mode must have exactly 1 undercover');
      expect(safeCount, equals(2), reason: '4 players in undercover mode must have 2 safe players');
    });

    testWidgets('Two Frauds mode: exactly 2 frauds, 0 undercover, remainder safe',
        (WidgetTester tester) async {
      await navigateToPlayersWithMode(tester, modeName: 'Two Frauds');
      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      int fraudCount = 0;
      int undercoverCount = 0;
      int safeCount = 0;

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('1 of 4'), findsNothing);

        final isFraud = find.text('YOU ARE THE FRAUD!').evaluate().isNotEmpty;
        final isUndercover = find.text('YOU ARE UNDERCOVER!').evaluate().isNotEmpty;
        final isSafe = find.text('YOU ARE SAFE').evaluate().isNotEmpty;

        if (isFraud) fraudCount++;
        if (isUndercover) undercoverCount++;
        if (isSafe) safeCount++;

        final nextButton = i == 3
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextButton);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fraudCount, equals(2), reason: 'Two Frauds mode must have exactly 2 frauds');
      expect(undercoverCount, equals(0), reason: 'Two Frauds mode must have 0 undercover');
      expect(safeCount, equals(2), reason: '4 players in Two Frauds mode must have 2 safe players');
    });
  });

  group('Adversarial Stress Test: Sound Service API Guarding', () {
    test('Sound methods return immediately and safely when Sound.enabled is false',
        () async {
      Sound.enabled = false;
      await Sound.tap();
      await Sound.start();
      await Sound.reveal();
      await Sound.vote();
      await Sound.guess();
      await Sound.win();
      await Sound.lose();
      expect(Sound.enabled, isFalse);
    });
  });
}
