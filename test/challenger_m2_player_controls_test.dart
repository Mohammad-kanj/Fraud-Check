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

  Future<void> navigateToPlayers(
    WidgetTester tester, {
    String mode = 'Classic',
    String category = 'Food',
    double width = 800,
    double height = 2400,
  }) async {
    setViewport(tester, width: width, height: height);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Play
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Mode
    await tester.tap(find.text(mode));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Category
    await tester.tap(find.text(category));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Challenger M2: Requirement R3 / F11 & F12 Player Setup Controls Stress Suite', () {
    testWidgets(
        'R3.1: Exactly ONE "Add player" button exists for all player counts from 3 to 9',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic');

      // Initially 4 players
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Add player'), findsOneWidget);

      // Reduce to 3 players (Classic mode minPlayers)
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // Empirically verify exactly ONE 'Add player' button at each count from 3 up to 9
      for (int count = 3; count <= 9; count++) {
        expect(
          find.byType(TextField),
          findsNWidgets(count),
          reason: 'Expected exactly $count player TextFields',
        );

        final addBtnFinder = find.text('Add player');
        expect(
          addBtnFinder,
          findsOneWidget,
          reason: 'Expected exactly ONE "Add player" button when players = $count',
        );

        // Advance to next count if below 9
        if (count < 9) {
          await tester.tap(addBtnFinder);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });

    testWidgets(
        'R3.2: "Add player" button is strictly positioned below the final player row for players 3..9',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic');

      // Reduce to 3 players first
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));

      for (int count = 3; count <= 9; count++) {
        final addBtnFinder = find.text('Add player');
        expect(addBtnFinder, findsOneWidget);

        final addBtnRect = tester.getRect(addBtnFinder);
        final lastFieldFinder = find.byType(TextField).at(count - 1);
        final lastFieldRect = tester.getRect(lastFieldFinder);
        final lastDeleteFinder = find.byTooltip('Remove player').at(count - 1);
        final lastDeleteRect = tester.getRect(lastDeleteFinder);

        // Verify strictly positioned below the final player's input and delete button
        expect(
          addBtnRect.top,
          greaterThan(lastFieldRect.bottom),
          reason:
              'At $count players, "Add player" top (${addBtnRect.top}) must be below final player TextField bottom (${lastFieldRect.bottom})',
        );

        expect(
          addBtnRect.top,
          greaterThan(lastDeleteRect.bottom),
          reason:
              'At $count players, "Add player" top (${addBtnRect.top}) must be below final player delete button bottom (${lastDeleteRect.bottom})',
        );

        // Also assert that every preceding player row 0..(count-1) is above the Add button
        for (int i = 0; i < count; i++) {
          final playerRect = tester.getRect(find.byType(TextField).at(i));
          expect(
            playerRect.bottom,
            lessThan(addBtnRect.top),
            reason:
                'Player $i TextField bottom (${playerRect.bottom}) must be strictly above "Add player" top (${addBtnRect.top})',
          );
        }

        // Advance to next count if below 9
        if (count < 9) {
          await tester.tap(addBtnFinder);
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });

    testWidgets(
        'R3.3: At maxPlayers (10), "Add player" button disappears, and reappears when player removed',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic');

      // Start from 4, add up to 10
      for (int i = 4; i < 10; i++) {
        expect(find.text('Add player'), findsOneWidget);
        await tester.tap(find.text('Add player'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Assert at maxPlayers (10)
      expect(find.byType(TextField), findsNWidgets(10));
      expect(
        find.text('Add player'),
        findsNothing,
        reason: 'At maxPlayers (10), "Add player" button MUST disappear',
      );

      // Verify that Start round and Back to main menu are still present and accessible
      expect(find.text('Start round'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);

      // Stress test: Remove 10th player -> "Add player" button MUST immediately reappear
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TextField), findsNWidgets(9));
      expect(
        find.text('Add player'),
        findsOneWidget,
        reason: '"Add player" button must reappear when roster shrinks from 10 to 9',
      );

      // Add back to 10 -> MUST disappear again
      await tester.tap(find.text('Add player'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TextField), findsNWidgets(10));
      expect(find.text('Add player'), findsNothing);
    });

    testWidgets(
        'R3.4: Horizontal distance between each player TextField and delete IconButton >= 28px',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic');

      // Reduce to 3 players
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));

      // Test across all roster sizes from 3 to 10
      for (int count = 3; count <= 10; count++) {
        expect(find.byType(TextField), findsNWidgets(count));
        final deleteButtons = find.byTooltip('Remove player');
        expect(deleteButtons, findsNWidgets(count));

        for (int i = 0; i < count; i++) {
          final tfRect = tester.getRect(find.byType(TextField).at(i));
          final btnRect = tester.getRect(deleteButtons.at(i));

          final horizontalGap = btnRect.left - tfRect.right;
          expect(
            horizontalGap,
            greaterThanOrEqualTo(28.0),
            reason:
                'Player $i at roster size $count: gap between TextField right (${tfRect.right}) and Delete button left (${btnRect.left}) is $horizontalGap px, which must be >= 28px',
          );

          // Assert vertical alignment: TextField and delete button should be vertically centered in the card
          expect(
            (tfRect.center.dy - btnRect.center.dy).abs(),
            lessThan(5.0),
            reason:
                'Player $i at roster size $count: TextField center.dy (${tfRect.center.dy}) and Delete button center.dy (${btnRect.center.dy}) must align within 5px',
          );
        }

        // Advance to next count if below 10
        if (count < 10) {
          await tester.tap(find.text('Add player'));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    });

    testWidgets(
        'R3.5: Multi-viewport stress test: gap >= 28px and 0 player row overflow on 320px, 390px, and 768px',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic', width: 800, height: 2400);

      final widths = [768.0, 390.0, 360.0, 320.0];

      for (final w in widths) {
        tester.view.physicalSize = Size(w, 2400);
        await tester.pump(const Duration(milliseconds: 50));

        final textFields = find.byType(TextField);
        final deleteBtns = find.byTooltip('Remove player');
        final currentCount = textFields.evaluate().length;

        for (int i = 0; i < currentCount; i++) {
          final tfRect = tester.getRect(textFields.at(i));
          final btnRect = tester.getRect(deleteBtns.at(i));
          final gap = btnRect.left - tfRect.right;

          expect(
            gap,
            greaterThanOrEqualTo(28.0),
            reason:
                'Viewport width ${w}px: Player $i gap was $gap px (expected >= 28px)',
          );
        }

        // Verify single Add button position
        final addBtnRect = tester.getRect(find.text('Add player'));
        final lastTfRect = tester.getRect(textFields.last);
        expect(
          addBtnRect.top,
          greaterThan(lastTfRect.bottom),
          reason: 'Viewport width ${w}px: Add player top must be below last TextField bottom',
        );
      }
    });

    testWidgets(
        'R3.6: Game Mode Boundary Stress: Two Frauds & Undercover modes enforce min=4 and max=10',
        (WidgetTester tester) async {
      for (final modeName in ['Two Frauds', 'Undercover']) {
        await navigateToPlayers(tester, mode: modeName);

        // Both Two Frauds & Undercover have minPlayers = 4
        expect(find.byType(TextField), findsNWidgets(4));
        expect(find.text('Add player'), findsOneWidget);

        // At minPlayers (4), delete buttons should be disabled
        final iconButtons = tester.widgetList<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
        for (final btn in iconButtons) {
          expect(btn.onPressed, isNull,
              reason: 'Delete buttons must be disabled at minPlayers (4) in $modeName mode');
        }

        // Add up to 10
        for (int count = 4; count < 10; count++) {
          expect(find.text('Add player'), findsOneWidget);
          await tester.tap(find.text('Add player'));
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(TextField), findsNWidgets(10));
        expect(
          find.text('Add player'),
          findsNothing,
          reason: 'At maxPlayers (10) in $modeName mode, "Add player" must disappear',
        );

        // Delete button is enabled at 10
        await tester.tap(find.byTooltip('Remove player').last);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TextField), findsNWidgets(9));
        expect(find.text('Add player'), findsOneWidget);

        // Reset widget tree for next iteration
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets(
        'R3.7: Interleaved insertion and deletion preserves ordering, gap >= 28px, and single Add button',
        (WidgetTester tester) async {
      await navigateToPlayers(tester, mode: 'Classic');

      // Type distinct names
      await tester.enterText(find.byType(TextField).at(0), 'Alpha');
      await tester.enterText(find.byType(TextField).at(1), 'Bravo');
      await tester.enterText(find.byType(TextField).at(2), 'Charlie');
      await tester.enterText(find.byType(TextField).at(3), 'Delta');
      await tester.pump(const Duration(milliseconds: 50));

      // Tap single Add player button
      await tester.tap(find.text('Add player'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now 5 players
      expect(find.byType(TextField), findsNWidgets(5));
      // Delete intermediate player (Bravo at index 1)
      await tester.tap(find.byTooltip('Remove player').at(1));
      await tester.pump(const Duration(milliseconds: 100));

      // Now 4 players: Alpha, Charlie, Delta, Player 5
      expect(find.byType(TextField), findsNWidgets(4));
      expect(find.text('Add player'), findsOneWidget);

      // Verify gap >= 28px for all remaining players
      for (int i = 0; i < 4; i++) {
        final tfRect = tester.getRect(find.byType(TextField).at(i));
        final btnRect = tester.getRect(find.byTooltip('Remove player').at(i));
        expect(btnRect.left - tfRect.right, greaterThanOrEqualTo(28.0));
      }

      // Add player position strictly below last player
      final addBtnRect = tester.getRect(find.text('Add player'));
      final lastTfRect = tester.getRect(find.byType(TextField).last);
      expect(addBtnRect.top, greaterThan(lastTfRect.bottom));
    });
  });
}
