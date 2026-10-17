import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../entities/quiz_models.dart';

// Legacy Malayalam chillus (consonant + virama + ZWJ) → atomic chillu letters,
// so "അവന്‍" typed on an old keyboard equals "അവൻ" typed on a new one.
const Map<String, String> _chillus = {
  'ണ്‍': 'ൺ', // ൺ
  'ന്‍': 'ൻ', // ൻ
  'ര്‍': 'ർ', // ർ
  'ല്‍': 'ൽ', // ൽ
  'ള്‍': 'ൾ', // ൾ
  'ക്‍': 'ൿ', // ൿ
};

final RegExp _zeroWidth = RegExp('[​-‍﻿]');
final RegExp _punctuation = RegExp(r'[^\p{L}\p{M}\p{N}\s]', unicode: true);
final RegExp _spaces = RegExp(r'\s+');

/// Canonical form used for comparing answers and for the seal.
/// Must stay identical to `normalizeAnswer` in functions/quiz_logic.js.
String normalizeAnswer(String input) {
  var t = input.trim().toLowerCase();
  _chillus.forEach((legacy, atomic) => t = t.replaceAll(legacy, atomic));
  t = t.replaceAll(_zeroWidth, '');
  t = t.replaceAll(_punctuation, ' ');
  return t.replaceAll(_spaces, ' ').trim();
}

bool isCorrectAnswer(String submitted, QuizSecret secret) {
  final s = normalizeAnswer(submitted);
  if (s.isEmpty) return false;
  return secret.allAccepted.any((a) => normalizeAnswer(a) == s);
}

/// 128-bit random salt (hex). Without it, a 4-option question could be
/// "decrypted" by hashing each option.
String generateSalt() {
  final rnd = Random.secure();
  return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// `sha256:<hex>` commitment published with the contest.
String sealAnswer(String answer, String salt) =>
    'sha256:${sha256.convert(utf8.encode('$salt|${normalizeAnswer(answer)}'))}';

/// After the reveal: proves the answer is the one sealed before the start.
bool verifySeal(QuizContest contest, QuizSecret secret) =>
    sealAnswer(secret.answer, secret.salt) == contest.encryptedAnswer;
