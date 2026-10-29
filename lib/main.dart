import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'categories.dart';

// Fraud Check — pass-and-play party game, one phone, 3–10 players.
// One player is the fraud and only sees the category.
// Everyone else sees the category and the secret word.
// No login, no internet, no storage: scores and used words live
// only for this session.

const bg = Color(0xFF0F1226);
const card = Color(0xFF1B2044);
const card2 = Color(0xFF232A5C);
const border = Color(0xFF3A4390);
const ink = Color(0xFFF4F5FF);
const muted = Color(0xFFB8BDE3);
const yellow = Color(0xFFFFD23F);
const green = Color(0xFF3DDC84);
const red = Color(0xFFFF5D73);
const blue = Color(0xFF5AA9FF);

void main() => runApp(const FraudCheckApp());

enum Screen { home, play, settings, howTo, pass, reveal, discuss, vote, guess, result }

class FraudCheckApp extends StatelessWidget {
  const FraudCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fraud Check',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: yellow, surface: card),
        textTheme: ThemeData.dark().textTheme.apply(bodyColor: ink, displayColor: ink),
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  Screen screen = Screen.home;
  String? chosenCat;
  int playerCount = 4;
  List<String> players = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
  int timerMinutes = 0; // 0 = no timer
  final Map<String, int> scores = {};
  final Set<String> usedWords = {};

  // Current round.
  String roundCat = '';
  String roundWord = '';
  int fraudIndex = 0;
  List<int> passOrder = [];
  int passIdx = 0;
  bool revealed = false;
  int? voted;
  List<String> guessOptions = [];
  int? guessPick;
  Timer? timer;
  int secondsLeft = 0;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void go(Screen s) => setState(() => screen = s);

  void setPlayerCount(int n) {
    setState(() {
      playerCount = n.clamp(3, 10);
      while (players.length < playerCount) {
        players.add('Player ${players.length + 1}');
      }
      players = players.sublist(0, playerCount);
    });
  }

  void startRound() {
    final cat = chosenCat;
    if (cat == null) return;
    var pool = categories[cat]!
        .where((w) => !usedWords.contains('$cat|$w'))
        .toList();
    if (pool.isEmpty) {
      usedWords.removeWhere((k) => k.startsWith('$cat|'));
      pool = List.of(categories[cat]!);
    }
    final rng = Random();
    final word = pool[rng.nextInt(pool.length)];
    usedWords.add('$cat|$word');
    setState(() {
      roundCat = cat;
      roundWord = word;
      fraudIndex = rng.nextInt(players.length);
      passOrder = List.generate(players.length, (i) => i)..shuffle(rng);
      passIdx = 0;
      revealed = false;
      voted = null;
      guessOptions = [];
      guessPick = null;
      for (final p in players) {
        scores.putIfAbsent(p, () => 0);
      }
      screen = Screen.pass;
    });
  }

  void showReveal() => setState(() {
        revealed = true;
        screen = Screen.reveal;
      });

  void hideAndPass() {
    setState(() {
      if (passIdx < passOrder.length - 1) {
        passIdx++;
        revealed = false;
        screen = Screen.pass;
      } else {
        startDiscussion();
      }
    });
  }

