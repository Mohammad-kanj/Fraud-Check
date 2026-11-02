import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'categories.dart';

// Fraud Check — pass-and-play party game, one phone, 3–10 players.
// Pass-and-play party game — the English mobile edition.
// Modes: Classic (1 Fraud), Two Frauds (2 Frauds), Undercover (1 Fraud + 1 Undercover).
// Scoring rules: 100 party points awarded to players who correctly vote for caught frauds.
// No login, no internet, no storage: scores and used words live only for this session.

// ---------- Colours ----------
const bg = Color(0xFF0A0D1B);
const card = Color(0xFF151932);
const card2 = Color(0xFF1E2448);
const cardHi = card2;
const border = Color(0xFF2C3466);
const yellow = Color(0xFFFFC837);
const red = Color(0xFFFF3B5C);
const green = Color(0xFF00E5A3);
const blue = Color(0xFF3A86FF);
const ink = Color(0xFFF8FAFC);
const muted = Color(0xFF94A3B8);
const purple = Color(0xFF8B5CF6);

// Fraud Check party points
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
  static double volume = 0.8;
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> setVolume(double val) async {
    volume = val.clamp(0.0, 1.0);
    try {
      await _player.setVolume(volume);
    } catch (_) {}
  }

  static Future<void> play(String name) async {
    if (!enabled || volume <= 0.0) return;
    try {
      await _player.stop();
      await _player.setVolume(volume);
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: yellow, surface: card),
        fontFamily: GoogleFonts.archivo().fontFamily,
        textTheme: GoogleFonts.archivoTextTheme(
          ThemeData.dark().textTheme.apply(bodyColor: ink, displayColor: ink),
        ),
      ),
      home: const GamePage(),
    );
  }
}

// ---------- Film Strip Background ----------
class FilmStripBackground extends StatefulWidget {
  const FilmStripBackground({super.key});

  @override
  State<FilmStripBackground> createState() => _FilmStripBackgroundState();
}

class _FilmStripBackgroundState extends State<FilmStripBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
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
        painter: FilmStripPainter(progress: _ctrl.value),
      ),
    );
  }
}

class FilmStripPainter extends CustomPainter {
  final double progress;
  FilmStripPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep midnight navy base fill
    final basePaint = Paint()..color = const Color(0xFF090B16);
    canvas.drawRect(Offset.zero & size, basePaint);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final diagonal = sqrt(size.width * size.width + size.height * size.height);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-pi / 4); // 45-degree angle tilt

    const double stripHeight = 62.0;
    const double stripGap = 42.0;
    const double pitch = stripHeight + stripGap;
    const double frameWidth = 58.0;
    const double sprocketSpacing = 14.0;
    const double sprocketW = 5.0;
    const double sprocketH = 7.0;

    final stripPaint = Paint()..color = const Color(0xFF13172E);
    final borderPaint = Paint()
      ..color = const Color(0xFF232A52).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final frameLinePaint = Paint()
      ..color = const Color(0xFF1D2344)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final sprocketPaint = Paint()..color = const Color(0xFF090B16);

    final textStyle = TextStyle(
      color: const Color(0xFFFFD15C).withValues(alpha: 0.45),
      fontSize: 26,
      fontWeight: FontWeight.w900,
      fontFamily: GoogleFonts.archivo().fontFamily,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: '?', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final int numStrips = (diagonal / pitch).ceil() + 2;

    for (int s = -numStrips; s <= numStrips; s++) {
      final double top = s * pitch;
      final double bottom = top + stripHeight;
      final stripRect = Rect.fromLTRB(-diagonal, top, diagonal, bottom);

      // Alternating strip scroll direction:
      // Even strips move forward, odd strips move in the opposite direction.
      final double stripProgress = s.isEven ? progress : (1.0 - progress);
      final double stripOffset = stripProgress * frameWidth;
      final double sprocketOffset = stripProgress * frameWidth;

      // 1. Film strip dark ribbon
      canvas.drawRRect(
        RRect.fromRectAndRadius(stripRect, const Radius.circular(2)),
        stripPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(stripRect, const Radius.circular(2)),
        borderPaint,
      );

      // Top and bottom rail divider lines
      final railLinePaint = Paint()
        ..color = const Color(0xFF222950).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawLine(
        Offset(-diagonal, top + 11),
        Offset(diagonal, top + 11),
        railLinePaint,
      );
      canvas.drawLine(
        Offset(-diagonal, bottom - 11),
        Offset(diagonal, bottom - 11),
        railLinePaint,
      );

      // 2. Sprocket perforations on top and bottom rails
      final double sprocketStart = -diagonal - (sprocketOffset % sprocketSpacing);
      for (double x = sprocketStart; x <= diagonal; x += sprocketSpacing) {
        // Top sprocket
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top + 2.5, sprocketW, sprocketH),
            const Radius.circular(1.5),
          ),
          sprocketPaint,
        );
        // Bottom sprocket
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, bottom - 9.5, sprocketW, sprocketH),
            const Radius.circular(1.5),
          ),
          sprocketPaint,
        );
      }

      // 3. Frames and Question Marks
      final double frameStart = -diagonal - (stripOffset % frameWidth);
      for (double x = frameStart; x <= diagonal; x += frameWidth) {
        // Frame divider
        canvas.drawLine(
          Offset(x, top + 11),
          Offset(x, bottom - 11),
          frameLinePaint,
        );

        // Center question mark in frame
        final qx = x + (frameWidth - textPainter.width) / 2;
        final qy = top + 12 + ((stripHeight - 24) - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(qx, qy));
      }
    }

    canvas.restore();

    // Subtle edge vignette overlay
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.1,
        colors: [
          Colors.transparent,
          const Color(0xFF070913).withValues(alpha: 0.75),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(FilmStripPainter oldDelegate) =>
      oldDelegate.progress != progress;
}


