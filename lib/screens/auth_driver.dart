import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

/// مشهد غروب على الطريق (الشاشة الافتتاحية)
class RoadPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B2A44), Color(0xFF1C3F63), Color(0xFFE8863A)], stops: [0, .55, .78]).createShader(Offset.zero & s));
    final hy = s.height * 0.55;
    c.drawCircle(Offset(s.width * .5, hy), s.width * .17, Paint()..color = const Color(0xFFF59A3C));
    final b = Paint()..color = const Color(0xFF0A1E33);
    for (final r in [[0.0, .10, .20], [.10, .08, .30], [.18, .09, .16], [.74, .09, .26], [.84, .07, .18], [.91, .09, .32]]) {
      c.drawRect(Rect.fromLTWH(s.width * r[0], hy - s.height * r[2] * .6, s.width * r[1], s.height * r[2] * .6 + 2), b);
    }
    c.drawRect(Rect.fromLTWH(0, hy, s.width, s.height - hy), Paint()..color = const Color(0xFF0C1F33));
    final road = Path()..moveTo(s.width * .44, hy)..lineTo(s.width * .56, hy)..lineTo(s.width * 1.05, s.height)..lineTo(-s.width * .05, s.height)..close();
    c.drawPath(road, Paint()..color = const Color(0xFF16283D));
    for (var i = 0; i < 6; i++) {
      final t = i / 6, w = 2 + 8 * t;
      final y = hy + (s.height - hy) * (t * t + .02);
      c.drawRect(Rect.fromCenter(center: Offset(s.width * .5, y), width: w, height: 8 + 22 * t), Paint()..color = Colors.white70);
    }
    // السيارة (من الخلف)
    final cx = s.width * .5, by = s.height * .90;
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, by - 24), width: s.width * .46, height: 52), const Radius.circular(14));
    c.drawRRect(body, Paint()..color = const Color(0xFF0A1420));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, by - 62), width: s.width * .34, height: 34), const Radius.circular(12)), Paint()..color = const Color(0xFF111E2D));
    for (final dx in [-1, 1]) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dx * s.width * .17, by - 28), width: 36, height: 10), const Radius.circular(5)), Paint()..color = const Color(0xFFFF3B30));
    }
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, by - 10), width: 44, height: 12), const Radius.circular(3)), Paint()..color = const Color(0xFFDADADA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DriverSplash extends StatefulWidget {
  final Future<Widget> Function() resolve;
  const DriverSplash({super.key, required this.resolve});
  @override
  State<DriverSplash> createState() => _DriverSplashState();
}

class _DriverSplashState extends State<DriverSplash> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final t = DateTime.now();
    Widget next = const SizedBox();
    try {
      next = await widget.resolve();
    } catch (_) {}
    final left = 1800 - DateTime.now().difference(t).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: RoadPainter())),
          Positioned(
            left: 0,
            right: 0,
            bottom: 70,
            child: Column(children: [
              const Text('معاً لرحلة أفضل', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('فرص أكثر - دخل أعلى', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle)),
              ]),
            ]),
          ),
        ]),
      );
}

/// خطوات التسجيل 1 - 2 - 3
class StepperHeader extends StatelessWidget {
  final int step;
  const StepperHeader(this.step, {super.key});
  @override
  Widget build(BuildContext context) {
    Widget dot(int n) => Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: n <= step ? AppColors.primary : const Color(0xFF1B3F5E), shape: BoxShape.circle),
          child: Text('$n', style: TextStyle(color: n <= step ? AppColors.navy : Colors.white70, fontWeight: FontWeight.w900)),
        );
    Widget line(int n) => Expanded(child: Container(height: 2, color: n < step ? AppColors.primary : const Color(0xFF1B3F5E)));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 60), child: Row(children: [dot(1), line(1), dot(2), line(2), dot(3)]));
  }
}

// ───────────── تسجيل الدخول (رقم الهاتف) ─────────────
class LoginScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  const LoginScreen({super.key, required this.homeBuilder});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(), _pass = TextEditingController();
  bool _remember = true, _busy = false;

  Future<void> _login() async {
    if (!AuthService.isValidPhone(_phone.text) || _pass.text.isEmpty) return showSnack(context, 'أدخل رقم موبايل مصري صحيح وكلمة المرور', error: true);
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_phone.text, _pass.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 70, 24, 24), children: [
            const Text('تسجيل الدخول', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 40),
            TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'رقم الهاتف', Icons.smartphone)),
            const SizedBox(height: 14),
            TextField(controller: _pass, obscureText: true, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'كلمة المرور', Icons.lock_outline)),
            const SizedBox(height: 6),
            Row(children: [
              Checkbox(value: _remember, activeColor: AppColors.primary, checkColor: AppColors.navy, onChanged: (v) => setState(() => _remember = v ?? true)),
              const Text('تذكرني', style: TextStyle(color: Colors.white)),
            ]),
            const SizedBox(height: 12),
            AppButton('تسجيل الدخول', onPressed: _login, busy: _busy),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('نسيت كلمة المرور؟'), content: const Text('تواصل مع الدعم لإعادة تعيين كلمة المرور بعد التحقق من هويتك.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))])),
                child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(homeBuilder: widget.homeBuilder))),
                child: const Text('سائق جديد؟ سجّل الآن', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ]),
        ),
      );
}

// ───────────── تسجيل السائق: الخطوة 1 ─────────────
class RegisterScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  const RegisterScreen({super.key, required this.homeBuilder});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _phone = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  String? _city;
  bool _busy = false;
  static const cities = ['القاهرة', 'الجيزة', 'الإسكندرية', 'الأقصر', 'أسوان', 'سوهاج', 'أسيوط', 'المنيا', 'قنا', 'الشرقية', 'الدقهلية', 'الغربية', 'المنوفية', 'القليوبية', 'البحيرة', 'بورسعيد', 'السويس', 'الإسماعيلية', 'أخرى'];

  Future<void> _next() async {
    if (_name.text.trim().length < 3) return showSnack(context, 'أدخل الاسم الكامل', error: true);
    if (!AuthService.isValidPhone(_phone.text)) return showSnack(context, 'أدخل رقم موبايل مصري صحيح (مثال: 01012345678)', error: true);
    if (_email.text.isNotEmpty && !_email.text.contains('@')) return showSnack(context, 'البريد الإلكتروني غير صحيح', error: true);
    if (_pass.text.length < 6) return showSnack(context, 'كلمة المرور 6 أحرف على الأقل', error: true);
    if (_city == null) return showSnack(context, 'اختر المدينة', error: true);
    setState(() => _busy = true);
    try {
      await AuthService.register(name: _name.text.trim(), phone: _phone.text, email: _email.text.trim(), password: _pass.text, city: _city);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), children: [
            const Text('تسجيل السائق', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 22),
            const StepperHeader(1),
            const SizedBox(height: 26),
            TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'الاسم الكامل', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'رقم الهاتف', Icons.smartphone)),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'البريد الإلكتروني', Icons.mail_outline)),
            const SizedBox(height: 12),
            TextField(controller: _pass, obscureText: true, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, 'كلمة المرور', Icons.lock_outline)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              dropdownColor: const Color(0xFF173B5A),
              style: const TextStyle(color: Colors.white),
              decoration: fieldDec(context, 'المدينة', Icons.location_city),
              items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 20),
            AppButton('التالي', onPressed: _next, busy: _busy),
            Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('لدي حساب — تسجيل الدخول', style: TextStyle(color: Colors.white70)))),
          ]),
        ),
      );
}

