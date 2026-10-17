import 'package:flutter_test/flutter_test.dart';
import 'package:kuri_collective/features/auth/domain/app_user.dart';
import 'package:kuri_collective/features/quiz/domain/entities/quiz_models.dart';
import 'package:kuri_collective/features/quiz/domain/usecases/answer_tools.dart';
import 'package:kuri_collective/features/quiz/domain/usecases/quiz_evaluation.dart';

// Same vectors as functions/quiz_logic.test.js — phone and server must agree.
QuizSubmission sub(String id, String name, String answer, int seconds, [int micros = 0]) => QuizSubmission(
      userId: id,
      userName: name,
      submittedAnswer: answer,
      submittedAtMicros: seconds * 1000000 + micros,
    );

QuizContest contest({required int startSec, required int endSec, String seal = ''}) => QuizContest(
      id: 'q1',
      title: 'Test',
      category: '',
      startTime: DateTime.fromMicrosecondsSinceEpoch(startSec * 1000000),
      endTime: DateTime.fromMicrosecondsSinceEpoch(endSec * 1000000),
      encryptedAnswer: seal,
      answerMode: AnswerMode.text,
      status: QuizStatus.scheduled,
    );

void main() {
  group('normalizeAnswer', () {
    test('case, spaces, punctuation', () {
      expect(normalizeAnswer('  Al-Baqarah!! '), 'al baqarah');
      expect(normalizeAnswer('114.'), '114');
    });
    test('Malayalam legacy chillu equals atomic chillu', () {
      expect(normalizeAnswer('മുഹര്‍റം'), normalizeAnswer('മുഹർറം'));
      expect(normalizeAnswer('തിരുവനന്തപുരം'), 'തിരുവനന്തപുരം');
    });
  });

  test('accepted alternatives', () {
    const secret = QuizSecret(answer: 'Makkah', acceptedAnswers: ['Mecca', 'മക്ക'], salt: 's');
    expect(isCorrectAnswer('mecca', secret), isTrue);
    expect(isCorrectAnswer(' മക്ക ', secret), isTrue);
    expect(isCorrectAnswer('Madinah', secret), isFalse);
    expect(isCorrectAnswer('   ', secret), isFalse);
  });

  test('seal matches the server (golden value)', () {
    expect(sealAnswer('Makkah', '00112233445566778899aabbccddeeff'), 'sha256:c2ab2efb6f1c9242192d6b3d8b28b67284148d0bea5fd42b554642c6828b9bd3');
    expect(sealAnswer(' makkah ', 'abc'), sealAnswer('MAKKAH', 'abc'));
    expect(sealAnswer('114', 'abc') == sealAnswer('114', 'xyz'), isFalse);
  });

  test('fastest correct answer wins; window is [start, end)', () {
    const secret = QuizSecret(answer: '114', salt: 'abc');
    final c = contest(startSec: 1000, endSec: 2800, seal: sealAnswer('114', 'abc'));
    final o = evaluateQuiz(contest: c, secret: secret, submissions: [
      sub('u1', 'Aysha', '110', 1010),
      sub('u2', 'Fathima', '114', 1252, 347000),
      sub('u3', 'Majeedha', '114', 1252, 346999),
      sub('u4', 'Late', '114', 2800),
      sub('u5', 'Early', '114', 999),
    ]);
    expect(o.winner?.userName, 'Majeedha');
    expect(o.fastestCorrect.map((s) => s.userId).toList(), ['u3', 'u2']);
    expect(o.correctCount, 2);
    expect(o.totalSubmissions, 3);
    expect(o.sealVerified, isTrue);
    expect(o.rankOf('u2'), 2);
    expect(o.rankOf('u1'), isNull);
  });

  test('tampered answer key fails seal verification', () {
    final c = contest(startSec: 0, endSec: 10, seal: sealAnswer('114', 'abc'));
    final o = evaluateQuiz(contest: c, secret: const QuizSecret(answer: '110', salt: 'abc'), submissions: const []);
    expect(o.sealVerified, isFalse);
  });

  test('exact tie broken by userId', () {
    final o = evaluateQuiz(
      contest: contest(startSec: 0, endSec: 100),
      secret: const QuizSecret(answer: 'A', salt: 's'),
      submissions: [sub('zz', 'Z', 'a', 5), sub('aa', 'A', 'a', 5)],
    );
    expect(o.winner?.userId, 'aa');
  });

  test('phase follows server time; contest never stops early', () {
    final c = contest(startSec: 100, endSec: 200);
    DateTime at(int s) => DateTime.fromMicrosecondsSinceEpoch(s * 1000000);
    expect(c.phaseAt(at(99)), QuizPhase.scheduled);
    expect(c.phaseAt(at(100)), QuizPhase.live);
    expect(c.phaseAt(at(199)), QuizPhase.live);
    expect(c.phaseAt(at(200)), QuizPhase.ended);
  });

  test('timer colours', () {
    const total = Duration(minutes: 30);
    expect(timerToneFor(const Duration(minutes: 20), total), TimerTone.calm);
    expect(timerToneFor(const Duration(minutes: 12), total), TimerTone.warning);
    expect(timerToneFor(const Duration(minutes: 5, seconds: 59), total), TimerTone.critical); // < 20 %
    // Short quiz: the 5-minute rule is capped at a third, so 4 of 5 minutes is still calm.
    expect(timerToneFor(const Duration(minutes: 4), const Duration(minutes: 5)), TimerTone.calm);
  });

  test('AppUser role helpers', () {
    const admin = AppUser(uid: 'a', name: 'A', role: UserRole.admin);
    const kuri = AppUser(uid: 'k', name: 'K', role: UserRole.member, isKuriMember: true);
    const community = AppUser(uid: 'c', name: 'C', role: UserRole.member);
    expect(admin.canAccessKuri, isTrue);
    expect(admin.canPlayQuiz, isFalse);
    expect(kuri.canAccessKuri, isTrue);
    expect(community.canAccessKuri, isFalse);
    expect(community.canPlayQuiz, isTrue);
    expect(community.isCommunityOnly, isTrue);
  });
}
