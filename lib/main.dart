import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'categories.dart';

// Fraud Check — pass-and-play party game, one phone, 3–10 players.
// One player is the fraud and only sees the category.
// Everyone else sees the category and the secret word, and is SAFE.
// No login, no internet, no storage: scores and used words live
// only for this session.

// ---------- Colours ----------
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

// ---------- Sound effects ----------
// Tiny generated WAVs in assets/sounds/. Everything is wrapped in
// try/catch, so the game still works with no sound if a file is
// missing or playback fails on a device.
class Sound {
  static bool enabled = true;
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Sound is a bonus, never a blocker.
    }
  }

  static Future<void> tap() => play('tap');
  static Future<void> start() => play('start');
  static Future<void> reveal() => play('reveal');
  static Future<void> vote() => play('vote');
  static Future<void> guess() => play('guess');
  static Future<void> win() => play('win');
  static Future<void> lose() => play('lose');
}

void main() => runApp(const FraudCheckApp());

enum Screen {
  home,
  category,
  players,
  settings,
  howTo,
  pass,
  reveal,
  discuss,
  vote,
  guess,
  result,
}

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


// ---------- Balatro-style background ----------
// A slow, swirling, liquid background behind every screen: dark navy
// base, with large soft blobs in deep red, teal, gold and purple
// orbiting the centre, plus wavy rings that ripple around them.
// Kept dark and translucent so text and cards stay readable, and
// drawn with plain CustomPaint (no shader files, so the build
// needs nothing extra).
class BalatroBackground extends StatefulWidget {
  const BalatroBackground({super.key});

  @override
  State<BalatroBackground> createState() => _BalatroBackgroundState();
}

