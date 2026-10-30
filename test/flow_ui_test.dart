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

  Future<void> startRound(WidgetTester tester) async {
    setMobileScreen(tester);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Play -> Classic -> Food -> Start round
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Classic'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Food'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Pass-the-Phone Options Dialog Tests (R4)', () {
    testWidgets('Options dialog renders separated pill boxes without "Change category"',
        (WidgetTester tester) async {
      await startRound(tester);

      // We are on Screen.pass. Open options dialog via more_vert button
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog is open
      expect(find.text('Options'), findsOneWidget);

      // Verify options
      expect(find.text('Restart round'), findsOneWidget);
      expect(find.text('Change players'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // "Change category" must NOT be in the dialog
      expect(find.text('Change category'), findsNothing);

      // Verify pill shapes (StadiumBorder)
      final materials = tester.widgetList<Material>(find.byType(Material));
      final pillMaterials = materials.where((m) => m.shape is StadiumBorder).toList();
      expect(pillMaterials.length, greaterThanOrEqualTo(4));

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsNothing);
    });
  });

  group('Role Reveal Screen Tests (R4)', () {
    testWidgets('Reveal screen does NOT show "1 of 4" and displays expressive presentation',
        (WidgetTester tester) async {
      await startRound(tester);

      // On Screen.pass, tap to reveal
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400)); // allow animation to finish

      // R4: "1 of 4" indicator must be removed
      expect(find.text('1 of 4'), findsNothing);

      // Category badge with emoji is shown
      expect(find.textContaining('Category: Food'), findsOneWidget);

      // Expressive visual presentation: either Fraud or Safe
      final isFraud = find.text('YOU ARE THE FRAUD!').evaluate().isNotEmpty;
      final isSafe = find.text('YOU ARE SAFE').evaluate().isNotEmpty;

      expect(isFraud || isSafe, isTrue);

      if (isFraud) {
        expect(find.text('🎭 IMPOSTER'), findsOneWidget);
        expect(find.text('SECRET WORD UNKNOWN'), findsOneWidget);
        expect(find.byIcon(Icons.theater_comedy_rounded), findsOneWidget);
      } else {
        expect(find.text('🛡️ INNOCENT / SAFE'), findsOneWidget);
        expect(find.text('YOUR SECRET WORD'), findsOneWidget);
        expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
      }
    });
  });

  group('Voting Screen Redesign Tests (R5)', () {
    testWidgets('Voting screen displays large typography (>=22px), suspect tags, and radio indicators',
        (WidgetTester tester) async {
      await startRound(tester);

      // Pass all 4 players through reveal to reach discussion
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        final nextButton = i == 3
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextButton);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Now on Screen.discuss
      expect(find.text('Discuss!'), findsOneWidget);

      // Tap vote button to begin voting
      await tester.tap(find.text('Vote: who is the fraud?'));
      await tester.pump(const Duration(milliseconds: 100));

      // Stage 1 of vote: Pass the phone to voter
      expect(find.text('Tap to vote'), findsOneWidget);
      await tester.tap(find.text('Tap to vote'));
      await tester.pump(const Duration(milliseconds: 100));

      // Now in Stage 2: Who is the fraud?
      expect(find.text('Who is the fraud?'), findsOneWidget);
      expect(find.textContaining('🗳️ Voter:'), findsOneWidget);

      // Check suspect subtitles
      expect(find.textContaining('Suspect #'), findsWidgets);

      // Check radio button indicators (unselected)
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsWidgets);

      // Check player typography: player name must be >= 22px
      final suspectTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.data != null && t.data!.startsWith('Player ') && t.style?.fontSize != null;
      }).toList();

      expect(suspectTexts, isNotEmpty);
      for (final st in suspectTexts) {
        expect(st.style!.fontSize, greaterThanOrEqualTo(22));
        expect(st.style!.fontWeight, equals(FontWeight.w900));
      }

      // Initial confirm button state
      expect(find.text('Select a suspect'), findsOneWidget);

      // Tap first suspect card
      final firstRadio = find.byIcon(Icons.radio_button_unchecked_rounded).first;
      await tester.tap(firstRadio);
      await tester.pump(const Duration(milliseconds: 250));

      // Should now show checked radio
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Confirm button should be dynamically enabled with suspect name
      expect(find.textContaining('Confirm vote for'), findsOneWidget);
    });
  });
}
