import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'categories.dart';

// Fraud Check — pass-and-play party game, one phone, 3–10 players.
// Inspired by "برا السالفة" (Barra El Salfa) — the English mobile edition.
// Modes: Classic (1 Fraud), Two Frauds (2 Frauds), Undercover (1 Fraud + 1 Undercover).
// Authentic Barra El Salfa scoring: 100 party points awarded to players who correctly vote for caught frauds.
// No login, no internet, no storage: scores and used words live only for this session.

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
const purple = Color(0xFFB066FF);

// Barra El Salfa party points
const int roundPoints = 100;

// ---------- Game Modes (Configurable in code) ----------
enum GameModeId {
  classic,
  twoFrauds,
  undercover,
}

class GameMode {
  final GameModeId id;
  final String title;
  final String subtitle;
  final int minPlayers;
  final int maxPlayers;
  final int fraudCount;
  final bool hasUndercover;

  const GameMode({
    required this.id,
    required this.title,
    required this.subtitle,
    this.minPlayers = 3,
    this.maxPlayers = 10,
    this.fraudCount = 1,
    this.hasUndercover = false,
  });
}

const List<GameMode> availableGameModes = [
  GameMode(
    id: GameModeId.classic,
    title: 'Classic',
    subtitle: '1 fraud who only knows the category. Pure deduction.',
    minPlayers: 3,
    fraudCount: 1,
    hasUndercover: false,
  ),
  GameMode(
    id: GameModeId.twoFrauds,
    title: 'Two Frauds',
    subtitle: '2 frauds in the mix. Double the chaos and deception!',
    minPlayers: 4,
    fraudCount: 2,
    hasUndercover: false,
  ),
  GameMode(
    id: GameModeId.undercover,
    title: 'Undercover',
    subtitle: '1 fraud + 1 undercover agent with a secret decoy word!',
    minPlayers: 4,
    fraudCount: 1,
    hasUndercover: true,
  ),
];

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
  mode,
  category,
  players,
  settings,
  rules,
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
class BalatroBackground extends StatefulWidget {
  const BalatroBackground({super.key});

  @override
  State<BalatroBackground> createState() => _BalatroBackgroundState();
}

class _BalatroBackgroundState extends State<BalatroBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        painter: _BalatroPainter(t: _ctrl.value * 2 * pi),
      ),
    );
  }
}

class _BalatroPainter extends CustomPainter {
  final double t;
  _BalatroPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0A0C1C);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final minDim = min(size.width, size.height);

    final blobs = [
      _Blob(
        color: const Color(0xFF8B1E3F),
        radius: minDim * 0.55,
        dist: minDim * 0.35,
        speed: 1.0,
        phase: 0.0,
      ),
      _Blob(
        color: const Color(0xFF0F5B66),
        radius: minDim * 0.50,
        dist: minDim * 0.30,
        speed: -0.7,
        phase: 2.1,
      ),
      _Blob(
        color: const Color(0xFF8C6D1F),
        radius: minDim * 0.45,
        dist: minDim * 0.40,
        speed: 0.5,
        phase: 4.2,
      ),
      _Blob(
        color: const Color(0xFF4B2375),
        radius: minDim * 0.60,
        dist: minDim * 0.25,
        speed: -1.2,
        phase: 1.3,
      ),
    ];

    for (final b in blobs) {
      final angle = t * b.speed + b.phase;
      final bx = cx + cos(angle) * b.dist;
      final by = cy + sin(angle) * b.dist;
      final paint = Paint()
        ..color = b.color.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, b.radius * 0.45);
      canvas.drawCircle(Offset(bx, by), b.radius, paint);
    }

    final wavePaint = Paint()
      ..color = const Color(0xFF5AA9FF).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (var ring = 1; ring <= 6; ring++) {
      final baseR = ring * (minDim * 0.11);
      final path = Path();
      const steps = 60;
      for (var i = 0; i <= steps; i++) {
        final a = (i / steps) * 2 * pi;
        final wave = sin(a * 4 + t * 2 + ring) * (minDim * 0.015) +
            cos(a * 2 - t + ring) * (minDim * 0.01);
        final r = baseR + wave;
        final px = cx + cos(a) * r;
        final py = cy + sin(a) * r;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_BalatroPainter oldDelegate) => oldDelegate.t != t;
}

