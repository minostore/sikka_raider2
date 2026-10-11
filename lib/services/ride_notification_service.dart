import 'package:firebase_database/firebase_database.dart';

/// In-app ride status notifications with deterministic IDs to make retries idempotent.
class RideNotificationService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static String _title(String status) => switch (status) {
    'requested' => 'تم إرسال طلب الرحلة',
    'accepted' => 'تم قبول الرحلة',
    'arrived' => 'السائق وصل إلى موقعك',
    'started' => 'بدأت الرحلة',
    'completed' => 'اكتملت الرحلة بنجاح',
    'cancelled' => 'تم إلغاء الرحلة',
    _ => 'تحديث الرحلة',
  };

  static String _body(String status, String rideId) => switch (status) {
    'requested' => 'طلبك #${_short(rideId)} أصبح متاحاً للسائقين.',
    'accepted' => 'تم اختيار سائق لرحلتك #${_short(rideId)}.',
    'arrived' => 'السائق في انتظارك عند نقطة الانطلاق.',
    'started' => 'رحلتك الآن في الطريق إلى الوجهة.',
    'completed' => 'شكراً لاستخدامك سِكّة. يمكنك تقييم الرحلة الآن.',
    'cancelled' => 'تم إلغاء الرحلة #${_short(rideId)}.',
    _ => 'تم تحديث حالة رحلتك #${_short(rideId)}.',
  };

  static String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  static Future<void> notifyStatus({required String rideId, required String status,
    String? riderId, String? driverId}) async {
    if (riderId == null || riderId.isEmpty) return;
    final recipients = <String>{riderId, if (driverId != null && driverId.isNotEmpty) driverId};
    final notificationId = 'ride_${rideId}_$status';
    final now = DateTime.now().millisecondsSinceEpoch;
    await Future.wait(recipients.map((uid) async {
      final ref = _db.child('notifications/$uid/$notificationId');
      try {
        await ref.runTransaction((Object? value) {
        if (value != null) return Transaction.abort();
        return Transaction.success({
          'title': _title(status), 'body': _body(status, rideId),
          'rideId': rideId, 'status': status, 'type': 'ride_status',
          'createdAt': now, 'read': false,
        });
        });
      } catch (_) { /* Notifications must not block the ride lifecycle. */ }
    }));
  }
}
