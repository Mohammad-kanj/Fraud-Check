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

  group('Main Menu & Rules Screen Widget Tests', () {
    testWidgets('Main menu displays "Rules" and does NOT display "How to Play"',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Rules'), findsOneWidget);
      expect(find.text('How to Play'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('Navigating to Rules screen displays "Rules" title',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Rules'));
      await tester.pump(const Duration(milliseconds: 100));

      // Rules screen title
      expect(find.widgetWithText(Column, 'Rules'), findsWidgets);
      expect(find.text('🎮 Game Modes'), findsOneWidget);
      expect(find.text('How to Play'), findsNothing);

      // Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Play'), findsOneWidget);
    });
  });

  group('Players Setup Screen Widget Tests', () {
    Future<void> navigateToPlayers(WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Play
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Classic mode
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap first category
      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Players screen removes top stepper and displays clean menu actions',
        (WidgetTester tester) async {
      await navigateToPlayers(tester);

      // Top number stepper buttons '−' and '+' in the old counter row should be absent
      expect(find.widgetWithText(ElevatedButton, '−'), findsNothing);

      // Bottom menu must have ONLY Start round and Back to main menu
      expect(find.text('Start round'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Change category'), findsNothing);
      expect(find.text('Change mode'), findsNothing);
    });

    testWidgets('Players screen has per-player remove button and add button under each player',
        (WidgetTester tester) async {
      await navigateToPlayers(tester);

      // Initially 4 players
      expect(find.byType(TextField), findsNWidgets(4));

      // Each player has a remove button
      final removeButtons = find.byTooltip('Remove player');
      expect(removeButtons, findsNWidgets(4));

      // Each player has an "Add player" button under it
      final addPlayerButtons = find.text('Add player');
      expect(addPlayerButtons, findsNWidgets(4));

      // Tap "Add player" under player 1
      await tester.tap(addPlayerButtons.first);
      await tester.pump(const Duration(milliseconds: 100));

      // Now 5 players
      expect(find.byType(TextField), findsNWidgets(5));

      // Tap remove button on player 5
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(4));

      // Remove down to 3 players (Classic minPlayers)
      await tester.tap(find.byTooltip('Remove player').last);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsNWidgets(3));

      // At minPlayers (3), remove buttons should be disabled (onPressed == null)
      final iconButtons = tester.widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.remove_circle_outline_rounded));
      for (final btn in iconButtons) {
        expect(btn.onPressed, isNull);
      }
    });
  });
}
