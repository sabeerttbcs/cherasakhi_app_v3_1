/**
 * Pure quiz logic — MUST stay identical to the Dart versions in
 *   lib/features/quiz/domain/usecases/answer_tools.dart
 *   lib/features/quiz/domain/usecases/quiz_evaluation.dart
 * so every phone and the server always agree on the winner.
 */
const crypto = require('crypto');

// Legacy Malayalam chillu (consonant + virama + ZWJ) → atomic chillu.
const CHILLUS = {
  'ണ്‍': 'ൺ', // ൺ
  'ന്‍': 'ൻ', // ൻ
  'ര്‍': 'ർ', // ർ
  'ല്‍': 'ൽ', // ൽ
  'ള്‍': 'ൾ', // ൾ
  'ക്‍': 'ൿ', // ൿ
};

function normalizeAnswer(input) {
  let t = String(input == null ? '' : input).trim().toLowerCase();
  for (const [legacy, atomic] of Object.entries(CHILLUS)) t = t.split(legacy).join(atomic);
  t = t.replace(/[​-‍﻿]/g, '');
  t = t.replace(/[^\p{L}\p{M}\p{N}\s]/gu, ' ');
  return t.replace(/\s+/g, ' ').trim();
}

function isCorrectAnswer(submitted, secret) {
  const s = normalizeAnswer(submitted);
  if (!s) return false;
  const accepted = [secret.answer, ...(secret.acceptedAnswers || [])];
  return accepted.some((a) => normalizeAnswer(a) === s);
}

function sealAnswer(answer, salt) {
  const hex = crypto.createHash('sha256').update(`${salt}|${normalizeAnswer(answer)}`, 'utf8').digest('hex');
  return `sha256:${hex}`;
}

/** Firestore Timestamp (or {seconds, nanoseconds}) → integer microseconds. */
function toMicros(ts) {
  if (!ts) return 0;
  const seconds = ts.seconds !== undefined ? ts.seconds : ts._seconds;
  const nanos = ts.nanoseconds !== undefined ? ts.nanoseconds : ts._nanoseconds;
  return seconds * 1000000 + Math.floor(nanos / 1000);
}

function fastestFirst(a, b) {
  if (a.micros !== b.micros) return a.micros - b.micros;
  return a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0;
}

/**
 * Fastest Finger First.
 * @param {{startMicros:number, endMicros:number}} window
 * @param {{answer:string, acceptedAnswers?:string[]}} secret
 * @param {Array<{userId:string,userName:string,submittedAnswer:string,submittedAt:any}>} submissions
 */
function evaluateQuiz(window, secret, submissions) {
  const valid = submissions
    .map((s) => ({ ...s, micros: toMicros(s.submittedAt) }))
    .filter((s) => s.micros >= window.startMicros && s.micros < window.endMicros);
  const correct = valid.filter((s) => isCorrectAnswer(s.submittedAnswer, secret)).sort(fastestFirst);
  const winner = correct[0] || null;
  return {
    winner,
    fastestCorrect: correct,
    correctCount: correct.length,
    totalSubmissions: valid.length,
    correctAnswer: secret.answer,
  };
}

module.exports = { normalizeAnswer, isCorrectAnswer, sealAnswer, toMicros, evaluateQuiz };
