import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';

typedef WidgetResolver = Future<Widget> Function();

/// شاشة البداية: شعار + تحميل ثم انتقال تلقائي
class SplashScreen extends StatefulWidget {
  final WidgetResolver resolve;
  final String tagline;
  const SplashScreen({super.key, required this.resolve, required this.tagline});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    Widget next;
    try {
      next = await widget.resolve();
    } catch (_) {
      next = const SizedBox();
    }
    final left = 1200 - DateTime.now().difference(started).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.navy,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: AppColors.primary, borderRadius: BorderRadius.circular(28)),
              child: const Icon(Icons.local_taxi, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text(AppConfig.appName,
                style: TextStyle(
                    color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.tagline, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 32),
            const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('جاري التحميل...', style: TextStyle(color: Colors.white54)),
          ]),
        ),
      );
}

/// شاشة الترحيب
class WelcomeScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget Function() homeBuilder;
  final bool isDriver;
  const WelcomeScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.homeBuilder,
    this.isDriver = false,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              const CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.local_taxi, size: 56, color: Colors.white)),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(subtitle,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RegisterScreen(homeBuilder: homeBuilder, withCity: isDriver))),
                child: const Text('إنشاء حساب'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: homeBuilder))),
                child: const Text('تسجيل الدخول'),
              ),
            ]),
          ),
        ),
      );
}

InputDecoration _dec(String label, IconData icon, {Widget? suffix, String? prefix}) =>
    InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        prefixText: prefix);

class LoginScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  const LoginScreen({super.key, required this.homeBuilder});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  Future<void> _login() async {
    if (!AuthService.isValidPhone(_phone.text) || _pass.text.isEmpty) {
      showSnack(context, 'أدخل رقم موبايل مصري صحيح وكلمة المرور', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_phone.text, _pass.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تسجيل الدخول')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 12),
          const Text('مرحباً بعودتك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: _dec('رقم الجوال', Icons.phone, prefix: '${AppConfig.countryCode} ')),
          const SizedBox(height: 14),
          TextField(
            controller: _pass,
            obscureText: _hide,
            decoration: _dec('كلمة المرور', Icons.lock,
                suffix: IconButton(
                    icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _hide = !_hide))),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                        title: const Text('نسيت كلمة المرور؟'),
                        content: const Text(
                            'تواصل مع الدعم لإعادة تعيين كلمة المرور بعد التحقق من هويتك.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))
                        ],
                      )),
              child: const Text('نسيت كلمة المرور؟'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _login,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('تسجيل الدخول'),
          ),
        ]),
      );
}

class RegisterScreen extends StatefulWidget {
  final Widget Function() homeBuilder;
  final bool withCity;
  const RegisterScreen({super.key, required this.homeBuilder, this.withCity = false});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _city;
  bool _agree = false;
  bool _busy = false;

  static const cities = ['القاهرة', 'الجيزة', 'الإسكندرية', 'الأقصر', 'أسوان', 'سوهاج', 'أسيوط', 'المنيا', 'قنا', 'الشرقية', 'الدقهلية', 'الغربية', 'المنوفية', 'القليوبية', 'البحيرة', 'بورسعيد', 'السويس', 'الإسماعيلية', 'أخرى'];

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) return showSnack(context, 'أدخل الاسم الكامل', error: true);
    if (!AuthService.isValidPhone(_phone.text)) return showSnack(context, 'أدخل رقم موبايل مصري صحيح (مثال: 01012345678)', error: true);
    if (_email.text.isNotEmpty && !_email.text.contains('@')) {
      return showSnack(context, 'البريد الإلكتروني غير صحيح', error: true);
    }
    if (_pass.text.length < 6) {
      return showSnack(context, 'كلمة المرور 6 أحرف على الأقل', error: true);
    }
    if (widget.withCity && _city == null) return showSnack(context, 'اختر المدينة', error: true);
    if (!_agree) return showSnack(context, 'يجب الموافقة على الشروط والأحكام', error: true);
    setState(() => _busy = true);
    try {
      await AuthService.register(
          name: _name.text.trim(),
          phone: _phone.text,
          email: _email.text.trim(),
          password: _pass.text,
          city: _city);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => widget.homeBuilder()), (r) => false);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.withCity ? 'تسجيل السائق' : 'إنشاء حساب')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(controller: _name, decoration: _dec('الاسم الكامل', Icons.person)),
          const SizedBox(height: 12),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: _dec('رقم الجوال', Icons.phone, prefix: '${AppConfig.countryCode} ')),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: _dec('البريد الإلكتروني (اختياري)', Icons.email)),
          const SizedBox(height: 12),
          if (widget.withCity) ...[
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: _dec('المدينة', Icons.location_city),
              items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
              controller: _pass,
              obscureText: true,
              decoration: _dec('كلمة المرور', Icons.lock)),
          CheckboxListTile(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('أوافق على الشروط والأحكام'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(widget.withCity ? 'ابدأ التسجيل' : 'إنشاء الحساب'),
          ),
        ]),
      );
}
