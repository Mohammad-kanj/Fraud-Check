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

  group('Milestone M1 Empirical Challenger Verification Suite', () {
    testWidgets('Criteria 1: Main Menu - settings_rounded and menu_book_rounded icons are completely absent',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Home screen verification
      expect(find.text('FRAUD CHECK'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Rules'), findsOneWidget);

      // Verify that settings_rounded and menu_book_rounded are absent
      expect(find.byIcon(Icons.settings_rounded), findsNothing,
          reason: 'Icons.settings_rounded must be absent from main menu');
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing,
          reason: 'Icons.menu_book_rounded must be absent from main menu');
      expect(find.byIcon(Icons.settings), findsNothing,
          reason: 'Icons.settings must be absent from main menu');
      expect(find.byIcon(Icons.menu_book), findsNothing,
          reason: 'Icons.menu_book must be absent from main menu');

      // Check the action card containers for Settings and Rules to ensure no Icon widget is present inside them
      final settingsTextFinder = find.text('Settings');
      final settingsContainer = find.ancestor(
        of: settingsTextFinder,
        matching: find.byType(InkWell),
      );
      expect(settingsContainer, findsOneWidget);
      expect(
        find.descendant(of: settingsContainer, matching: find.byType(Icon)),
        findsNothing,
        reason: 'Settings action button must contain no icon widget',
      );

      final rulesTextFinder = find.text('Rules');
      final rulesContainer = find.ancestor(
        of: rulesTextFinder,
        matching: find.byType(InkWell),
      );
      expect(rulesContainer, findsOneWidget);
      expect(
        find.descendant(of: rulesContainer, matching: find.byType(Icon)),
        findsNothing,
        reason: 'Rules action button must contain no icon widget',
      );
    });

    testWidgets('Criteria 2: Settings Screen - "Audio" is present and "Audio Feedback" is absent',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Screen title
      expect(find.text('Settings'), findsWidgets);

      // Verify 'Audio' is present
      expect(find.text('Audio'), findsOneWidget,
          reason: '"Audio" section header must be present on Settings screen');

      // Verify 'Audio Feedback' is absent (both exact and case-insensitive check)
      expect(find.text('Audio Feedback'), findsNothing,
          reason: '"Audio Feedback" must be absent from Settings screen');
      expect(find.textContaining(RegExp(r'audio feedback', caseSensitive: false)), findsNothing,
          reason: 'Case-insensitive "audio feedback" must not appear on Settings screen');

      // Verify accompanying audio controls
      expect(find.text('Playful arcade sound effects and master volume'), findsOneWidget);
      expect(find.text('Sound effects'), findsOneWidget);
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('Criteria 3: Rules Screen - All 4 subsections exist, each inside its own distinct rounded card container',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to Rules
      await tester.tap(find.text('Rules'));
      await tester.pump(const Duration(milliseconds: 100));

      // 4 subsection titles
      final subsectionTitles = [
        'Overview',
        'Roles & Objectives',
        'Questioning Phase',
        'Voting & Scoring',
      ];

      for (final title in subsectionTitles) {
        expect(find.text(title), findsOneWidget,
            reason: 'Subsection "$title" must be present on the Rules screen');
      }

      // Check distinct rounded card containers
      final cardContainers = <Element>{};

      for (final title in subsectionTitles) {
        final titleFinder = find.text(title);
        // Find the containing card container
        final containerFinders = find.ancestor(
          of: titleFinder,
          matching: find.byType(Container),
        );

        Element? roundedCardElement;
        for (final elem in containerFinders.evaluate()) {
          final widget = elem.widget as Container;
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.borderRadius != null) {
            final radius = decoration.borderRadius;
            if (radius is BorderRadius && radius.topLeft.x > 0) {
              roundedCardElement = elem;
              break;
            }
          }
        }

        expect(roundedCardElement, isNotNull,
            reason: 'Subsection "$title" must be housed in a container with rounded border radius');
        cardContainers.add(roundedCardElement!);
      }

      // Verify all 4 containers are distinct instances
      expect(cardContainers.length, equals(4),
          reason: 'The 4 subsections must be rendered inside 4 distinct rounded card containers');
    });

    testWidgets('Criteria 4: Role Reveal - Category text has no emoji, no lock icon once revealed, "👁️ FRAUD" badge for fraud',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Start a Classic game
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      // Access GamePage state to inspect players and fraud role distribution
      final appState = tester.state(find.byType(GamePage).first) as dynamic;
      final int totalPlayers = (appState.players as List).length;
      final Set<int> fraudIndices = (appState.fraudIndices as Set).cast<int>();

      bool encounteredFraud = false;
      bool encounteredSafe = false;

      // Emoji detection regex
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]',
        unicode: true,
      );

      for (int i = 0; i < totalPlayers; i++) {
        expect(find.text('Pass the phone'), findsOneWidget);

        // Tap reveal
        await tester.tap(find.text('Tap to reveal'));
        // Wait for flip animation
        await tester.pump(const Duration(milliseconds: 450));

        // 1. Verify category text renders without any emoji
        final categoryFinder = find.textContaining('Category:');
        expect(categoryFinder, findsOneWidget);
        final categoryTextWidget = tester.widget<Text>(categoryFinder);
        final catText = categoryTextWidget.data!;
        expect(emojiRegex.hasMatch(catText), isFalse,
            reason: 'Category text "$catText" must not contain any emoji');
        expect(catText, equals('Category: Food'));

        // 2. Verify lock icons are NOT rendered once a player role is revealed
        expect(find.byIcon(Icons.lock_rounded), findsNothing,
            reason: 'Icons.lock_rounded must NOT be rendered when role is revealed');
        expect(find.byIcon(Icons.lock_open_rounded), findsNothing,
            reason: 'Icons.lock_open_rounded must NOT be rendered when role is revealed');
        expect(find.byIcon(Icons.lock), findsNothing,
            reason: 'Icons.lock must NOT be rendered when role is revealed');
        expect(find.byIcon(Icons.lock_open), findsNothing,
            reason: 'Icons.lock_open must NOT be rendered when role is revealed');
        expect(find.byIcon(Icons.lock_person_rounded), findsNothing,
            reason: 'Icons.lock_person_rounded must NOT be rendered on reveal screen');

        // 3. Verify eye emoji badge
        final int currentPassPlayerIdx = appState.passOrder[i] as int;
        final bool isCurrentFraud = fraudIndices.contains(currentPassPlayerIdx);

        if (isCurrentFraud) {
          encounteredFraud = true;
          expect(find.text('👁️ FRAUD'), findsOneWidget,
              reason: 'Fraud player must display the "👁️ FRAUD" eye emoji badge');
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        } else {
          encounteredSafe = true;
          expect(find.text('👁️ FRAUD'), findsNothing,
              reason: 'Safe player must NOT display "👁️ FRAUD" badge');
          expect(find.text('YOU ARE NOT THE FRAUD'), findsOneWidget);
        }

        // Tap hide and pass
        final hideButton = find.textContaining('Hide and');
        expect(hideButton, findsOneWidget);
        await tester.tap(hideButton);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(encounteredFraud, isTrue, reason: 'Must have tested at least one fraud player');
      expect(encounteredSafe, isTrue, reason: 'Must have tested at least one safe player');
    });

    testWidgets('Criteria 4b: Role Reveal - Chaos Mode renders "👁️ UNDERCOVER" and "👁️ FRAUD" with no lock icons',
        (WidgetTester tester) async {
      setMobileScreen(tester);
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Start Chaos game
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Chaos'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Food'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Start round'));
      await tester.pump(const Duration(milliseconds: 100));

      final appState = tester.state(find.byType(GamePage).first) as dynamic;
      final int totalPlayers = (appState.players as List).length;
      final Set<int> fraudIndices = (appState.fraudIndices as Set).cast<int>();
      final int undercoverIndex = appState.undercoverIndex as int;

      bool sawUndercover = false;
      bool sawFraud = false;

      for (int i = 0; i < totalPlayers; i++) {
        expect(find.text('Pass the phone'), findsOneWidget);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 450));

        // Check lock icons
        expect(find.byIcon(Icons.lock_rounded), findsNothing);
        expect(find.byIcon(Icons.lock_open_rounded), findsNothing);
        expect(find.byIcon(Icons.lock_person_rounded), findsNothing);

        final int playerIdx = appState.passOrder[i] as int;
        if (playerIdx == undercoverIndex) {
          sawUndercover = true;
          expect(find.text('👁️ UNDERCOVER'), findsOneWidget,
              reason: 'Undercover player must display "👁️ UNDERCOVER" badge');
          expect(find.text('YOU ARE UNDERCOVER'), findsOneWidget);
        } else if (fraudIndices.contains(playerIdx)) {
          sawFraud = true;
          expect(find.text('👁️ FRAUD'), findsOneWidget,
              reason: 'Fraud player must display "👁️ FRAUD" badge');
          expect(find.text('YOU ARE THE FRAUD'), findsOneWidget);
        }

        final hideButton = find.textContaining('Hide and');
        await tester.tap(hideButton);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(sawUndercover, isTrue, reason: 'Undercover role was revealed');
      expect(sawFraud, isTrue, reason: 'Fraud role was revealed');
    });
  });
}
