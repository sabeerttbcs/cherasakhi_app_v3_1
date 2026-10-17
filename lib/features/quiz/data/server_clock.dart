import 'package:cloud_firestore/cloud_firestore.dart';

/// Phone clocks drift by seconds or minutes. Every countdown and lock in the
/// quiz uses server time: `DateTime.now() + offset`.
class ServerClock {
  const ServerClock(this.offset);

  static const zero = ServerClock(Duration.zero);

  final Duration offset;

  DateTime now() => DateTime.now().add(offset);
}

/// One round-trip to `clockSync/{uid}`: write a server timestamp, read it back
/// and compare with the local midpoint of the request. Accuracy ≈ network
/// latency / 2. Falls back to the device clock when offline.
Future<ServerClock> syncServerClock(FirebaseFirestore db, String uid) async {
  try {
    final ref = db.collection('clockSync').doc(uid);
    final t0 = DateTime.now();
    await ref.set({'t': FieldValue.serverTimestamp()}).timeout(const Duration(seconds: 8));
    final t1 = DateTime.now();
    final snap = await ref.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 8));
    final ts = snap.data()?['t'];
    if (ts is! Timestamp) return ServerClock.zero;
    final localMid = t0.add(t1.difference(t0) ~/ 2);
    return ServerClock(ts.toDate().difference(localMid));
  } catch (_) {
    return ServerClock.zero;
  }
}
