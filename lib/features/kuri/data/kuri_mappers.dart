import '../../../core/network/firestore_utils.dart';
import '../domain/entities/claim.dart';
import '../domain/entities/kuri_cycle.dart';
import '../domain/entities/member.dart';
import '../domain/entities/payment.dart';

Member memberFromDoc(JsonDoc d) {
  final m = d.data() ?? const <String, dynamic>{};
  return Member(
    id: d.id,
    name: asString(m['name']),
    phone: asString(m['phone']),
    seatNo: asInt(m['seatNo']),
    isActive: m['isActive'] as bool? ?? true,
    joinedAt: tsToDate(m['joinedAt']),
  );
}

KuriCycle cycleFromDoc(JsonDoc d) {
  final m = d.data() ?? const <String, dynamic>{};
  return KuriCycle(
    id: d.id,
    name: asString(m['name'], 'Kuri'),
    startMonth: asString(m['startMonth']),
    durationMonths: asInt(m['durationMonths'], 60),
    monthlyInstallment: asDouble(m['monthlyInstallment']),
    status: m['status'] == 'active' ? CycleStatus.active : CycleStatus.closed,
    createdAt: tsToDate(m['createdAt']),
  );
}

Payment paymentFromDoc(JsonDoc d) {
  final m = d.data() ?? const <String, dynamic>{};
  return Payment(
    memberId: asString(m['memberId']),
    monthKey: asString(m['monthKey']),
    paid: m['paid'] == true,
    amount: asDouble(m['amount']),
    paidAt: tsToDate(m['paidAt']),
    markedBy: m['markedBy'] as String?,
  );
}

Claim claimFromDoc(JsonDoc d) {
  final m = d.data() ?? const <String, dynamic>{};
  return Claim(
    memberId: d.id,
    memberName: asString(m['memberName']),
    hasClaimed: m['hasClaimed'] == true,
    claimedMonth: asString(m['claimedMonth']),
    amount: asDouble(m['amount']),
    claimedAt: tsToDate(m['claimedAt']),
  );
}
