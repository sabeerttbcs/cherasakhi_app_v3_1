/**
 * CheraSakhi push sender + quiz evaluator (Cloud Functions, 2nd gen).
 *
 *   onPamparamWinner  draw created          → push to the KURI COHORT only
 *   onQuizScheduled   quiz created          → push to ALL members
 *   quizTicker        every minute          → "quiz is live" push at startTime;
 *                                             at endTime: lock, evaluate
 *                                             (Fastest Finger First), write
 *                                             the result, push winner to ALL
 *
 * Deploy:  cd functions && npm install && cd .. && firebase deploy --only functions
 * Needs the Blaze (pay-as-you-go) plan.
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { evaluateQuiz, toMicros } = require('./quiz_logic');

initializeApp();
const REGION = 'asia-south1';
const TIME_ZONE = 'Asia/Kolkata';

const rupees = (n) => '₹' + Number(n || 0).toLocaleString('en-IN');
const clock = (ts) =>
  ts.toDate().toLocaleTimeString('en-IN', { timeZone: TIME_ZONE, hour: '2-digit', minute: '2-digit', hour12: true });
const preciseClock = (ts) => {
  const d = ts.toDate();
  const base = d.toLocaleTimeString('en-IN', {
    timeZone: TIME_ZONE, hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true,
  });
  return base.replace(/(\d{2}:\d{2}:\d{2})/, `$1.${String(d.getMilliseconds()).padStart(3, '0')}`);
};

/** uids allowed to receive Kuri pushes (authoritative: users/{uid}). */
async function kuriUids(db) {
  const users = await db.collection('users').get();
  const ok = new Set();
  users.forEach((u) => {
    const d = u.data();
    const flag = d.isKuriMember !== undefined ? d.isKuriMember === true : d.memberId != null;
    if (d.role === 'admin' || flag) ok.add(u.id);
  });
  return ok;
}

/**
 * @param {'kuri'|'all'} audience
 */
async function sendPush({ audience, title, body, type, key, excludeUid }) {
  const db = getFirestore();
  const [snap, allowed] = await Promise.all([
    db.collection('deviceTokens').get(),
    audience === 'kuri' ? kuriUids(db) : Promise.resolve(null),
  ]);
  const tokens = snap.docs
    .filter((d) => d.get('uid') !== excludeUid)
    .filter((d) => !allowed || allowed.has(d.get('uid')))
    .map((d) => d.id);
  if (tokens.length === 0) return;

  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      data: { type, key, title, body },
      android: { priority: 'high', notification: { channelId: 'cherasakhi_alerts', color: '#4A0E2E' } },
      apns: { payload: { aps: { sound: 'default' } } },
      webpush: { notification: { icon: 'icons/Icon-192.png', tag: key } },
    });
    const dead = [];
    res.responses.forEach((r, idx) => {
      const code = r.error && r.error.code;
      if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
        dead.push(db.collection('deviceTokens').doc(batch[idx]).delete());
      }
    });
    await Promise.all(dead);
  }
}

// ───────────────────────── Kuri (cohort only) ─────────────────────────

exports.onPamparamWinner = onDocumentCreated(
  { document: 'cycles/{cycleId}/draws/{monthKey}', region: REGION },
  async (event) => {
    const d = event.data && event.data.data();
    if (!d) return;
    await sendPush({
      audience: 'kuri',
      title: '🏆 പമ്പരം വിജയി! (Pamparam winner)',
      body: `${d.winnerName} won the ${event.params.monthKey} Kuri — ${rupees(d.amount)}`,
      type: 'winner',
      key: `${event.params.cycleId}/${event.params.monthKey}`,
      excludeUid: d.drawnBy,
    });
  }
);

// ───────────────────────── Live quiz (everyone) ─────────────────────────

exports.onQuizScheduled = onDocumentCreated({ document: 'quizzes/{quizId}', region: REGION }, async (event) => {
  const q = event.data && event.data.data();
  if (!q || q.status !== 'scheduled') return;
  const day = q.startTime.toDate().toLocaleDateString('en-IN', { timeZone: TIME_ZONE, weekday: 'short', day: 'numeric', month: 'short' });
  await sendPush({
    audience: 'all',
    title: '📅 പുതിയ ക്വിസ്! (New live quiz)',
    body: `${q.title} — ${day}, ${clock(q.startTime)} to ${clock(q.endTime)}`,
    type: 'quiz',
    key: `scheduled:${event.params.quizId}`,
    excludeUid: q.createdBy,
  });
});

async function evaluateAndAnnounce(doc) {
  const db = getFirestore();
  const q = doc.data();
  const [secretSnap, subsSnap] = await Promise.all([
    doc.ref.collection('secret').doc('answer').get(),
    doc.ref.collection('submissions').get(),
  ]);
  if (!secretSnap.exists) return;
  const secret = secretSnap.data();
  const outcome = evaluateQuiz(
    { startMicros: toMicros(q.startTime), endMicros: toMicros(q.endTime) },
    secret,
    subsSnap.docs.map((d) => d.data())
  );
  const w = outcome.winner;

  // Write once, even if two ticker runs overlap.
  const written = await db.runTransaction(async (tx) => {
    const fresh = await tx.get(doc.ref);
    if (fresh.get('result')) return false;
    tx.update(doc.ref, {
      status: 'completed',
      result: {
        correctAnswer: outcome.correctAnswer,
        correctCount: outcome.correctCount,
        totalSubmissions: outcome.totalSubmissions,
        winnerId: w ? w.userId : null,
        winnerName: w ? w.userName : null,
        winnerAnswer: w ? w.submittedAnswer : null,
        winnerSubmittedAt: w ? w.submittedAt : null,
        evaluatedBy: 'function',
        evaluatedAt: FieldValue.serverTimestamp(),
      },
    });
    return true;
  });
  if (!written) return;

  await sendPush({
    audience: 'all',
    title: '🏆 ക്വിസ് വിജയി! (Quiz winner)',
    body: w
      ? `${w.userName} won “${q.title}” — answer: ${outcome.correctAnswer} (at ${preciseClock(w.submittedAt)})`
      : `No correct answers in “${q.title}”. Answer: ${outcome.correctAnswer}`,
    type: 'winner',
    key: `result:${doc.id}`,
  });
}

exports.quizTicker = onSchedule({ schedule: 'every 1 minutes', region: REGION, timeZone: TIME_ZONE }, async () => {
  const db = getFirestore();
  const now = Timestamp.now();
  const open = await db.collection('quizzes').where('status', '==', 'scheduled').get();

  for (const doc of open.docs) {
    const q = doc.data();
    try {
      if (q.endTime.toMillis() <= now.toMillis()) {
        await evaluateAndAnnounce(doc);
      } else if (q.startTime.toMillis() <= now.toMillis() && !q.startNotified) {
        await doc.ref.update({ startNotified: true });
        await sendPush({
          audience: 'all',
          title: '📝 ലൈവ് ക്വിസ് ആരംഭിച്ചു! (Live quiz started)',
          body: `${q.title} — answer before ${clock(q.endTime)}`,
          type: 'quiz',
          key: `start:${doc.id}`,
          excludeUid: q.createdBy,
        });
      }
    } catch (e) {
      console.error(`quizTicker: ${doc.id}`, e);
    }
  }
});
