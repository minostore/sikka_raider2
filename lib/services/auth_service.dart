import 'push_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/config.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  static User? get user => _auth.currentUser;
  static String get uid => _auth.currentUser!.uid;

  /// يحوّل الرقم المحلي إلى صيغة دولية بدون + (مثال: 201012345678)
  static String normalizePhone(String input) {
    var d = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    final cc = AppConfig.countryCode.replaceAll('+', '');
    if (d.startsWith(cc)) return d;
    if (d.startsWith('0')) d = d.substring(1);
    return '$cc$d';
  }

  /// رقم موبايل مصري: 010/011/012/015 + 8 أرقام
  static bool isValidPhone(String input) => RegExp(r'^201[0125][0-9]{8}$').hasMatch(normalizePhone(input));

  // الهوية داخل Firebase Auth = بريد وهمي مشتق من رقم الجوال (بدون الحاجة لخدمة SMS)
  static String _email(String phone) => '${normalizePhone(phone)}@users.mishwar.app';

  /// يقبل بريداً إلكترونياً أو رقم موبايل
  static Future<void> signIn(String identifier, String password) async {
    final id0 = identifier.trim();
    final cred = await _auth.signInWithEmailAndPassword(
        email: id0.contains('@') ? id0.toLowerCase() : _email(id0), password: password);
    final id = cred.user!.uid;
    final role = (await _db.child('users/$id/role').get()).value?.toString();
    final status = (await _db.child('users/$id/status').get()).value?.toString();
    if (role != null && role != AppConfig.role) {
      await _auth.signOut();
      throw AppAuthException(role == 'driver'
          ? 'هذا الحساب مسجّل كسائق. استخدم تطبيق السائق.'
          : 'هذا الحساب مسجّل كراكب. استخدم تطبيق الراكب.');
    }
    if (status == 'suspended') {
      await _auth.signOut();
      throw AppAuthException('تم إيقاف هذا الحساب. تواصل مع الدعم.');
    }
  }

  static Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? city,
  }) async {
    // الراكب: بريده الحقيقي هو هوية الدخول (يدعم استرجاع كلمة المرور). السائق: الجوال.
    final loginEmail = (AppConfig.role == 'rider' && email.contains('@')) ? email.toLowerCase() : _email(phone);
    final cred = await _auth.createUserWithEmailAndPassword(email: loginEmail, password: password);
    final id = cred.user!.uid;
    await cred.user!.updateDisplayName(name);
    final p = normalizePhone(phone);
    final updates = <String, Object?>{
      'users/$id': {
        'name': name,
        'phone': p,
        'email': email,
        'role': AppConfig.role,
        'status': 'active',
        'createdAt': ServerValue.timestamp,
      },
    };
    if (AppConfig.role == 'driver') {
      updates['drivers/$id'] = {
        'name': name,
        'phone': p,
        'city': city ?? '',
        'status': 'incomplete',
        'createdAt': ServerValue.timestamp,
      };
    }
    await _db.update(updates);
  }

  static Future<void> signOut() async {
    await PushService.clearToken();
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

  static String message(Object e) {
    if (e is AppAuthException) return e.message;
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-email':
          return 'البيانات غير صحيحة. تأكد من البريد/الجوال وكلمة المرور.';
        case 'email-already-in-use':
          return 'هذا الحساب مسجّل مسبقاً. سجّل الدخول.';
        case 'weak-password':
          return 'كلمة المرور ضعيفة (6 أحرف على الأقل).';
        case 'network-request-failed':
          return 'لا يوجد اتصال بالإنترنت.';
        case 'too-many-requests':
          return 'محاولات كثيرة. حاول لاحقاً.';
        case 'operation-not-allowed':
          return 'فعّل تسجيل الدخول بالبريد/كلمة المرور من Firebase Console.';
      }
      return 'خطأ في المصادقة (${e.code}).';
    }
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'لا تملك صلاحية تنفيذ العملية. تحقق من قواعد Firebase.';
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}
