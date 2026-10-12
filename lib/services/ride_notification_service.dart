import 'package:firebase_database/firebase_database.dart';

/// In-app ride status notifications with deterministic IDs to make retries idempotent.
class RideNotificationService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static String _title(String status, {required bool forDriver}) => switch (status) {
    'requested' => forDriver ? 'طلب رحلة جديد متاح' : 'تم إرسال طلب الرحلة',
    'accepted' => forDriver ? 'تم قبول الرحلة' : 'تم قبول رحلتك',
    'arrived' => forDriver ? 'تم تسجيل وصولك' : 'السائق وصل إلى موقعك',
    'started' => forDriver ? 'بدأت الرحلة' : 'بدأت رحلتك الآن',
    'completed' => forDriver ? 'تم إنهاء الرحلة' : 'اكتملت الرحلة بنجاح',
    'cancelled' => 'تم إلغاء الرحلة',
    _ => 'تحديث الرحلة',
  };

  static String _body(String status, String rideId, {required bool forDriver}) => switch (status) {
    'requested' => forDriver
        ? 'رحلة جديدة #${_short(rideId)} متاحة لك لمراجعة التفاصيل وتقديم عرض.'
        : 'طلبك #${_short(rideId)} أصبح متاحاً للسائقين.',
    'accepted' => forDriver
        ? 'تم تأكيد قبول الرحلة #${_short(rideId)}. راجع تفاصيل الرحلة.'
        : 'تم اختيار سائق لرحلتك #${_short(rideId)}.',
    'arrived' => forDriver
        ? 'تم تحديث حالة الرحلة #${_short(rideId)} إلى وصل السائق.'
        : 'السائق في انتظارك عند نقطة الانطلاق.',
    'started' => forDriver
        ? 'بدأت الرحلة #${_short(rideId)}. قد بأمان.'
        : 'رحلتك الآن في الطريق إلى الوجهة.',
    'completed' => forDriver
        ? 'انتهت الرحلة #${_short(rideId)}. يمكنك مراجعة أرباحك وتفاصيلها.'
        : 'شكراً لاستخدامك سِكّة. يمكنك تقييم الرحلة الآن.',
    'cancelled' => 'تم إلغاء الرحلة #${_short(rideId)}.',
    _ => 'تم تحديث حالة رحلتك #${_short(rideId)}.',
  };

  static String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  static Future<void> notifyStatus({
    required String rideId,
    required String status,
    String? riderId,
    String? driverId,
  }) async {
    final recipients = <String>{
      if (riderId != null && riderId.isNotEmpty) riderId,
      if (driverId != null && driverId.isNotEmpty) driverId,
    };
    if (recipients.isEmpty || rideId.isEmpty || status.isEmpty) return;
    final notificationId = 'ride_${rideId}_$status';
    await Future.wait(recipients.map((uid) async {
      final ref = _db.child('notifications/$uid/$notificationId');
      final forDriver = driverId != null && uid == driverId;
      try {
        await ref.runTransaction((Object? value) {
          if (value != null) return Transaction.abort();
          return Transaction.success({
            'title': _title(status, forDriver: forDriver),
            'body': _body(status, rideId, forDriver: forDriver),
            'rideId': rideId,
            'status': status,
            'type': 'ride_status',
            'createdAt': ServerValue.timestamp,
            'read': false,
          });
        });
      } catch (_) {
        // A notification failure must never block the ride lifecycle.
      }
    }));
  }
}