class _BalatroBackgroundState extends State<BalatroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _SwirlPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  final double t;
  const _SwirlPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = bg,
    );
    final centre = Offset(size.width / 2, size.height / 2);
    const blobColours = [
      Color(0xFF7A1F2B),
      Color(0xFF1F5A5A),
      Color(0xFF8A6D1F),
      Color(0xFF3A2A6B),
      Color(0xFF5A1F3A),
      Color(0xFF1F3A5A),
    ];
    for (var i = 0; i < blobColours.length; i++) {
      final angle = t * 2 * pi + i * (2 * pi / blobColours.length);
      final blobCentre = Offset(
        centre.dx + cos(angle) * size.width * 0.28,
        centre.dy + sin(angle) * size.height * 0.22,
      );
      final radius = size.longestSide * (0.28 + 0.06 * (i % 2));
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [blobColours[i].withAlpha(110), blobColours[i].withAlpha(0)],
        ).createShader(Rect.fromCircle(center: blobCentre, radius: radius));
      canvas.drawCircle(blobCentre, radius, paint);
    }
    for (var r = 0; r < 5; r++) {
      final baseRadius = size.longestSide * (0.10 + r * 0.09);
      final path = Path();
      for (var a = 0; a <= 64; a++) {
        final angle = a / 64 * 2 * pi;
        final ripple = 14 * sin(angle * 3 + t * 2 * pi + r);
        final radius = baseRadius + ripple;
        final point = Offset(
          centre.dx + radius * cos(angle),
          centre.dy + radius * sin(angle),
        );
        if (a == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (r.isEven ? yellow : green).withAlpha(28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SwirlPainter old) => old.t != t;
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
  // Voting: every player votes, one at a time, for someone else.
  int voteIdx = 0;
  bool voteRevealed = false;
  int? votePick;
  List<int> allVotes = [];
  Map<int, int> voteCounts = {};
  bool fraudCaughtByMajority = false;
  int fraudVoteCount = 0;
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
      voteIdx = 0;
      voteRevealed = false;
      votePick = null;
      allVotes = [];
      voteCounts = {};
      fraudCaughtByMajority = false;
      fraudVoteCount = 0;
      guessOptions = [];
      guessPick = null;
      for (final p in players) {
        scores.putIfAbsent(p, () => 0);
      }
      screen = Screen.pass;
    });
  }

  void showReveal() {
    Sound.reveal();
    setState(() {
      revealed = true;
      screen = Screen.reveal;
    });
  }

  void hideAndPass() {
    Sound.tap();
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

  void startVoting() {
    setState(() {
      voteIdx = 0;
      voteRevealed = false;
      votePick = null;
      allVotes = [];
      voteCounts = {};
      fraudCaughtByMajority = false;
      fraudVoteCount = 0;
      screen = Screen.vote;
    });
  }

  void confirmIndividualVote() {
    if (votePick == null) return;
    Sound.vote();
    setState(() {
      allVotes.add(votePick!);
      voteCounts[votePick!] = (voteCounts[votePick!] ?? 0) + 1;
      if (voteIdx < players.length - 1) {
        voteIdx++;
        votePick = null;
        voteRevealed = false;
      } else {
        tallyVotes();
      }
    });
  }

  void tallyVotes() {
    fraudVoteCount = voteCounts[fraudIndex] ?? 0;
    // The fraud is only caught if MORE THAN HALF of all votes
    // are for the fraud. Anything less, and the fraud wins.
    fraudCaughtByMajority = fraudVoteCount > players.length / 2;
    if (fraudCaughtByMajority) {
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
      Sound.lose();
    }
  }

  void confirmGuess() {
    if (guessPick == null) return;
    Sound.guess();
    setState(() {
      if (guessOptions[guessPick!] == roundWord) {
        scores[players[fraudIndex]] = (scores[players[fraudIndex]] ?? 0) + 1;
        screen = Screen.result;
        Sound.lose();
      } else {
        for (var i = 0; i < players.length; i++) {
          if (i != fraudIndex) {
            scores[players[i]] = (scores[players[i]] ?? 0) + 1;
          }
        }
        screen = Screen.result;
        Sound.win();
      }
    });
  }

  String get resultTitle {
    if (!fraudCaughtByMajority) return 'The fraud wins!';
    if (guessPick != null && guessOptions[guessPick!] == roundWord) {
      return 'The fraud escapes!';
    }
    return 'The players in the know win!';
  }

  String get resultLine {
    if (!fraudCaughtByMajority) {
      return 'Only $fraudVoteCount of ${players.length} voted for the fraud — not a majority, so the fraud takes the round.';
    }
    if (guessPick != null && guessOptions[guessPick!] == roundWord) {
      return 'The fraud guessed the word.';
    }
    return 'The fraud was caught and guessed wrong.';
  }

  Future<void> showPassOptions() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Options', textAlign: TextAlign.center),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'restart'),
            child: const Text('Restart round', textAlign: TextAlign.center),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'category'),
            child: const Text('Change category', textAlign: TextAlign.center),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'players'),
            child: const Text('Change players', textAlign: TextAlign.center),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'home'),
            child: const Text('Back to main menu', textAlign: TextAlign.center),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restart':
        Sound.start();
        startRound();
      case 'category':
        go(Screen.category);
      case 'players':
        go(Screen.players);
      case 'home':
        timer?.cancel();
        go(Screen.home);
      default:
        break;
    }
  }

  Widget passTopBar() => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onPressed: showPassOptions,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: BalatroBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          // Everything is centred: one centred column, max width 640,
          // centred text throughout.
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: switch (screen) {
                    Screen.home => _home(),
                    Screen.category => _category(),
                    Screen.players => _players(),
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
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Shared widgets (all centred) ----------

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
          child: Text(label, textAlign: TextAlign.center),
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
          child: Text(label, textAlign: TextAlign.center),
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
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      );

  Widget _mutedText(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, height: 1.55),
      );

  // Category name is always bright yellow, never the background colour,
  // so it stays readable on the dark cards.
  Widget _categoryLabel(String cat, {double size = 16}) => Text(
        cat,
        textAlign: TextAlign.center,
        style: TextStyle(color: yellow, fontSize: size, fontWeight: FontWeight.w800),
      );

  // "1 of 5" progress while the phone is being passed around.
  Widget _passProgress() => Text(
        '${passIdx + 1} of ${players.length}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w700),
      );

  // ---------- Screens ----------

  // Main menu: text buttons only, no icons, no tip, no tagline.
  Widget _home() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _logo(),
          const SizedBox(height: 10),
          const Text(
            'FRAUD CHECK',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 22),
          _primary('Play', () {
            Sound.tap();
            go(Screen.category);
          }),
          const SizedBox(height: 8),
          _secondary('Settings', () {
            Sound.tap();
            go(Screen.settings);
          }),
          const SizedBox(height: 8),
          _secondary('How to Play', () {
            Sound.tap();
            go(Screen.howTo);
          }),
        ],
      );

  // Page 1 of setup: pick a category. Tapping one moves straight on
  // to the players page. No "Step 1" label.
  Widget _category() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Pick a category'),
          const SizedBox(height: 4),
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
                onTap: () {
                  Sound.tap();
                  setState(() => chosenCat = cat);
                  go(Screen.players);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2F6B4F) : const Color(0xFF12153A),
                    border: Border.all(color: selected ? green : border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(categoryIcons[cat] ?? '🎭',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      _categoryLabel(cat),
                      Text('${categories[cat]!.length} words${selected ? ' ✓' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  // Page 2 of setup: how many players, and their names. No "Step 2" label.
  Widget _players() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Players'),
          if (chosenCat != null) ...[
            _categoryLabel(chosenCat!),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: playerCount > 3
                      ? () {
                          Sound.tap();
                          setPlayerCount(playerCount - 1);
                        }
                      : null,
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
                  onPressed: playerCount < 10
                      ? () {
                          Sound.tap();
                          setPlayerCount(playerCount + 1);
                        }
                      : null,
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
                textAlign: TextAlign.center,
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
          _primary('Start round', chosenCat == null
              ? null
              : () {
                  Sound.start();
                  startRound();
                }),
          const SizedBox(height: 8),
          _secondary('Change category', () => go(Screen.category)),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _settings() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Settings'),
          SwitchListTile(
            value: Sound.enabled,
            onChanged: (v) {
              setState(() => Sound.enabled = v);
              if (v) Sound.tap();
            },
            title: const Text('Sound effects', textAlign: TextAlign.center),
            activeColor: yellow,
          ),
          const Text('Discussion timer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...[0, 2, 3, 5].map((m) => RadioListTile<int>(
                value: m,
                groupValue: timerMinutes,
                onChanged: (v) => setState(() => timerMinutes = v ?? 0),
                title: Text(m == 0 ? 'No timer' : '$m minutes',
                    textAlign: TextAlign.center),
                activeColor: yellow,
              )),
          _mutedText('The timer is only a guide. You can vote early at any time.'),
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('How to Play'),
          _mutedText('You need 3–10 players and one phone.'),
          const SizedBox(height: 8),
          _card(Text(
              '1. Setup. Pick a category, then enter the players.\n\n'
              '2. Pass the phone. Each player looks at their own card, then hides it and passes it on. Players in the know see the word and are SAFE. The fraud sees only the category.\n\n'
              '3. Discuss. Give a clue or ask a question about the word. Never say the word itself.\n\n'
              '4. Vote. Each player, one at a time and in private, picks someone else. The fraud is only caught if more than half of all votes are for the fraud. If not, the fraud wins the round.\n\n'
              '5. Last chance. If the fraud was caught by a majority, the fraud picks from 4 words in the same category. Pick right and the fraud steals the round.\n\n'
              '6. Scoring. The fraud scores alone if they win. Otherwise every player in the know scores.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.55))),
          _primary('Start a game', () => go(Screen.category)),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _pass() {
    final name = players[passOrder[passIdx]];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Pass the phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _mutedText('No peeking! Only the person holding the phone should look.'),
            const SizedBox(height: 16),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _passProgress(),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        _passProgress(),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isFraud ? const Color(0xFF3D1220) : const Color(0xFF12392A),
            border: Border.all(color: isFraud ? red : green, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: isFraud
                ? [
                    const Text('YOU ARE THE FRAUD!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    _categoryLabel(roundCat, size: 20),
                  ]
                : [
                    const Text('YOU ARE SAFE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w900, color: green)),
                    const SizedBox(height: 14),
                    _categoryLabel(roundCat, size: 20),
                    const SizedBox(height: 10),
                    Text(roundWord,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w900, height: 1.15)),
                  ],
          ),
        ),
        const SizedBox(height: 14),
        _primary(last ? 'Hide and start discussion' : 'Hide and pass on', hideAndPass),
      ],
    );
  }

  Widget _discuss() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Discuss!'),
          _categoryLabel(roundCat, size: 20),
          const SizedBox(height: 10),
          _mutedText('Give a clue or ask a question about the word. Do not say the word itself.'),
          if (timerMinutes > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            ),
          ],
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Players, in order:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...players.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(p, textAlign: TextAlign.center),
                  )),
            ],
          )),
          _primary('Vote: who is the fraud?', startVoting),
        ],
      );

  Widget _vote() {
    // Voting happens one player at a time, in private: pass the
    // phone, tap to reveal your own voting list, pick someone
    // else (never yourself), confirm, then pass it on.
    if (!voteRevealed) {
      final voter = players[voteIdx];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          passTopBar(),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Pass the phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _mutedText('No peeking! Only the person voting should look.'),
              const SizedBox(height: 16),
              Text(voter,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Vote ${voteIdx + 1} of ${players.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: muted, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          )),
          _primary('Tap to vote', () {
            Sound.reveal();
            setState(() => voteRevealed = true);
          }),
        ],
      );
    }
    final voter = players[voteIdx];
    final others = List.generate(players.length, (i) => i)
        .where((i) => i != voteIdx)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        _title('Who is the fraud?'),
        Text('$voter, pick someone.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.55)),
        Text('Vote ${voteIdx + 1} of ${players.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: muted, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...others.map((i) {
          final selected = votePick == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Sound.tap();
                  setState(() => votePick = i);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? blue : card2,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: selected ? blue : border)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                child: Text(players[i], textAlign: TextAlign.center),
              ),
            ),
          );
        }),
        _primary('Confirm vote',
            votePick == null ? null : confirmIndividualVote),
      ],
    );
  }

  Widget _guess() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                  onPressed: () {
                    Sound.tap();
                    setState(() => guessPick = i);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected ? blue : card2,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: selected ? blue : border)),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  child: Text(guessOptions[i], textAlign: TextAlign.center),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _title(resultTitle),
        _mutedText(resultLine),
        const SizedBox(height: 8),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Fraud: ${players[fraudIndex]}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Word: $roundWord',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            _categoryLabel(roundCat),
            if (allVotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Votes for the fraud: $fraudVoteCount of ${players.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...players.map((name) {
                final idx = players.indexOf(name);
                final count = voteCounts[idx] ?? 0;
                return Text('$name: $count vote${count == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted));
              }),
            ],
          ],
        )),
        const SizedBox(height: 8),
        const Text('Scores',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
        _primary('Start a new round', () {
          Sound.start();
          startRound();
        }),
        const SizedBox(height: 8),
        _secondary('Return to main menu', () {
          timer?.cancel();
          go(Screen.home);
        }),
      ],
    );
  }
}
