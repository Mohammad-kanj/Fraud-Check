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

  Future<void> startRoundInMode(WidgetTester tester, {String modeTitle = 'Classic'}) async {
    setMobileScreen(tester);
    await tester.pumpWidget(const FraudCheckApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Play
    await tester.tap(find.text('Play'));
    await tester.pump(const Duration(milliseconds: 100));

    // Select mode
    await tester.tap(find.text(modeTitle));
    await tester.pump(const Duration(milliseconds: 100));

    // Select category Food
    await tester.tap(find.text('Food'));
    await tester.pump(const Duration(milliseconds: 100));

    // Start round
    await tester.tap(find.text('Start round'));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Pass-the-Phone Options Dialog Adversarial Tests (R4)', () {
    testWidgets('Options dialog renders separated pill boxes without "Change category" from Screen.pass',
        (WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Classic');

      // Verify on Screen.pass
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Open options dialog
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Change category'), findsNothing);
      expect(find.text('Change mode'), findsNothing);

      // Verify 4 pills: Restart round, Change players, Back to main menu, Cancel
      expect(find.text('Restart round'), findsOneWidget);
      expect(find.text('Change players'), findsOneWidget);
      expect(find.text('Back to main menu'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      final materials = tester.widgetList<Material>(find.byType(Material));
      final pillMaterials = materials.where((m) => m.shape is StadiumBorder).toList();
      expect(pillMaterials.length, greaterThanOrEqualTo(4));

      // Test Cancel dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsNothing);
      expect(find.text('Pass the phone'), findsOneWidget);
    });

    testWidgets('Options dialog can be opened and verified from Screen.reveal',
        (WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Classic');

      // Go to Screen.reveal
      await tester.tap(find.text('Tap to reveal'));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify on reveal screen
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Open options dialog from reveal screen
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Change category'), findsNothing);

      // Test Restart round from options dialog
      await tester.tap(find.text('Restart round'));
      await tester.pump(const Duration(milliseconds: 100));

      // After restart, options dialog is gone and round restarted on Screen.pass
      expect(find.text('Options'), findsNothing);
      expect(find.text('Pass the phone'), findsOneWidget);
    });

    testWidgets('Options dialog works on both stages of Screen.vote',
        (WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Classic');

      // Reveal and pass all 4 players to reach discuss
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = i == 3
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Discuss screen -> begin voting
      await tester.tap(find.text('Vote: who is the fraud?'));
      await tester.pump(const Duration(milliseconds: 100));

      // Vote Stage 1: Pass the phone to voter
      expect(find.text('Tap to vote'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Change category'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));

      // Vote Stage 2: Who is the fraud?
      await tester.tap(find.text('Tap to vote'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Who is the fraud?'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Change category'), findsNothing);

      // Test Back to main menu
      await tester.tap(find.text('Back to main menu'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Play'), findsOneWidget);
    });
  });

  group('Role Reveal Screen Adversarial Tests (R4)', () {
    testWidgets('Exhaustive role rendering verification in Undercover mode (Imposter, Undercover, Safe)',
        (WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Undercover');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final int undercoverIndex = state.undercoverIndex as int;
      final List<int> passOrder = (state.passOrder as List<int>);
      final String roundWord = state.roundWord as String;
      final String roundUndercoverWord = state.roundUndercoverWord as String;

      expect(fraudIndices.isNotEmpty, isTrue);
      expect(undercoverIndex, isNotNull);
      expect(roundWord.isNotEmpty, isTrue);
      expect(roundUndercoverWord.isNotEmpty, isTrue);
      expect(roundWord != roundUndercoverWord, isTrue);

      bool imposterSeen = false;
      bool undercoverSeen = false;
      bool safeSeen = false;

      // Iterate through every player in passOrder
      for (var p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);
        final isUndercover = playerIdx == undercoverIndex;
        final isSafe = !isFraud && !isUndercover;

        // Currently on Screen.pass
        expect(find.text('Pass the phone'), findsOneWidget);
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // CRITICAL CHECK: "1 of 4" or any "X of Y" MUST NOT appear on reveal screen!
        final countRegex = RegExp(r'\b\d+\s+of\s+\d+\b');
        final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final t in allTextWidgets) {
          if (t.data != null) {
            expect(countRegex.hasMatch(t.data!), isFalse,
                reason: 'Reveal screen must not display sequence counter like "1 of 4": found "${t.data}"');
          }
        }

        // Category pill must be present
        expect(find.textContaining('Category: Food'), findsOneWidget);

        if (isFraud) {
          imposterSeen = true;
          // Imposter presentation
          expect(find.text('🎭 IMPOSTER'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD!'), findsOneWidget);
          expect(find.text('? ? ?'), findsOneWidget);
          expect(find.text('SECRET WORD UNKNOWN'), findsOneWidget);
          expect(find.byIcon(Icons.theater_comedy_rounded), findsOneWidget);

          // Secret word MUST NOT be leaked to fraud
          expect(find.text(roundWord), findsNothing);
        } else if (isUndercover) {
          undercoverSeen = true;
          // Undercover presentation
          expect(find.text('🕵️ UNDERCOVER AGENT'), findsOneWidget);
          expect(find.text('YOU ARE UNDERCOVER!'), findsOneWidget);
          expect(find.text('YOUR DECOY WORD'), findsOneWidget);
          expect(find.text(roundUndercoverWord), findsOneWidget);
          expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

          // True secret word MUST NOT be shown to undercover
          expect(find.text(roundWord), findsNothing);
        } else if (isSafe) {
          safeSeen = true;
          // Safe presentation
          expect(find.text('🛡️ INNOCENT / SAFE'), findsOneWidget);
          expect(find.text('YOU ARE SAFE'), findsOneWidget);
          expect(find.text('YOUR SECRET WORD'), findsOneWidget);
          expect(find.text(roundWord), findsOneWidget);
          expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
        }

        // Advance to next player
        final isLast = p == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Confirm all 3 roles were verified in this round
      expect(imposterSeen, isTrue);
      expect(undercoverSeen, isTrue);
      expect(safeSeen, isTrue);
    });

    testWidgets('Two Frauds Mode visual presentation verification',
        (WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Two Frauds');

      final dynamic state = tester.state(find.byType(GamePage));
      final Set<int> fraudIndices = (state.fraudIndices as Set<int>);
      final List<int> passOrder = (state.passOrder as List<int>);

      expect(fraudIndices.length, equals(2));

      int fraudCountEncountered = 0;
      for (var p = 0; p < passOrder.length; p++) {
        final playerIdx = passOrder[p];
        final isFraud = fraudIndices.contains(playerIdx);

        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));

        // Category count indicator "X of Y" must be absent
        final countRegex = RegExp(r'\b\d+\s+of\s+\d+\b');
        for (final t in tester.widgetList<Text>(find.byType(Text))) {
          if (t.data != null) {
            expect(countRegex.hasMatch(t.data!), isFalse);
          }
        }

        if (isFraud) {
          fraudCountEncountered++;
          expect(find.text('🎭 IMPOSTER'), findsOneWidget);
          expect(find.text('YOU ARE THE FRAUD!'), findsOneWidget);
          expect(find.textContaining('There are 2 frauds this round!'), findsOneWidget);
        }

        final isLast = p == passOrder.length - 1;
        final nextBtn = isLast
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(fraudCountEncountered, equals(2));
    });
  });

  group('Voting Screen Typography, Spacing, and Selection Logic Tests (R5)', () {
    Future<void> setupVotingScreen(WidgetTester tester) async {
      await startRoundInMode(tester, modeTitle: 'Classic');

      // Pass all players through reveal
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Tap to reveal'));
        await tester.pump(const Duration(milliseconds: 400));
        final nextBtn = i == 3
            ? find.text('Hide and start discussion')
            : find.text('Hide and pass on');
        await tester.tap(nextBtn);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Discuss screen -> begin voting
      await tester.tap(find.text('Vote: who is the fraud?'));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap to vote
      await tester.tap(find.text('Tap to vote'));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('Typography >= 22px, FontWeight.w900, and spacing on candidate cards',
        (WidgetTester tester) async {
      await setupVotingScreen(tester);

      expect(find.text('Who is the fraud?'), findsOneWidget);

      // Verify suspect cards: 4 players total, so 3 suspect cards (current voter excluded)
      final suspectCards = tester.widgetList<Padding>(find.byType(Padding)).where((p) {
        return p.padding == const EdgeInsets.only(bottom: 14);
      }).toList();
      expect(suspectCards.length, equals(3));

      // Verify suspect player name typography
      final candidateTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.data != null && t.data!.startsWith('Player ') && t.style?.fontSize != null;
      }).toList();

      expect(candidateTexts.length, equals(3));
      for (final ct in candidateTexts) {
        expect(ct.style!.fontSize, greaterThanOrEqualTo(22),
            reason: 'Candidate name typography must be at least 22px');
        expect(ct.style!.fontWeight, equals(FontWeight.w900),
            reason: 'Candidate name font weight must be w900');
      }

      // Verify avatar badges (44x44) with candidate numbers
      final avatarBadges = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final box = c.decoration as BoxDecoration?;
        return box != null &&
            box.shape == BoxShape.circle &&
            c.constraints?.minWidth == 44 &&
            c.constraints?.minHeight == 44;
      }).toList();
      expect(avatarBadges.length, equals(3));

      // Verify suspect subtitles ('Suspect #X')
      expect(find.textContaining('Suspect #'), findsNWidgets(3));
    });

    testWidgets('Voter self-exclusion: current voter cannot vote for themselves',
        (WidgetTester tester) async {
      await setupVotingScreen(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final int currentVoterIdx = state.voteIdx as int;
      final List<String> players = (state.players as List<String>);
      final String currentVoterName = players[currentVoterIdx];

      // Check header shows Voter name
      expect(find.text('🗳️ Voter: $currentVoterName'), findsOneWidget);

      // Check candidate list contains exactly the other 3 players
      for (int i = 0; i < players.length; i++) {
        if (i == currentVoterIdx) {
          // Current voter's name must NOT appear in the candidate list
          final suspectMatches = tester.widgetList<Text>(find.byType(Text)).where((t) {
            return t.data == players[i] && t.style?.fontSize == 22;
          });
          expect(suspectMatches.isEmpty, isTrue,
              reason: 'Current voter ${players[i]} must not be a suspect candidate');
        } else {
          // Other players must appear as suspect candidate
          final suspectMatches = tester.widgetList<Text>(find.byType(Text)).where((t) {
            return t.data == players[i] && t.style?.fontSize == 22;
          });
          expect(suspectMatches.length, equals(1),
              reason: 'Player ${players[i]} must appear in candidate list');
        }
      }
    });

    testWidgets('Selection logic: radio toggle, dynamic confirmation button, and vote submission',
        (WidgetTester tester) async {
      await setupVotingScreen(tester);

      final dynamic state = tester.state(find.byType(GamePage));
      final List<String> players = (state.players as List<String>);

      // Initially, votePick is null, button is disabled
      expect(find.text('Select a suspect'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      // Tap confirm button when nothing is selected - should do nothing
      await tester.tap(find.text('Select a suspect'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.voteIdx, equals(0));

      // Tap the first candidate
      final unselectedRadios = find.byIcon(Icons.radio_button_unchecked_rounded);
      await tester.tap(unselectedRadios.at(0));
      await tester.pump(const Duration(milliseconds: 200));

      // First candidate selected: 1 checked, 2 unchecked
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));

      final firstPicked = state.votePick as int;
      expect(find.text('Confirm vote for ${players[firstPicked]}'), findsOneWidget);

      // Tap the second candidate: selection should switch
      final remainingRadios = find.byIcon(Icons.radio_button_unchecked_rounded);
      await tester.tap(remainingRadios.at(0));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));

      final secondPicked = state.votePick as int;
      expect(secondPicked != firstPicked, isTrue);
      expect(find.text('Confirm vote for ${players[secondPicked]}'), findsOneWidget);

      // Confirm vote
      await tester.tap(find.text('Confirm vote for ${players[secondPicked]}'));
      await tester.pump(const Duration(milliseconds: 100));

      // Advances to Voter 2 (voteIdx = 1, voteRevealed = false)
      expect(state.voteIdx, equals(1));
      expect(state.voteRevealed, isFalse);
      expect(find.text('Pass the phone'), findsOneWidget);
      expect(find.text('Vote 2 of 4'), findsOneWidget);
    });

    testWidgets('Full voting loop across all voters transitions cleanly to next game screen',
        (WidgetTester tester) async {
      await setupVotingScreen(tester);

      // 4 voters total. Voter 1 is at voting screen already.
      // Cast vote for Voter 1
      await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded).first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.textContaining('Confirm vote for'));
      await tester.pump(const Duration(milliseconds: 100));

      // Voters 2, 3, 4
      for (var v = 2; v <= 4; v++) {
        expect(find.text('Vote $v of 4'), findsOneWidget);
        await tester.tap(find.text('Tap to vote'));
        await tester.pump(const Duration(milliseconds: 100));

        // Select first available suspect
        await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded).first);
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.textContaining('Confirm vote for'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      // After last vote, tallyVotes runs and screen transitions to either Screen.guess or Screen.result
      final dynamic state = tester.state(find.byType(GamePage));
      final currentScreen = state.screen;
      expect(currentScreen == Screen.guess || currentScreen == Screen.result, isTrue);
    });
  });
}
