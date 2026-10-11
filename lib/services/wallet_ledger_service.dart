import 'package:firebase_database/firebase_database.dart';

/// سجل مالي ذريّ لكل مستخدم. يجب استدعاؤه من خادم موثوق فقط عند تنفيذ
/// الخصومات/العمولات الحقيقية؛ لا تمنح تطبيقات العميل صلاحية تعديل balance مباشرة.
class WalletLedgerService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Applies one ledger entry exactly once per [operationId].
  /// Returns true when applied, false when this operation was already applied.
  static Future<bool> applyOnce({
    required String uid,
    required String operationId,
    required double amount,
    required String type,
    required String title,
    String? rideId,
    String? reference,
  }) async {
    if (uid.trim().isEmpty || operationId.trim().isEmpty) {
      throw ArgumentError('uid و operationId مطلوبان');
    }
    if (!amount.isFinite || amount == 0) {
      throw ArgumentError('قيمة المعاملة غير صالحة');
    }
    // One transaction covers balance + immutable ledger + idempotency marker.
    final ref = _db.child('wallets/$uid');
    final result = await ref.runTransaction((Object? value) {
      final wallet = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
      final processed = wallet['processedOperations'] is Map
          ? Map<String, dynamic>.from(wallet['processedOperations'] as Map)
          : <String, dynamic>{};
      if (processed.containsKey(operationId)) return Transaction.abort();
      final tx = wallet['tx'] is Map
          ? Map<String, dynamic>.from(wallet['tx'] as Map)
          : <String, dynamic>{};
      final balanceRaw = wallet['balance'];
      final balance = balanceRaw is num ? balanceRaw.toDouble() : 0.0;
      final nextBalance = double.parse((balance + amount).toStringAsFixed(2));
      if (nextBalance < 0) return Transaction.abort();
      final now = ServerValue.timestamp;
      tx[operationId] = <String, Object?>{
        'operationId': operationId,
        'amount': double.parse(amount.toStringAsFixed(2)),
        'type': type,
        'source': type,
        'title': title,
        'rideId': rideId ?? '',
        'reference': reference ?? operationId,
        'createdAt': now,
      };
      processed[operationId] = true;
      wallet['balance'] = nextBalance;
      wallet['tx'] = tx;
      wallet['processedOperations'] = processed;
      return Transaction.success(wallet);
    }, applyLocally: false);
    if (result.committed) return true;
    // Distinguish duplicate from insufficient funds or a transaction abort.
    final snapshot = await ref.child('processedOperations/$operationId').get();
    if (snapshot.exists) return false;
    final current = await ref.child('balance').get();
    if (amount < 0 && current.value is num && (current.value as num).toDouble() + amount < 0) {
      throw StateError('الرصيد غير كافٍ لإتمام المعاملة');
    }
    throw StateError('تعذر تسجيل المعاملة المالية؛ أعد المحاولة لاحقاً');
  }
}
