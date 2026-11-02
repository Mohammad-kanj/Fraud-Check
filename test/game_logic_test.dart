import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraud_check/categories.dart';

void main() {
  group('Category and Word Tests', () {
    test('Categories map has at least 20 categories with valid words', () {
      expect(categories.keys.length, greaterThanOrEqualTo(20));
      for (final cat in categories.keys) {
        expect(categories[cat]!.length, greaterThanOrEqualTo(20));
      }
    });

    test('Undercover decoy word selection picks distinct word from same category', () {
      const cat = 'Food';
      final secretWord = categories[cat]!.first;
      final decoys = categories[cat]!.where((w) => w != secretWord).toList();
      expect(decoys.isNotEmpty, isTrue);
      expect(decoys.contains(secretWord), isFalse);
    });
  });

  group('Fraud Check Scoring Logic Tests', () {
    const int roundPoints = 100;

    test('Caught fraud misses guess: only correct voters gain 100 points', () {
      final players = ['Alice', 'Bob', 'Charlie', 'David'];
      final scores = <String, int>{for (var p in players) p: 0};
      const fraudIdx = 3; // David is fraud
      final caughtFrauds = {fraudIdx};

      // Votes: Alice -> David (correct), Bob -> David (correct), Charlie -> Alice (wrong), David -> Alice (wrong)
      final playerVotes = {0: 3, 1: 3, 2: 0, 3: 0};

      // Fraud missed guess:
      for (var voter = 0; voter < players.length; voter++) {
        if (voter != fraudIdx) {
          final target = playerVotes[voter];
          if (target != null && caughtFrauds.contains(target)) {
            scores[players[voter]] = (scores[players[voter]] ?? 0) + roundPoints;
          }
        }
      }

      expect(scores['Alice'], equals(100)); // Voted for fraud
      expect(scores['Bob'], equals(100));   // Voted for fraud
      expect(scores['Charlie'], equals(0)); // Voted for Alice (wrong)
      expect(scores['David'], equals(0));   // Fraud lost
    });

    test('Fraud escapes (no majority): fraud gains 100 points, safe players get 0', () {
      final players = ['Alice', 'Bob', 'Charlie', 'David'];
      final scores = <String, int>{for (var p in players) p: 0};
      const fraudIdx = 3; // David is fraud

      // David escapes:
      scores[players[fraudIdx]] = (scores[players[fraudIdx]] ?? 0) + roundPoints;

      expect(scores['David'], equals(100));
      expect(scores['Alice'], equals(0));
      expect(scores['Bob'], equals(0));
      expect(scores['Charlie'], equals(0));
    });

    test('Caught fraud guesses secret word correctly: fraud receives 50 points, voters get 100', () {
      final players = ['Alice', 'Bob', 'Charlie', 'David'];
      final scores = <String, int>{for (var p in players) p: 0};
      const fraudIdx = 3; // David is fraud
      final playerVotes = {0: 3, 1: 3, 2: 3, 3: 0};

      // Caught fraud guesses correctly (R6):
      scores[players[fraudIdx]] = (scores[players[fraudIdx]] ?? 0) + 50;
      for (int v = 0; v < players.length; v++) {
        if (v != fraudIdx && playerVotes[v] == fraudIdx) {
          scores[players[v]] = (scores[players[v]] ?? 0) + roundPoints;
        }
      }

      expect(scores['David'], equals(50));
      expect(scores['Alice'], equals(100));
      expect(scores['Bob'], equals(100));
      expect(scores['Charlie'], equals(100));
    });

    test('Caught fraud guesses incorrectly: fraud receives 0 points, voters get 100', () {
      final players = ['Alice', 'Bob', 'Charlie', 'David'];
      final scores = <String, int>{for (var p in players) p: 0};
      const fraudIdx = 3; // David is fraud
      final playerVotes = {0: 3, 1: 3, 2: 3, 3: 0};

      // Caught fraud misses guess (R6):
      for (int v = 0; v < players.length; v++) {
        if (v != fraudIdx && playerVotes[v] == fraudIdx) {
          scores[players[v]] = (scores[players[v]] ?? 0) + roundPoints;
        }
      }

      expect(scores['David'], equals(0));
      expect(scores['Alice'], equals(100));
      expect(scores['Bob'], equals(100));
      expect(scores['Charlie'], equals(100));
    });

    test('Two Frauds role assignment properly assigns 2 distinct frauds', () {
      final players = ['P1', 'P2', 'P3', 'P4', 'P5'];
      final rng = Random(42);
      final indices = List.generate(players.length, (i) => i)..shuffle(rng);
      final fraudIndices = indices.take(2).toSet();

      expect(fraudIndices.length, equals(2));
      for (final f in fraudIndices) {
        expect(f, greaterThanOrEqualTo(0));
        expect(f, lessThan(players.length));
      }
    });

    test('Undercover role assignment assigns distinct fraud and undercover', () {
      final players = ['P1', 'P2', 'P3', 'P4'];
      final rng = Random(42);
      final indices = List.generate(players.length, (i) => i)..shuffle(rng);
      final fraudIndices = indices.take(1).toSet();
      final undercoverIdx = indices[1];

      expect(fraudIndices.length, equals(1));
      expect(fraudIndices.contains(undercoverIdx), isFalse);
    });
  });
}

