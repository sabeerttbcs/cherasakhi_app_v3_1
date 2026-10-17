// Run: node --test functions/quiz_logic.test.js
// The same vectors are checked in Dart by test/quiz_logic_test.dart.
const test = require('node:test');
const assert = require('node:assert');
const { normalizeAnswer, isCorrectAnswer, sealAnswer, evaluateQuiz } = require('./quiz_logic');

const ts = (seconds, nanoseconds = 0) => ({ seconds, nanoseconds });

test('normalization: case, spaces, punctuation', () => {
  assert.strictEqual(normalizeAnswer('  Al-Baqarah!! '), 'al baqarah');
  assert.strictEqual(normalizeAnswer('MAKKAH'), 'makkah');
  assert.strictEqual(normalizeAnswer('114.'), '114');
});

test('normalization: Malayalam legacy chillu equals atomic chillu', () => {
  const legacy = 'മുഹര്‍റം'; // ര്‍ (ZWJ form)
  const atomic = 'മുഹർറം'; // ർ
  assert.strictEqual(normalizeAnswer(legacy), normalizeAnswer(atomic));
  assert.strictEqual(normalizeAnswer('തിരുവനന്തപുരം'), 'തിരുവനന്തപുരം'); // vowel signs kept
});

test('accepted alternatives', () => {
  const secret = { answer: 'Makkah', acceptedAnswers: ['Mecca', 'മക്ക'] };
  assert.ok(isCorrectAnswer('mecca', secret));
  assert.ok(isCorrectAnswer(' മക്ക ', secret));
  assert.ok(!isCorrectAnswer('Madinah', secret));
  assert.ok(!isCorrectAnswer('   ', secret));
});

test('seal is salted and stable', () => {
  const a = sealAnswer('114', 'abc');
  assert.match(a, /^sha256:[0-9a-f]{64}$/);
  assert.strictEqual(a, sealAnswer(' 114 ', 'abc'));
  assert.notStrictEqual(a, sealAnswer('114', 'xyz'));
  // Golden value shared with the Dart test.
  assert.strictEqual(sealAnswer('Makkah', '00112233445566778899aabbccddeeff'),
    'sha256:' + require('crypto').createHash('sha256').update('00112233445566778899aabbccddeeff|makkah').digest('hex'));
});

test('fastest correct answer wins; contest does not stop early', () => {
  const start = 1000, end = 2800; // 30-minute window, seconds
  const window = { startMicros: start * 1e6, endMicros: end * 1e6 };
  const secret = { answer: '114', acceptedAnswers: [] };
  const subs = [
    { userId: 'u1', userName: 'Aysha', submittedAnswer: '110', submittedAt: ts(1010) },        // fast but wrong
    { userId: 'u2', userName: 'Fathima', submittedAnswer: '114', submittedAt: ts(1252, 347000000) },
    { userId: 'u3', userName: 'Majeedha', submittedAnswer: '114', submittedAt: ts(1252, 346999000) }, // 1 µs earlier
    { userId: 'u4', userName: 'Late', submittedAnswer: '114', submittedAt: ts(2800) },          // exactly at end → excluded
    { userId: 'u5', userName: 'Early', submittedAnswer: '114', submittedAt: ts(999) },          // before start → excluded
  ];
  const r = evaluateQuiz(window, secret, subs);
  assert.strictEqual(r.winner.userName, 'Majeedha');
  assert.deepStrictEqual(r.fastestCorrect.map((s) => s.userId), ['u3', 'u2']);
  assert.strictEqual(r.correctCount, 2);
  assert.strictEqual(r.totalSubmissions, 3);
});

test('exact tie broken by userId (deterministic everywhere)', () => {
  const window = { startMicros: 0, endMicros: 1e12 };
  const secret = { answer: 'A' };
  const r = evaluateQuiz(window, secret, [
    { userId: 'zz', userName: 'Z', submittedAnswer: 'a', submittedAt: ts(5) },
    { userId: 'aa', userName: 'A', submittedAnswer: 'a', submittedAt: ts(5) },
  ]);
  assert.strictEqual(r.winner.userId, 'aa');
});

test('no correct answers → no winner', () => {
  const r = evaluateQuiz({ startMicros: 0, endMicros: 1e12 }, { answer: 'x' },
    [{ userId: 'u', userName: 'U', submittedAnswer: 'y', submittedAt: ts(1) }]);
  assert.strictEqual(r.winner, null);
  assert.strictEqual(r.correctCount, 0);
});
