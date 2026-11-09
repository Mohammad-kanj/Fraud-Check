import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/main.dart';

void main() {
  setUp(() {
    Sound.enabled = false;
  });

  const matrixViewports = <String, Size>{
    '320x480 (Ultra-compact mobile)': Size(320, 480),
    '320x568 (iPhone 5 / SE 1)': Size(320, 568),
    '360x640 (Compact Android)': Size(360, 640),
    '375x667 (iPhone SE 2/3)': Size(375, 667),
    '390x844 (iPhone 12/13/14)': Size(390, 844),
    '412x915 (Modern Android flagship)': Size(412, 915),
    '768x1024 (iPad / Tablet portrait)': Size(768, 1024),
    '1024x1366 (iPad Pro portrait)': Size(1024, 1366),
    '1200x800 (Tablet landscape)': Size(1200, 800),
    '1920x1080 (Desktop 1080p landscape)': Size(1920, 1080),
  };

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Empirical Challenger 2: Viewport Matrix Stress Suite', () {
    for (final entry in matrixViewports.entries) {
      testWidgets('Matrix: Results Screen layout robustness on ${entry.key}', (WidgetTester tester) async {
        setViewport(tester, entry.value);
        await tester.pumpWidget(const FraudCheckApp());
        await tester.pump(const Duration(milliseconds: 100));

        final dynamic state = tester.state(find.byType(GamePage));
        final extremeNames = [
          'MaximilianAlexanderTheThirdSuperLong',
          'ConstantineBartholomewTheGreatest',
          'PrincessAnastasiaSeraphinaRosewood',
          'ArchdukeFerdinandLeopoldMaximilian',
        ];

        state.setState(() {
          state.screen = Screen.result;
          state.players = List<String>.from(extremeNames);
          state.playerCount = 4;
          state.scores.clear();
          state.scores.addAll({
            extremeNames[0]: 9999,
            extremeNames[1]: 8500,
            extremeNames[2]: 7200,
            extremeNames[3]: 5000,
          });
          state.pointsEarnedThisRound.clear();
          state.pointsEarnedThisRound.addAll({0: 100, 1: 100, 2: 100, 3: 50});
          state.playerVotes.clear();
          state.playerVotes.addAll({0: 3, 1: 3, 2: 3, 3: 0});
          state.roundCat = 'Extremely Long Category Name That Might Wrap';
          state.roundWord = 'Hippopotomonstrosesquippedaliophobia';
          state.fraudIndices = {3};
          state.fraudCaughtByMajority = true;
          state.caughtFrauds = {3};
          state.guessingFraudIndex = 3;
        });

        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull,
            reason: 'Results screen must render cleanly with 0 overflow on ${entry.key}');
        expect(find.text('The players win'), findsOneWidget);
        expect(find.text('Hippopotomonstrosesquippedaliophobia'), findsOneWidget);
        expect(find.text('Total Leaderboard'), findsOneWidget);
      });
    }

    testWidgets('Interactive flow at 320x480 ultra-compact viewport across all screens',
        (WidgetTester tester) async {
      setViewport(tester, const Size(320, 480));
      await tester.pumpWidget(const FraudCheckApp());
      await tester.pump(const Duration(milliseconds: 100));

      final dynamic state = tester.state(find.byType(GamePage));

      // Home
      expect(state.screen, equals(Screen.home));
      expect(tester.takeException(), isNull);

      // Rules
      await tester.tap(find.text('Rules'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.rules));
      expect(tester.takeException(), isNull);

      final rulesBackBtn = find.text('Back to main menu');
      await tester.ensureVisible(rulesBackBtn);
      await tester.tap(rulesBackBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.home));

      // Settings
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.settings));
      expect(tester.takeException(), isNull);

      final settingsBackBtn = find.text('Back to main menu');
      await tester.ensureVisible(settingsBackBtn);
      await tester.tap(settingsBackBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.home));

      // Mode
      await tester.tap(find.text('Play'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.mode));
      expect(tester.takeException(), isNull);

      // Category
      await tester.tap(find.text('Classic'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.category));
      expect(tester.takeException(), isNull);

      // Players
      final foodBtn = find.text('Food');
      await tester.ensureVisible(foodBtn);
      await tester.tap(foodBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.players));
      expect(tester.takeException(), isNull);

      // Start round -> Pass
      final startRoundBtn = find.text('Start round');
      await tester.ensureVisible(startRoundBtn);
      await tester.tap(startRoundBtn);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.screen, equals(Screen.pass));
      expect(tester.takeException(), isNull);

      // Reveal Player 0
      final revealBtn = find.text('Tap to reveal');
      await tester.ensureVisible(revealBtn);
      await tester.tap(revealBtn);
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.screen, equals(Screen.reveal));
      expect(tester.takeException(), isNull);
    });
  });
}