  void startDiscussion() {
    timer?.cancel();
    setState(() {
      secondsLeft = timerMinutes * 60;
      screen = Screen.discuss;
    });
    if (timerMinutes > 0) {
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (secondsLeft > 0) secondsLeft--;
          if (secondsLeft == 0) t.cancel();
        });
      });
    }
  }

  void confirmVote() {
    if (voted == null) return;
    timer?.cancel();
    setState(() {
      if (voted == fraudIndex) {
        final decoys = categories[roundCat]!
            .where((w) => w != roundWord)
            .toList()
          ..shuffle();
        guessOptions = [roundWord, ...decoys.take(3)]..shuffle();
        guessPick = null;
        screen = Screen.guess;
      } else {
        scores[players[fraudIndex]] = (scores[players[fraudIndex]] ?? 0) + 1;
        screen = Screen.result;
      }
    });
  }

  void confirmGuess() {
    if (guessPick == null) return;
    setState(() {
      if (guessOptions[guessPick!] == roundWord) {
        scores[players[fraudIndex]] = (scores[players[fraudIndex]] ?? 0) + 1;
      } else {
        for (var i = 0; i < players.length; i++) {
          if (i != fraudIndex) {
            scores[players[i]] = (scores[players[i]] ?? 0) + 1;
          }
        }
      }
      screen = Screen.result;
    });
  }

  String get resultTitle {
    if (voted != null && voted != fraudIndex) return 'The fraud wins!';
    if (guessPick != null && guessOptions[guessPick!] == roundWord) {
      return 'The fraud escapes!';
    }
    return 'The players in the know win!';
  }

  String get resultLine {
    if (voted != null && voted != fraudIndex) {
      return 'The vote was wrong, so the fraud takes the round.';
    }
    if (guessPick != null && guessOptions[guessPick!] == roundWord) {
      return 'The fraud guessed the word.';
    }
    return 'The fraud was caught and guessed wrong.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: switch (screen) {
            Screen.home => _home(),
            Screen.play => _play(),
            Screen.settings => _settings(),
            Screen.howTo => _howTo(),
            Screen.pass => _pass(),
            Screen.reveal => _reveal(),
            Screen.discuss => _discuss(),
            Screen.vote => _vote(),
            Screen.guess => _guess(),
            Screen.result => _result(),
          },
        ),
      ),
    );
  }

  // ---------- Shared widgets ----------

  Widget _logo({double size = 150}) => ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.cover),
      );

  Widget _primary(String label, VoidCallback? onPressed) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: yellow,
            foregroundColor: const Color(0xFF1A1400),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          child: Text(label),
        ),
      );

  Widget _secondary(String label, VoidCallback onPressed) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: card2,
            foregroundColor: ink,
            side: const BorderSide(color: border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          child: Text(label),
        ),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: card,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      );

  Widget _mutedText(String text) => Text(
        text,
        style: const TextStyle(color: muted, height: 1.55),
      );

  // Category name is always bright yellow, never the background colour,
  // so it stays readable on the dark cards.
  Widget _categoryLabel(String cat, {double size = 16}) => Text(
        cat,
        style: TextStyle(color: yellow, fontSize: size, fontWeight: FontWeight.w800),
      );

  // ---------- Screens ----------

  // Main menu: text buttons only, no icons, no tip, no tagline.
  Widget _home() => Column(
        children: [
          _logo(),
          const SizedBox(height: 10),
          const Text(
            'FRAUD CHECK',
            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 22),
          _primary('Play', () => go(Screen.play)),
          const SizedBox(height: 8),
          _secondary('Settings', () => go(Screen.settings)),
          const SizedBox(height: 8),
          _secondary('How to Play', () => go(Screen.howTo)),
        ],
      );

  Widget _play() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Play'),
          const Text('Step 1 — Pick a category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.45,
            children: categories.keys.map((cat) {
              final selected = chosenCat == cat;
              return InkWell(
                onTap: () => setState(() => chosenCat = cat),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2F6B4F) : const Color(0xFF12153A),
                    border: Border.all(color: selected ? green : border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(categoryIcons[cat] ?? '🎭',
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      _categoryLabel(cat),
                      Text('${categories[cat]!.length} words${selected ? ' ✓' : ''}',
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text('Step 2 — How many players?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: playerCount > 3 ? () => setPlayerCount(playerCount - 1) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: yellow,
                      foregroundColor: const Color(0xFF1A1400),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  child: const Text('−'),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text('$playerCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: playerCount < 10 ? () => setPlayerCount(playerCount + 1) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: yellow,
                      foregroundColor: const Color(0xFF1A1400),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  child: const Text('+'),
                ),
              ),
            ],
          ),
          const Text('3 to 10 players. Names are optional.',
              textAlign: TextAlign.center, style: TextStyle(color: muted)),
          const SizedBox(height: 12),
          ...List.generate(playerCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('player-$i-$playerCount'),
                controller: TextEditingController(text: players[i])
                  ..selection = TextSelection.collapsed(offset: players[i].length),
                onChanged: (v) {
                  players[i] = v.trim().isEmpty ? 'Player ${i + 1}' : v.trim();
                },
                decoration: InputDecoration(
                  labelText: 'Player ${i + 1}',
                  filled: true,
                  fillColor: const Color(0xFF12153A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: border)),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _primary('Start round', chosenCat == null ? null : startRound),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _settings() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Settings'),
          const Text('Discussion timer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...[0, 2, 3, 5].map((m) => RadioListTile<int>(
                value: m,
                groupValue: timerMinutes,
                onChanged: (v) => setState(() => timerMinutes = v ?? 0),
                title: Text(m == 0 ? 'No timer' : '$m minutes'),
                activeColor: yellow,
              )),
          _mutedText('The timer is only a guide. You can vote early at any time.'),
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mutedText('One fraud per round. Words do not repeat until a category runs out.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      scores.clear();
                      usedWords.clear();
                      for (final p in players) {
                        scores[p] = 0;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scores and used words cleared.')));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: red, foregroundColor: Colors.white),
                  child: const Text('Reset scores and used words'),
                ),
              ),
            ],
          )),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _howTo() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('How to Play'),
          _mutedText('You need 3–10 players and one phone.'),
          const SizedBox(height: 8),
          _card(_mutedText(
              '1. Setup. Pick a category and enter the players.\n\n'
              '2. Pass the phone. Each player looks at their own card, then hides it and passes it on. Players in the know see the word. The fraud sees only the category.\n\n'
              '3. Discuss. Give a clue or ask a question about the word. Never say the word itself.\n\n'
              '4. Vote. Agree on one suspect and confirm.\n\n'
              '5. Last chance. If the vote was right, the fraud picks from 4 words in the same category. Pick right and the fraud steals the round.\n\n'
              '6. Scoring. The fraud scores alone if they win. Otherwise every player in the know scores.')),
          _primary('Start a game', () => go(Screen.play)),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _pass() {
    final name = players[passOrder[passIdx]];
    return Column(
      children: [
        _card(Column(
          children: [
            const Text('Pass the phone',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _mutedText('No peeking! Only the person holding the phone should look.'),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          ],
        )),
        _primary('Tap to reveal', showReveal),
      ],
    );
  }

  Widget _reveal() {
    final idx = passOrder[passIdx];
    final isFraud = idx == fraudIndex;
    final last = passIdx == passOrder.length - 1;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isFraud ? const Color(0xFF3D1220) : const Color(0xFF12392A),
            border: Border.all(color: isFraud ? red : green, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: isFraud
                ? [
                    // Fraud card: role + category only. Nothing else.
                    const Text('YOU ARE THE FRAUD!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    _categoryLabel(roundCat, size: 20),
                  ]
                : [
                    // In-the-know card: category + word only.
                    // No role label: if you can see a word, you are in.
                    _categoryLabel(roundCat, size: 20),
                    const SizedBox(height: 10),
                    Text(roundWord,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, height: 1.15)),
                  ],
          ),
        ),
        const SizedBox(height: 14),
        _primary(last ? 'Hide and start discussion' : 'Hide and pass on', hideAndPass),
      ],
    );
  }

  Widget _discuss() => Column(
        children: [
          _title('Discuss!'),
          _categoryLabel(roundCat, size: 20),
          const SizedBox(height: 10),
          _mutedText('Give a clue or ask a question about the word. Do not say the word itself.'),
          if (timerMinutes > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            ),
          ],
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Players, in order:',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...players.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(p),
                  )),
            ],
          )),
          _primary('Vote: who is the fraud?', () => go(Screen.vote)),
        ],
      );

  Widget _vote() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Who is the fraud?'),
          _mutedText('Agree on one suspect, tap their name, then confirm.'),
          const SizedBox(height: 10),
          ...List.generate(players.length, (i) {
            final selected = voted == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => voted = i),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? blue : card2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: selected ? blue : border)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  child: Text(players[i]),
                ),
              ),
            );
          }),
          _primary('Confirm vote', voted == null ? null : confirmVote),
          const SizedBox(height: 8),
          _secondary('Back to discussion', startDiscussion),
        ],
      );

  Widget _guess() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Last chance!'),
          _mutedText(
              'You caught the fraud, but they get one final guess. ${players[fraudIndex]}, pick the word you think it was. Pick right and you steal the round.'),
          const SizedBox(height: 10),
          ...List.generate(guessOptions.length, (i) {
            final selected = guessPick == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => guessPick = i),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? blue : card2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: selected ? blue : border)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  child: Text(guessOptions[i]),
                ),
              ),
            );
          }),
          _primary('Confirm guess', guessPick == null ? null : confirmGuess),
        ],
      );

  Widget _result() {
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(resultTitle),
        _mutedText(resultLine),
        const SizedBox(height: 8),
        _card(Column(
          children: [
            Text('Fraud: ${players[fraudIndex]}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              const Text('Word: ', style: TextStyle(color: muted)),
              _categoryLabel(roundCat),
              const Text(' — ', style: TextStyle(color: muted)),
              Expanded(
                  child: Text(roundWord,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ],
        )),
        const SizedBox(height: 8),
        const Text('Scores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...sorted.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${e.value}'),
                ],
              ),
            )),
        const SizedBox(height: 14),
        _primary('Play another round (same players)', startRound),
        const SizedBox(height: 8),
        _secondary('Change category / players', () => go(Screen.play)),
        const SizedBox(height: 8),
        _secondary('New game (clear scores)', () {
          setState(() {
            scores.clear();
            usedWords.clear();
            chosenCat = null;
            screen = Screen.home;
          });
        }),
      ],
    );
  }
}
