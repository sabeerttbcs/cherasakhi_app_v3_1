import '../entities/claim.dart';
import '../entities/kuri_cycle.dart';
import '../entities/member.dart';
import '../entities/payment.dart';

abstract interface class KuriRepository {
  Stream<List<Member>> watchMembers();
  Future<void> addMember({required String name, required String phone, required int seatNo});
  Future<void> updateMember(Member member);

  Stream<KuriCycle?> watchActiveCycle();
  Future<void> startCycle({
    required String name,
    required String startMonth,
    required int durationMonths,
    required double monthlyInstallment,
    required String byUid,
  });

  /// memberId -> Payment for the given month.
  Stream<Map<String, Payment>> watchPayments(String cycleId, String monthKey);

  Future<void> setPayment({
    required String cycleId,
    required String monthKey,
    required Member member,
    required bool paid,
    required double amount,
    required String byUid,
  });

  Stream<List<Claim>> watchClaims(String cycleId);
}
