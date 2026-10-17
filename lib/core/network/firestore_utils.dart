import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;
typedef JsonDoc = DocumentSnapshot<Json>;

DateTime? tsToDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

double asDouble(Object? v) => v is num ? v.toDouble() : 0;
int asInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String asString(Object? v, [String fallback = '']) => v is String ? v : fallback;
