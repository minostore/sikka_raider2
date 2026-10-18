import 'dart:convert';
import 'package:http/http.dart' as http;
import 'push_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/config.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);
}

/// فصل كامل بين حسابات الراكب والسائق:
/// - كل تطبيق له «هوية دخول» مستقلة داخل Firebase Auth، فيمكن لنفس رقم الهاتف أو
///   البريد الإلكتروني أن يسجّل في تطبيق السائق ثم في تطبيق المستخدم (حسابان مستقلان
///   ببيانات مستقلة في users/{uid} و drivers/{uid}).
/// - الراكب: بريده الحقيقي يتحوّل إلى عنوان معزول `name+sikkarider@domain` (يصل لنفس صندوق البريد).
/// - السائق: رقم الهاتف على نطاق خاص بالسائقين `phone@drivers.mishwar.app`.
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

  /// رقم موبايل مصري: 10/11/12/15 + 8 أرقام (10 أرقام بعد +20)
  static bool isValidPhone(String input) => RegExp(r'^201[0125][0-9]{8}$').hasMatch(normalizePhone(input));

  static const String _legacyDomain = 'users.mishwar.app';
  static String _phoneDomain(String role) => role == 'driver' ? 'drivers.mishwar.app' : _legacyDomain;

  static String _phoneEmail(String phone, {String? role}) => '${normalizePhone(phone)}@${_phoneDomain(role ?? AppConfig.role)}';

  /// البريد الحقيقي → عنوان معزول لكل تطبيق (نفس صندوق البريد، هوية Firebase مختلفة).
  static String _roleAlias(String email, String role) {
    final e = email.trim().toLowerCase();
    final at = e.lastIndexOf('@');
    if (at <= 0) return e;
    final local = e.substring(0, at).split('+').first;
    return '$local+sikka$role@${e.substring(at + 1)}';
  }

  /// الهويات المحتملة للدخول بالترتيب: الجديدة أولاً ثم القديمة (حسابات أُنشئت قبل الفصل).
  static List<String> _loginCandidates(String identifier) {
    final id = identifier.trim();
    final role = AppConfig.role;
    if (id.contains('@')) {
      final plain = id.toLowerCase();
      return [_roleAlias(plain, role), plain];
    }
    final list = <String>[_phoneEmail(id)];
    if (role == 'driver') list.add('${normalizePhone(id)}@$_legacyDomain');
    return list;
  }

  /// يقبل بريداً إلكترونياً أو رقم موبايل
  static Future<void> signIn(String identifier, String password) async {
    UserCredential? cred;
    FirebaseAuthException? last;
    for (final email in _loginCandidates(identifier)) {
      try {
        cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
        break;
      } on FirebaseAuthException catch (e) {
        last = e;
        const retry = {'invalid-credential', 'wrong-password', 'user-not-found', 'invalid-email'};
        if (!retry.contains(e.code)) rethrow;
      }
    }
    if (cred == null) throw last ?? AppAuthException('البيانات غير صحيحة.');
    final id = cred.user!.uid;
    final role = (await _db.child('users/$id/role').get()).value?.toString();
    final status = (await _db.child('users/$id/status').get()).value?.toString();
    if (role != AppConfig.role) {
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

  /// يمنع إنشاء أكثر من حساب بنفس رقم الهاتف في التطبيق نفسه (التحقق على خادم اللوحة).
  /// إن تعذر الوصول للخادم نكمل التسجيل حتى لا يتعطل التطبيق؛ وتبقى قاعدة «بريد/هاتف واحد» في Firebase.
  static Future<void> _assertPhoneFree(String phone, String role) async {
    try {
      final r = await http
          .post(Uri.parse('${AppConfig.adminApiBase}/api/auth/check-available'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'phone': normalizePhone(phone), 'role': role}))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200 && (jsonDecode(r.body) as Map)['phoneTaken'] == true) {
        throw AppAuthException('رقم الهاتف هذا مسجّل مسبقًا في التطبيق. سجّل الدخول بدلًا من إنشاء حساب جديد.');
      }
    } on AppAuthException {
      rethrow;
    } catch (_) {}
  }

  static Future<void> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? city,
    String? firstName,
    String? lastName,
  }) async {
    final role = AppConfig.role;
    await _assertPhoneFree(phone, role);
    // الراكب: البريد (بعد العزل) هو هوية الدخول. السائق: رقم الجوال على نطاق السائقين.
    final loginEmail = (role == 'rider' && email.contains('@')) ? _roleAlias(email, role) : _phoneEmail(phone);
    final cred = await _auth.createUserWithEmailAndPassword(email: loginEmail, password: password);
    final id = cred.user!.uid;
    await cred.user!.updateDisplayName(name);
    final p = normalizePhone(phone);
    final updates = <String, Object?>{
      'users/$id': {
        'name': name,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        'phone': p,
        'email': email,
        'role': role,
        'status': 'active',
        'createdAt': ServerValue.timestamp,
      },
    };
    if (role == 'driver') {
      updates['drivers/$id'] = {
        'name': name,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        'phone': p,
        'email': email,
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

  /// استرجاع كلمة المرور: نرسل للعنوان المعزول ثم للعنوان القديم (للحسابات السابقة).
  static Future<void> resetPassword(String email) async {
    final plain = email.trim().toLowerCase();
    FirebaseAuthException? notFound;
    var sent = false;
    for (final e in {_roleAlias(plain, AppConfig.role), plain}) {
      try {
        await _auth.sendPasswordResetEmail(email: e);
        sent = true;
      } on FirebaseAuthException catch (ex) {
        if (ex.code == 'user-not-found') {
          notFound = ex;
        } else {
          rethrow;
        }
      }
    }
    if (!sent && notFound != null) throw notFound;
  }

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
          return 'هذا الحساب مسجّل مسبقاً في هذا التطبيق. سجّل الدخول.';
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