// ---------- Questioning Derangement Generator ----------
class QuestionPairing {
  final List<int> askers;
  final List<int> targets;
  const QuestionPairing({required this.askers, required this.targets});
}

QuestionPairing generateRandomQuestioningRound(int n, [Random? rng]) {
  final rand = rng ?? Random();
  if (n <= 1) {
    return const QuestionPairing(askers: [], targets: []);
  }
  if (n == 2) {
    final a = rand.nextBool() ? [0, 1] : [1, 0];
    return QuestionPairing(askers: a, targets: [a[1], a[0]]);
  }

  // Generate derangement of targets for [0..n-1]
  final targetsMap = List.generate(n, (i) => i);
  while (true) {
    targetsMap.shuffle(rand);
    bool isDerangement = true;
    for (int i = 0; i < n; i++) {
      if (targetsMap[i] == i) {
        isDerangement = false;
        break;
      }
    }
    if (isDerangement) break;
  }

  // Randomize the order of askers
  final askers = List.generate(n, (i) => i)..shuffle(rand);
  final targets = askers.map((a) => targetsMap[a]).toList();

  return QuestionPairing(askers: askers, targets: targets);
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
  double brightness = 1.0; // In-app visual overlay brightness (0.2 to 1.0)
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

  // Questioning rounds
  int questionTurnIdx = 0;
  List<int> questionAskers = [];
  List<int> questionTargets = [];

  // Points awarded this round
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
      questionTurnIdx = 0;
      questionAskers = [];
      questionTargets = [];
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
    final pairing = generateRandomQuestioningRound(players.length);
    setState(() {
      questionTurnIdx = 0;
      questionAskers = List<int>.from(pairing.askers);
      questionTargets = List<int>.from(pairing.targets);
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

  void advanceQuestionTurn() {
    Sound.tap();
    setState(() {
      questionTurnIdx++;
      if (questionAskers.isNotEmpty && questionTargets.isNotEmpty) {
        while (questionAskers.length <= questionTurnIdx) {
          final nextPairing = generateRandomQuestioningRound(players.length);
          questionAskers.addAll(nextPairing.askers);
          questionTargets.addAll(nextPairing.targets);
        }
      }
    });
  }

  void startVoting() {
    timer?.cancel();
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
      final isCorrect = guessOptions[guessPick!] == roundWord;
      if (isCorrect) {
        // Caught fraud guessed correctly: fraud receives 50 points, but loses the round.
        scores[players[guessingFraudIndex]] =
            (scores[players[guessingFraudIndex]] ?? 0) + 50;
        pointsEarnedThisRound[guessingFraudIndex] = 50;
      } else {
        // Caught fraud guessed incorrectly: fraud receives 0 points.
        pointsEarnedThisRound[guessingFraudIndex] = 0;
      }

      // All players who voted for that caught fraud receive 100 points
      for (int voter = 0; voter < players.length; voter++) {
        if (!fraudIndices.contains(voter)) {
          final target = playerVotes[voter];
          if (target != null &&
              (target == guessingFraudIndex || caughtFrauds.contains(target))) {
            scores[players[voter]] =
                (scores[players[voter]] ?? 0) + roundPoints;
            pointsEarnedThisRound[voter] = roundPoints;
          }
        }
      }
      screen = Screen.result;
      Sound.win();
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
    return 'The players in the know win!';
  }

  String get resultLine {
    if (!fraudCaughtByMajority) {
      return 'No fraud received more than half of the votes, so the fraud takes the round.';
    }
    if (fraudGuessedCorrectly) {
      return '${players[guessingFraudIndex]} guessed the secret word ("$roundWord") for 50 bonus pts, but was caught and lost the round!';
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
        const Positioned.fill(child: FilmStripBackground()),
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
        // In-app visual overlay brightness control (dimming/brightening cleanly without device permissions)
        if (brightness < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: (1.0 - brightness) * 0.75),
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
            // High-contrast circular backing disc with layered glow so cutout pops against film strips
            Container(
              width: size * 0.90,
              height: size * 0.90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E1226).withValues(alpha: 0.88),
                border: Border.all(
                  color: yellow.withValues(alpha: 0.28),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: yellow.withValues(alpha: 0.30),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                  BoxShadow(
                    color: blue.withValues(alpha: 0.20),
                    blurRadius: 55,
                    spreadRadius: 14,
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
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

  Widget _primaryWithIcon(String label, IconData icon, VoidCallback? onPressed) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: yellow,
            foregroundColor: const Color(0xFF1A1400),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 8),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Widget _actionCardButton(String label, VoidCallback onPressed) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.5),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
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

  // ---------- Screens ----------

  // Main menu: party hero branding
  Widget _home() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _logo(),
          const SizedBox(height: 12),
          Text(
            'FRAUD CHECK',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: GoogleFonts.archivo().fontFamily,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              height: 1.05,
              color: ink,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.95),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
                Shadow(
                  color: yellow.withValues(alpha: 0.40),
                  offset: Offset.zero,
                  blurRadius: 30,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: yellow.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: yellow.withValues(alpha: 0.5)),
            ),
            child: const Text(
              'WHO IS THE FRAUD?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: yellow,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _primaryWithIcon('Play', Icons.play_arrow_rounded, () {
            Sound.tap();
            go(Screen.mode);
          }),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionCardButton('Settings', () {
                  Sound.tap();
                  go(Screen.settings);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionCardButton('Rules', () {
                  Sound.tap();
                  go(Screen.rules);
                }),
              ),
            ],
          ),
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
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(m.title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
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
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Text('Mode: ${selectedMode.title}',
                    style: const TextStyle(
                        color: yellow, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Text(
                  '${categories.length} Categories',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _title('Pick a category'),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: categories.keys.map((cat) {
              final selected = chosenCat == cat;
              return InkWell(
                onTap: () {
                  Sound.tap();
                  setState(() => chosenCat = cat);
                  go(Screen.players);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [const Color(0xFF233554), const Color(0xFF1B2844)]
                          : [const Color(0xFF1E244E), const Color(0xFF151838)],
                    ),
                    border: Border.all(
                      color: selected ? yellow : border,
                      width: selected ? 2.2 : 1.2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: yellow.withValues(alpha: 0.25),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (selected)
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: yellow,
                            size: 20,
                          ),
                        ),
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252D60),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  categoryIcons[cat] ?? '🎭',
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _categoryLabel(cat, size: 15),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: card2.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🏷️ ${categories[cat]!.length} words',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
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
          // Player rows
          ...List.generate(playerCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Row(
                  children: [
                    // Number Badge
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
                          fontWeight: FontWeight.w800,
                          color: yellow,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Player Name Input Field
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
                    // Distinct visual and touch gap: 16px gap + 1.5px divider + 12px gap
                    const SizedBox(width: 16),
                    Container(
                      width: 1.5,
                      height: 26,
                      color: border.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    // Standalone 38px circular container for delete button
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: playerCount > selectedMode.minPlayers
                            ? red.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: playerCount > selectedMode.minPlayers
                              ? red.withValues(alpha: 0.3)
                              : border.withValues(alpha: 0.3),
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 20,
                          color: playerCount > selectedMode.minPlayers
                              ? red
                              : muted.withValues(alpha: 0.3),
                        ),
                        tooltip: 'Remove player',
                        onPressed: playerCount > selectedMode.minPlayers
                            ? () => removePlayerAt(i)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Single "Add player" button strictly once below the final player
          if (playerCount < selectedMode.maxPlayers)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: InkWell(
                onTap: () => addPlayerAfter(playerCount - 1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: card2.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 20, color: yellow),
                      SizedBox(width: 8),
                      Text(
                        'Add player',
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          const SizedBox(height: 8),

          // Card 1: Sound effects and master audio volume
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: yellow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Playful arcade sound effects and master volume',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: Sound.enabled,
                    onChanged: (v) {
                      setState(() => Sound.enabled = v);
                      if (v) Sound.tap();
                    },
                    title: const Text(
                      'Sound effects',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    activeThumbColor: yellow,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      !Sound.enabled || Sound.volume == 0
                          ? Icons.volume_off_rounded
                          : (Sound.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      color: Sound.enabled ? yellow : muted,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: yellow,
                          inactiveTrackColor: card2,
                          thumbColor: yellow,
                          overlayColor: yellow.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: Sound.volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: Sound.enabled
                              ? (v) {
                                  setState(() => Sound.setVolume(v));
                                }
                              : null,
                          onChangeEnd: (v) {
                            if (Sound.enabled) Sound.tap();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(Sound.volume * 100).round()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Sound.enabled ? ink : muted,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card 2: Screen Brightness
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.brightness_6_rounded, color: yellow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Screen Brightness',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                          Text(
                            'Adjust in-app visual overlay brightness',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.brightness_low_rounded, color: muted, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: yellow,
                          inactiveTrackColor: card2,
                          thumbColor: yellow,
                          overlayColor: yellow.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: brightness,
                          min: 0.2,
                          max: 1.0,
                          onChanged: (v) {
                            setState(() => brightness = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.brightness_high_rounded, color: yellow, size: 20),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(brightness * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ink),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _secondary('Back to main menu', () => go(Screen.home)),
        ],
      );

  Widget _rules() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _title('Rules'),
          _mutedText('Pass-and-play party game of deception and deduction.\n3–10 players on one device.'),
          const SizedBox(height: 10),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              SizedBox(height: 6),
              Text(
                '• One or more players are secret frauds who only know the category.\n\n'
                '• Everyone else receives the secret word and must deduce who is bluffing.\n\n'
                '• The fraud\'s objective is to blend in, avoid detection, and guess the secret word.',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          )),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Roles & Objectives',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              SizedBox(height: 6),
              Text(
                '• Classic (1 Fraud): Exactly one player is the fraud and only knows the category. Everyone else sees the secret word.\n\n'
                '• Two Frauds: Two players are chosen as frauds! Neither knows the secret word. Double the suspicion!\n\n'
                '• Undercover: One fraud + one undercover player. The undercover receives a related decoy word. Both try to blend in!',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          )),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Questioning Phase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              SizedBox(height: 6),
              Text(
                '1. Pass the phone: Each player secretly reveals their role in private.\n\n'
                '2. Discuss: Take turns asking smart questions and giving vague clues. Never say your secret word!\n\n'
                '3. Infinite rounds: Questioning continues until players are ready to vote.',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          )),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Voting & Scoring',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: yellow)),
              SizedBox(height: 6),
              Text(
                '• Secret Vote: Every player votes privately for who they suspect is the fraud.\n\n'
                '• Last chance: If a fraud is caught by majority vote (> 50%), they get 4 word options to guess the secret word.\n\n'
                '• Caught Fraud guesses correctly: The fraud earns 50 points, but loses the round! All players who voted for that fraud earn +100 points.\n\n'
                '• Caught Fraud misses guess: The fraud earns 0 points. All players who voted for that fraud earn +100 points!\n\n'
                '• Fraud Escapes: If no fraud receives majority votes, frauds win the round and earn +100 points each.\n\n'
                '• Undercover: Earns +100 points if they vote for the fraud or survive unexposed.',
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
        const SizedBox(height: 10),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mystery badge
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: card2,
                  shape: BoxShape.circle,
                  border: Border.all(color: yellow.withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: yellow.withValues(alpha: 0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: yellow,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pass the phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              _mutedText('No peeking! Only the person holding the phone should look.'),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: yellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Player ${passIdx + 1} of ${players.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: yellow,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryWithIcon('Tap to reveal', Icons.visibility_rounded, showReveal),
      ],
    );
  }

  Widget _reveal() {
    final idx = passOrder[passIdx];
    final isFraud = fraudIndices.contains(idx);
    final isUndercover = idx == undercoverIndex;
    final last = passIdx == passOrder.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        const SizedBox(height: 6),
        // Category Indicator at the top OUTSIDE the content box
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Text(
              'Category: $roundCat',
              style: const TextStyle(color: yellow, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _revealCard(
          playerIdx: idx,
          isFraud: isFraud,
          isUndercover: isUndercover,
        ),
        const SizedBox(height: 16),
        _primary(last ? 'Hide and start discussion' : 'Hide and pass on', hideAndPass),
      ],
    );
  }

  Widget _revealCard({
    required int playerIdx,
    required bool isFraud,
    required bool isUndercover,
  }) {
    final frontCard = _revealCardFront(
      playerIdx: playerIdx,
      isFraud: isFraud,
      isUndercover: isUndercover,
    );
    final backCard = _revealCardBack(playerIdx);

    return TweenAnimationBuilder<double>(
      key: ValueKey('reveal_flip_$passIdx'),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, _) {
        final isFront = value >= 0.5;
        final angle = isFront ? (value - 1.0) * pi : value * pi;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: isFront ? 1.0 : 0.0,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((value - 1.0) * pi),
                child: frontCard,
              ),
            ),
            if (!isFront)
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: backCard,
              ),
          ],
        );
      },
    );
  }

  Widget _revealCardBack(int playerIdx) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 380),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2448), Color(0xFF0F1326)],
        ),
        border: Border.all(color: yellow.withValues(alpha: 0.7), width: 2.5),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: yellow.withValues(alpha: 0.3),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: card2,
              border: Border.all(color: yellow.withValues(alpha: 0.8), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: yellow.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.help_outline_rounded,
              color: yellow,
              size: 42,
            ),
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: yellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: yellow.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'TOP SECRET • سري للغاية',
                style: TextStyle(
                  color: yellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              players[playerIdx],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: ink,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'REVEALING ROLE...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revealCardFront({
    required int playerIdx,
    required bool isFraud,
    required bool isUndercover,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E2448), Color(0xFF0F1326)],
        ),
        border: Border.all(color: yellow.withValues(alpha: 0.6), width: 2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: yellow.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isFraud) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: yellow.withValues(alpha: 0.5)),
              ),
              child: const Text(
                '👁️ FRAUD',
                style: TextStyle(
                  color: yellow,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isUndercover) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: yellow.withValues(alpha: 0.5)),
              ),
              child: const Text(
                '👁️ UNDERCOVER',
                style: TextStyle(
                  color: yellow,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isFraud
                  ? 'YOU ARE THE FRAUD'
                  : (isUndercover ? 'YOU ARE UNDERCOVER' : 'YOU ARE NOT THE FRAUD'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: ink,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isFraud) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Text(
                selectedMode.fraudCount > 1
                    ? 'There are 2 frauds this round! Listen closely, blend in, and try to deduce the secret word.'
                    : 'Try to blend in! Listen to clues, pretend you know the word, and deduce it before voting.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ] else if (isUndercover) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
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
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your word is slightly different from other players. Blend in and help expose the fraud!',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13, height: 1.4),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
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
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: ink,
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
    );
  }

  Widget _discuss() {
    final totalQuestions = players.isNotEmpty ? players.length : 1;
    final bool validLists = questionAskers.isNotEmpty &&
        questionTargets.isNotEmpty &&
        questionAskers.length == questionTargets.length;
    final List<int> askers = validLists
        ? questionAskers
        : List.generate(totalQuestions, (i) => i);
    final List<int> targets = validLists
        ? questionTargets
        : List.generate(totalQuestions, (i) => (i + 1) % totalQuestions);

    final safeTurn = questionTurnIdx < 0 ? 0 : questionTurnIdx;
    final currentIdx = safeTurn < askers.length ? safeTurn : (safeTurn % askers.length);
    final askerName = players[askers[currentIdx] % players.length];
    final responderName = players[targets[currentIdx] % players.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        passTopBar(),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: card2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: const Text(
            'Discuss!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Light box background behind instruction text to prevent background blending
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: card2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: const Text(
            'Give clues and ask each other questions. Do not say your secret word!',
            textAlign: TextAlign.center,
            style: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
        if (timerMinutes > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (secondsLeft <= 10 && secondsLeft > 0) ? red : border,
                width: 1.5,
              ),
            ),
            child: Text(
              '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                color: (secondsLeft <= 10 && secondsLeft > 0) ? red : ink,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Simplified Questioning Display: vertical prompt with asker and responder in separate boxes
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: yellow.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Text(
                  askerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'asks',
                  style: TextStyle(
                    color: muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Text(
                  responderName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Navigation Control: Next question only (Previous question removed per R4.3)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: advanceQuestionTurn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: const Color(0xFF1A1400),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Next question', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Action button labeled 'Vote'
        _primary('Vote', startVoting),
      ],
    );
  }

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
            'Voter: $voter',
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
          'Vote',
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
    final isPlayersWin = fraudCaughtByMajority;
    final heroBannerText = isPlayersWin
        ? 'PLAYERS IN THE KNOW WIN!'
        : 'THE FRAUD ESCAPED!';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // a. Victory/Defeat Hero Banner (No emojis)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: card2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPlayersWin ? const Color(0xFF10B981) : const Color(0xFFFF3B5C),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                heroBannerText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPlayersWin ? const Color(0xFF10B981) : const Color(0xFFFF3B5C),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resultTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 4),
              _mutedText(resultLine),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // b. Polished Summary Section with Visual Depth & Dimensional Card Styling
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF202652), Color(0xFF121630)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: yellow.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: yellow.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Category & Mode Pills
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(categoryIcons[roundCat] ?? '📁', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            roundCat,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: yellow, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      'Mode: ${selectedMode.title}',
                      style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Secret Word Hero Display
              const Text('SECRET WORD',
                  style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  roundWord,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: ink, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 14),
              // Fraud Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: card2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: yellow.withValues(alpha: 0.4)),
                ),
                child: Text(
                  selectedMode.fraudCount > 1
                      ? 'Frauds: ${fraudIndices.map((i) => players[i]).join(', ')}'
                      : 'Fraud: ${fraudIndices.map((i) => players[i]).join(', ')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 14),
                ),
              ),
              if (undercoverIndex != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: card2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    'Undercover: ${players[undercoverIndex!]} (Word: "$roundUndercoverWord")',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // c. Total Leaderboard with Score Deltas (+N) and NO emojis
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Leaderboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...List.generate(sorted.length, (rankIdx) {
                final entry = sorted[rankIdx];
                final pIdx = players.indexOf(entry.key);
                final delta = pIdx != -1 ? (pointsEarnedThisRound[pIdx] ?? 0) : 0;
                final targetIdx = pIdx != -1 ? playerVotes[pIdx] : null;
                final votedTarget = (targetIdx != null && targetIdx >= 0 && targetIdx < players.length)
                    ? players[targetIdx]
                    : null;
                final rankNum = '${rankIdx + 1}.';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: rankIdx < 3 ? card2 : card2.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: rankIdx == 0 ? yellow.withValues(alpha: 0.6) : border,
                      width: rankIdx == 0 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(rankNum, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: yellow)),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              entry.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ink),
                            ),
                            if (votedTarget != null)
                              Text(
                                'voted $votedTarget',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (delta > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+$delta',
                                      style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                                Text(
                                  '${entry.value} pts',
                                  style: const TextStyle(
                                      color: yellow,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // d. Continue Button: Preserves cumulative scores and prompts back to category selection
        _primaryWithIcon('Continue', Icons.arrow_forward_rounded, () {
          Sound.tap();
          go(Screen.category);
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