class _Blob {
  final Color color;
  final double radius;
  final double dist;
  final double speed;
  final double phase;
  _Blob({
    required this.color,
    required this.radius,
    required this.dist,
    required this.speed,
    required this.phase,
  });
}

// ---------- Main Game Widget ----------
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  Screen screen = Screen.home;
  GameMode selectedMode = availableGameModes[0];
  String? chosenCat;
  int playerCount = 4;
  List<String> players = ['Player 1', 'Player 2', 'Player 3', 'Player 4'];
  int timerMinutes = 0; // 0 = no timer
  final Map<String, int> scores = {};
  final Set<String> usedWords = {};

  // Current round state.
  String roundCat = '';
  String roundWord = '';
  String roundUndercoverWord = '';
  Set<int> fraudIndices = {};
  int? undercoverIndex;
  List<int> passOrder = [];
  int passIdx = 0;
  bool revealed = false;

  // Voting: every player votes, one at a time, for someone else in private.
  int voteIdx = 0;
  bool voteRevealed = false;
  int? votePick;
  List<int> allVotes = [];
  Map<int, int> playerVotes = {}; // voterIndex -> targetIndex
  Map<int, int> voteCounts = {};
  bool fraudCaughtByMajority = false;
  Set<int> caughtFrauds = {};
  int guessingFraudIndex = 0;
  List<String> guessOptions = [];
  int? guessPick;
  Timer? timer;
  int secondsLeft = 0;

  // Points awarded this round (Barra El Salfa rule tracking)
  Map<int, int> pointsEarnedThisRound = {};

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void go(Screen s) => setState(() => screen = s);

  void setPlayerCount(int n) {
    setState(() {
      playerCount = n.clamp(selectedMode.minPlayers, selectedMode.maxPlayers);
      while (players.length < playerCount) {
        players.add('Player ${players.length + 1}');
      }
      players = players.sublist(0, playerCount);
    });
  }

  void addPlayerAfter(int index) {
    if (players.length >= selectedMode.maxPlayers) return;
    Sound.tap();
    setState(() {
      int n = players.length + 1;
      while (players.contains('Player $n')) {
        n++;
      }
      players.insert(index + 1, 'Player $n');
      playerCount = players.length;
    });
  }

  void removePlayerAt(int index) {
    if (players.length <= selectedMode.minPlayers) return;
    Sound.tap();
    setState(() {
      players.removeAt(index);
      playerCount = players.length;
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

    // Pick undercover decoy word if mode has undercover
    String undercoverWord = '';
    if (selectedMode.hasUndercover) {
      final otherWords = categories[cat]!.where((w) => w != word).toList()..shuffle(rng);
      undercoverWord = otherWords.isNotEmpty ? otherWords.first : 'Decoy';
    }

    // Assign roles randomly
    final indices = List.generate(players.length, (i) => i)..shuffle(rng);
    final frauds = indices.take(selectedMode.fraudCount).toSet();
    int? undercover;
    if (selectedMode.hasUndercover && indices.length > selectedMode.fraudCount) {
      undercover = indices[selectedMode.fraudCount];
    }

    setState(() {
      roundCat = cat;
      roundWord = word;
      roundUndercoverWord = undercoverWord;
      fraudIndices = frauds;
      undercoverIndex = undercover;
      passOrder = List.generate(players.length, (i) => i)..shuffle(rng);
      passIdx = 0;
      revealed = false;
      voteIdx = 0;
      voteRevealed = false;
      votePick = null;
      allVotes = [];
      playerVotes = {};
      voteCounts = {};
      fraudCaughtByMajority = false;
      caughtFrauds = {};
      guessingFraudIndex = frauds.first;
      guessOptions = [];
      guessPick = null;
      pointsEarnedThisRound = {};
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
      playerVotes = {};
      voteCounts = {};
      fraudCaughtByMajority = false;
      caughtFrauds = {};
      pointsEarnedThisRound = {};
      screen = Screen.vote;
    });
  }

  void confirmIndividualVote() {
    if (votePick == null) return;
    Sound.vote();
    setState(() {
      allVotes.add(votePick!);
      playerVotes[voteIdx] = votePick!;
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
    caughtFrauds.clear();
    pointsEarnedThisRound.clear();
    final majorityThreshold = players.length / 2;

    for (final f in fraudIndices) {
      if ((voteCounts[f] ?? 0) > majorityThreshold) {
        caughtFrauds.add(f);
      }
    }

    if (caughtFrauds.isNotEmpty) {
      fraudCaughtByMajority = true;
      // Caught fraud with highest votes guesses
      guessingFraudIndex = caughtFrauds.reduce(
          (a, b) => (voteCounts[a] ?? 0) >= (voteCounts[b] ?? 0) ? a : b);

      final decoys = categories[roundCat]!
          .where((w) => w != roundWord && w != roundUndercoverWord)
          .toList()
        ..shuffle();
      guessOptions = [roundWord, ...decoys.take(3)]..shuffle();
      guessPick = null;
      screen = Screen.guess;
    } else {
      fraudCaughtByMajority = false;
      // Frauds escape! Each fraud earns +100 points
      for (final f in fraudIndices) {
        scores[players[f]] = (scores[players[f]] ?? 0) + roundPoints;
        pointsEarnedThisRound[f] = roundPoints;
      }
      // If undercover survived without majority votes against them, undercover earns points
      if (undercoverIndex != null &&
          (voteCounts[undercoverIndex!] ?? 0) <= majorityThreshold) {
        scores[players[undercoverIndex!]] =
            (scores[players[undercoverIndex!]] ?? 0) + roundPoints;
        pointsEarnedThisRound[undercoverIndex!] = roundPoints;
      }
      screen = Screen.result;
      Sound.lose();
    }
  }

  void confirmGuess() {
    if (guessPick == null) return;
    Sound.guess();
    setState(() {
      pointsEarnedThisRound.clear();
      if (guessOptions[guessPick!] == roundWord) {
        // Fraud successfully guessed the secret word! Frauds steal the round.
        for (final f in fraudIndices) {
          scores[players[f]] = (scores[players[f]] ?? 0) + roundPoints;
          pointsEarnedThisRound[f] = roundPoints;
        }
        screen = Screen.result;
        Sound.lose();
      } else {
        // Fraud guessed wrong!
        // Authentic Barra El Salfa scoring:
        // Every player who voted for ANY caught fraud earns +100 party points!
        for (int voter = 0; voter < players.length; voter++) {
          if (!fraudIndices.contains(voter)) {
            final target = playerVotes[voter];
            if (target != null && caughtFrauds.contains(target)) {
              scores[players[voter]] =
                  (scores[players[voter]] ?? 0) + roundPoints;
              pointsEarnedThisRound[voter] = roundPoints;
            }
          }
        }
        screen = Screen.result;
        Sound.win();
      }
    });
  }

  bool get fraudGuessedCorrectly =>
      guessPick != null && guessOptions[guessPick!] == roundWord;

  String get resultTitle {
    if (!fraudCaughtByMajority) {
      return selectedMode.fraudCount > 1
          ? 'The frauds win!'
          : 'The fraud wins!';
    }
    if (fraudGuessedCorrectly) {
      return selectedMode.fraudCount > 1
          ? 'The frauds escape!'
          : 'The fraud escapes!';
    }
    return 'The players in the know win!';
  }

  String get resultLine {
    if (!fraudCaughtByMajority) {
      return 'No fraud received more than half of the votes, so the fraud takes the round.';
    }
    if (fraudGuessedCorrectly) {
      return '${players[guessingFraudIndex]} guessed the secret word ("$roundWord") and stole the round!';
    }
    return 'The fraud was caught by majority vote and failed to guess the secret word.';
  }

  // Passing phone dialog: strictly for round control, NO mode switching mid-round.
  Future<void> showPassOptions() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border, width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Options',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              _optionPill(
                icon: Icons.refresh_rounded,
                label: 'Restart round',
                onTap: () => Navigator.pop(context, 'restart'),
              ),
              const SizedBox(height: 10),
              _optionPill(
                icon: Icons.people_alt_rounded,
                label: 'Change players',
                onTap: () => Navigator.pop(context, 'players'),
              ),
              const SizedBox(height: 10),
              _optionPill(
                icon: Icons.home_rounded,
                label: 'Back to main menu',
                onTap: () => Navigator.pop(context, 'home'),
              ),
              const SizedBox(height: 10),
              _optionPill(
                icon: Icons.close_rounded,
                label: 'Cancel',
                isCancel: true,
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restart':
        Sound.start();
        startRound();
      case 'players':
        go(Screen.players);
      case 'home':
        timer?.cancel();
        go(Screen.home);
      default:
        break;
    }
  }

  Widget _optionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isCancel = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isCancel ? Colors.transparent : card2,
        shape: StadiumBorder(
          side: BorderSide(
            color: isCancel ? border.withValues(alpha: 0.6) : border,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isCancel ? muted : yellow,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isCancel ? muted : ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: switch (screen) {
                    Screen.home => _home(),
                    Screen.mode => _mode(),
                    Screen.category => _category(),
                    Screen.players => _players(),
                    Screen.settings => _settings(),
                    Screen.rules => _rules(),
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

  Widget _logo({double size = 150}) => Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.95,
              height: size * 0.95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: yellow.withValues(alpha: 0.28),
                    blurRadius: 40,
                    spreadRadius: 6,
                  ),
                  BoxShadow(
                    color: blue.withValues(alpha: 0.22),
                    blurRadius: 55,
                    spreadRadius: 14,
                  ),
                ],
              ),
            ),
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const RadialGradient(
                  center: Alignment.center,
                  radius: 0.65,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.72, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/logo.png',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
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

  Widget _categoryLabel(String cat, {double size = 16}) => Text(
        cat,
        textAlign: TextAlign.center,
        style: TextStyle(color: yellow, fontSize: size, fontWeight: FontWeight.w800),
      );

  Widget _passProgress() => Text(
        '${passIdx + 1} of ${players.length}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w700),
      );

  // ---------- Screens ----------

  // Main menu: text buttons only.
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
          const SizedBox(height: 6),
          const Text(
            'The English Barra El Salfa',
            textAlign: TextAlign.center,
            style: TextStyle(color: yellow, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          _primary('Play', () {
            Sound.tap();
            go(Screen.mode);
          }),
          const SizedBox(height: 8),
          _secondary('Settings', () {
            Sound.tap();
            go(Screen.settings);
          }),
          const SizedBox(height: 8),
          _secondary('Rules', () {
            Sound.tap();
            go(Screen.rules);
          }),
        ],
      );

  // Mode Selection Screen (Accessible from Main Menu setup flow)
  Widget _mode() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Select Game Mode'),
          _mutedText('Pick the game mode for your round. Add or adjust modes directly in code:'),
          const SizedBox(height: 16),
          ...availableGameModes.map((m) {
            final isSelected = selectedMode.id == m.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Sound.tap();
                  setState(() {
                    selectedMode = m;
                    if (playerCount < m.minPlayers) {
                      setPlayerCount(m.minPlayers);
                    }
                  });
                  go(Screen.category);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E2856) : card,
                    border: Border.all(
                        color: isSelected ? yellow : border,
                        width: isSelected ? 2 : 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(m.title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              m.fraudCount > 1
                                  ? '2 Frauds'
                                  : m.hasUndercover
                                      ? '1 Fraud + 1 Undercover'
                                      : '1 Fraud',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: yellow),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(m.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${m.minPlayers} to ${m.maxPlayers} players',
                        style: const TextStyle(
                            color: blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  // Category Selection
  Widget _category() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Text('Mode: ${selectedMode.title}',
                style: const TextStyle(
                    color: yellow, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
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
          _secondary('Change mode', () => go(Screen.mode)),
          const SizedBox(height: 8),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  // Players setup screen
  Widget _players() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Players'),
          if (chosenCat != null) ...[
            _categoryLabel(chosenCat!),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Text('Mode: ${selectedMode.title}',
                style: const TextStyle(
                    color: yellow, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedMode.minPlayers} to ${selectedMode.maxPlayers} players. Names are optional.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...List.generate(playerCount, (i) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: card2,
                          shape: BoxShape.circle,
                          border: Border.all(color: border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: yellow, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: ValueKey('player-$i-$playerCount'),
                          controller: TextEditingController(text: players[i])
                            ..selection = TextSelection.collapsed(offset: players[i].length),
                          onChanged: (v) {
                            players[i] = v.trim().isEmpty ? 'Player ${i + 1}' : v.trim();
                          },
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'Player ${i + 1}',
                            hintStyle: const TextStyle(color: muted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          color: playerCount > selectedMode.minPlayers
                              ? red
                              : muted.withValues(alpha: 0.3),
                        ),
                        tooltip: 'Remove player',
                        onPressed: playerCount > selectedMode.minPlayers
                            ? () => removePlayerAt(i)
                            : null,
                      ),
                    ],
                  ),
                ),
                if (playerCount < selectedMode.maxPlayers)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: Center(
                      child: InkWell(
                        onTap: () => addPlayerAfter(i),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: card2,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 18, color: yellow),
                              SizedBox(width: 6),
                              Text(
                                'Add player',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            );
          }),
          const SizedBox(height: 12),
          _primary('Start round', chosenCat == null
              ? null
              : () {
                  Sound.start();
                  startRound();
                }),
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
            activeThumbColor: yellow,
          ),
          const SizedBox(height: 10),
          const Text('Discussion timer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          RadioGroup<int>(
            groupValue: timerMinutes,
            onChanged: (v) => setState(() => timerMinutes = v ?? 0),
            child: Column(
              children: [0, 2, 3, 5]
                  .map((m) => RadioListTile<int>(
                        value: m,
                        title: Text(m == 0 ? 'No timer' : '$m minutes',
                            textAlign: TextAlign.center),
                        activeColor: yellow,
                      ))
                  .toList(),
            ),
          ),
          _mutedText('The timer is only a guide. You can vote early at any time.'),
          const SizedBox(height: 14),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _mutedText('Scores are tracked across rounds using Barra El Salfa rules (100 party points per correct vote / round). Words do not repeat until a category runs out.'),
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

  Widget _rules() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Rules'),
          _mutedText('Fraud Check — The English Barra El Salfa party game.\n3–10 players and one phone.'),
          const SizedBox(height: 10),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🎮 Game Modes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              const SizedBox(height: 6),
              const Text(
                '• Classic (1 Fraud): Exactly one player is the fraud and only knows the category. Everyone else sees the secret word.\n\n'
                '• Two Frauds: Two players are chosen as frauds! Neither of them knows the secret word. Double the suspicion!\n\n'
                '• Undercover: One fraud + one undercover agent. The undercover receives a different decoy word from the same category. Both try to blend in!',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text('📱 How the Round Works',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              const SizedBox(height: 6),
              const Text(
                '1. Pass the phone: Each player secretly reveals their card in private.\n\n'
                '2. Discuss: Take turns asking smart questions and giving vague clues. Never say your secret word!\n\n'
                '3. Vote: Every player votes privately for who they suspect is the fraud.\n\n'
                '4. Last chance: If a fraud is caught by majority vote (> 50%), they get 4 word options. If they guess the secret word, they steal the round!',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text('🏆 Barra El Salfa Scoring (+100 Party Points)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              const SizedBox(height: 6),
              const Text(
                '• Caught Fraud misses guess: Every player who personally voted for the caught fraud earns +100 points! (Players who voted for an innocent player get 0 points).\n\n'
                '• Fraud Escapes or Guesses Right: The fraud earns +100 points! Safe players get 0 points.\n\n'
                '• Undercover Agent: Earns +100 points if they vote for the fraud or survive unexposed.',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          )),
          const SizedBox(height: 8),
          _primary('Play now', () => go(Screen.mode)),
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
    final isFraud = fraudIndices.contains(idx);
    final isUndercover = idx == undercoverIndex;
    final last = passIdx == passOrder.length - 1;

    final themeColor = isFraud
        ? red
        : isUndercover
            ? purple
            : green;

    final bgGradient = isFraud
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A1020), Color(0xFF220810)],
          )
        : isUndercover
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF35175C), Color(0xFF190B2E)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF103D28), Color(0xFF081F14)],
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          tween: Tween<double>(begin: 0.88, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
            decoration: BoxDecoration(
              gradient: bgGradient,
              border: Border.all(color: themeColor, width: 2.5),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.42),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFraud
                        ? const Color(0xFF63152A)
                        : isUndercover
                            ? const Color(0xFF471F7A)
                            : const Color(0xFF165236),
                    border: Border.all(color: themeColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.5),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isFraud
                        ? Icons.theater_comedy_rounded
                        : isUndercover
                            ? Icons.visibility_off_rounded
                            : Icons.shield_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor),
                  ),
                  child: Text(
                    isFraud
                        ? '🎭 IMPOSTER'
                        : isUndercover
                            ? '🕵️ UNDERCOVER AGENT'
                            : '🛡️ INNOCENT / SAFE',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isFraud
                      ? 'YOU ARE THE FRAUD!'
                      : isUndercover
                          ? 'YOU ARE UNDERCOVER!'
                          : 'YOU ARE SAFE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isFraud ? Colors.white : themeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: card2.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        categoryIcons[roundCat] ?? '📁',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Category: $roundCat',
                        style: const TextStyle(
                          color: yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isFraud) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF280B14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: red.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          '? ? ?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: red,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'SECRET WORD UNKNOWN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    selectedMode.fraudCount > 1
                        ? 'There are 2 frauds this round! Listen closely, blend in, and try to deduce the secret word.'
                        : 'Blend in! Listen to the clues, pretend you know the word, and deduce it before voting.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, fontSize: 13, height: 1.4),
                  ),
                ] else if (isUndercover) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF210E3A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: purple.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR DECOY WORD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          roundUndercoverWord,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your word is slightly different from the safe players. Blend in and help expose the fraud!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C2B1C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: green.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR SECRET WORD',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          roundWord,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Give subtle clues to prove you know the word without giving it away to the fraud!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _primary(last ? 'Hide and start discussion' : 'Hide and pass on', hideAndPass),
      ],
    );
  }

  Widget _discuss() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Discuss!'),
          _categoryLabel(roundCat, size: 20),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Text('Mode: ${selectedMode.title}',
                style: const TextStyle(
                    color: yellow, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          _mutedText('Give clues and ask each other questions. Do not say your secret word!'),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: card2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: yellow.withValues(alpha: 0.5)),
          ),
          child: Text(
            '🗳️ Voter: $voter',
            style: const TextStyle(
              color: yellow,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vote ${voteIdx + 1} of ${players.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...others.map((i) {
          final selected = votePick == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Sound.tap();
                  setState(() => votePick = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF1B2F5C) : card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? blue : border,
                      width: selected ? 2.2 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: blue.withValues(alpha: 0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? blue : card2,
                          border: Border.all(
                            color: selected ? Colors.white : border,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.white : yellow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              players[i],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Suspect #${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? const Color(0xFF8DC0FF) : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? blue : border,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        _primary(
          votePick == null
              ? 'Select a suspect'
              : 'Confirm vote for ${players[votePick!]}',
          votePick == null ? null : confirmIndividualVote,
        ),
      ],
    );
  }

  Widget _guess() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Last chance!'),
          _mutedText(
              'A fraud was caught by majority vote, but they get one final guess. ${players[guessingFraudIndex]}, pick the word you think was the secret word. Guess right to steal the round!'),
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
        const SizedBox(height: 12),
        _card(Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: Text('Mode: ${selectedMode.title}',
                  style: const TextStyle(
                      color: yellow, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            Text('Secret Word: $roundWord',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            _categoryLabel(roundCat),
            const SizedBox(height: 10),
            Text(
              selectedMode.fraudCount > 1
                  ? 'Frauds: ${fraudIndices.map((i) => players[i]).join(', ')}'
                  : 'Fraud: ${fraudIndices.map((i) => players[i]).join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, color: red),
            ),
            if (undercoverIndex != null) ...[
              const SizedBox(height: 6),
              Text(
                'Undercover: ${players[undercoverIndex!]} (Word: "$roundUndercoverWord")',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: purple),
              ),
            ],
            if (allVotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: border),
              const SizedBox(height: 8),
              const Text('Vote Summary',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              ...players.map((name) {
                final idx = players.indexOf(name);
                final count = voteCounts[idx] ?? 0;
                final isFraud = fraudIndices.contains(idx);
                final isUnder = idx == undercoverIndex;
                final badge = isFraud
                    ? ' [Fraud]'
                    : isUnder
                        ? ' [Undercover]'
                        : '';
                return Text('$name$badge: $count vote${count == 1 ? '' : 's'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: count > (players.length / 2) ? red : muted,
                        fontWeight: count > (players.length / 2)
                            ? FontWeight.w700
                            : FontWeight.normal));
              }),
              const SizedBox(height: 12),
              const Divider(color: border),
              const SizedBox(height: 8),
              const Text('Barra El Salfa Points This Round',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              ...List.generate(players.length, (i) {
                final pts = pointsEarnedThisRound[i] ?? 0;
                final voterTarget = playerVotes[i];
                String reason = '';
                if (pts > 0) {
                  if (fraudIndices.contains(i)) {
                    reason = fraudGuessedCorrectly ? 'Guessed the word!' : 'Escaped undetected!';
                  } else if (i == undercoverIndex) {
                    reason = 'Survived undercover!';
                  } else if (voterTarget != null && caughtFrauds.contains(voterTarget)) {
                    reason = 'Correctly voted for ${players[voterTarget]}';
                  } else {
                    reason = 'Round bonus';
                  }
                } else {
                  if (fraudIndices.contains(i)) {
                    reason = 'Caught & missed guess';
                  } else if (voterTarget != null) {
                    reason = 'Voted for ${players[voterTarget]}';
                  } else {
                    reason = 'No points';
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${players[i]} ($reason)',
                          style: TextStyle(
                              color: pts > 0 ? ink : muted,
                              fontSize: 13,
                              fontWeight: pts > 0 ? FontWeight.w700 : FontWeight.normal),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        pts > 0 ? '+$pts pts' : '0 pts',
                        style: TextStyle(
                            color: pts > 0 ? green : muted,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        )),
        const SizedBox(height: 12),
        const Text('Total Leaderboard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...sorted.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('${e.value} pts',
                      style: const TextStyle(
                          color: yellow, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            )),
        const SizedBox(height: 16),
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
