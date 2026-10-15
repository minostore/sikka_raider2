import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../core/config.dart';
import 'auth_driver.dart';

/// واجهة ترحيب سكة — عربية RTL، بنفس لوحة الألوان المرجعية.
class SikkaWelcome extends StatefulWidget {
  final Widget Function() homeBuilder;
  const SikkaWelcome({super.key, required this.homeBuilder});
  @override
  State<SikkaWelcome> createState() => _SikkaWelcomeState();
}

class _SikkaWelcomeState extends State<SikkaWelcome> {
  final PageController _pages = PageController();
  int _index = 0;
  late final Future<List<String?>> _welcomeImages;

  @override
  void initState() {
    super.initState();
    _welcomeImages = _loadWelcomeImages();
  }

  List<String?> _posterUrls = const []; // روابط صور لوحة التحكم (تُعرض كبوستر كامل)
  List<(String, String)> _explicit = const []; // العنوان/النص المكتوبان فعلاً في لوحة التحكم

  bool _isPoster(int i) => (i < _slides.length && _slides[i].poster) || (i < _posterUrls.length && _posterUrls[i] != null);

  Widget _posterFor(int i) {
    final url = i < _posterUrls.length ? _posterUrls[i] : null;
    final ex = i < _explicit.length ? _explicit[i] : ('', '');
    return _PosterSlide(
      image: url != null ? NetworkImage(url) as ImageProvider : AssetImage(_slides[i].image),
      title: url != null ? ex.$1 : '',
      subtitle: url != null ? ex.$2 : '',
    );
  }

  List<_SlideData> _slides = _defaults;

  static List<Map<String, dynamic>> _slideEntries(dynamic raw) {
    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        out.add(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{});
      }
    } else if (raw is Map) {
      final keys = raw.keys.map((k) => int.tryParse(k.toString()) ?? -1).where((k) => k >= 0).toList()..sort();
      if (keys.isNotEmpty) {
        for (var i = 0; i <= keys.last; i++) {
          final e = raw['$i'];
          out.add(e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{});
        }
      }
    }
    return out;
  }

  /// شرائح الترحيب من لوحة التحكم (عدد غير محدود): صورة + عنوان + نص لكل شريحة، وإلا تُستخدم الافتراضية.
  Future<List<String?>> _loadWelcomeImages() async {
    try {
      final snap = await FirebaseDatabase.instance.ref('settings/welcome').once();
      final value = snap.snapshot.value;
      final welcome = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
      final entries = _slideEntries(welcome['driverSlides']);
      if (entries.isEmpty) return _loadLegacyImages();
      final slides = <_SlideData>[];
      final urls = <String?>[];
      final explicit = <(String, String)>[];
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final base = i < _defaults.length ? _defaults[i] : null;
        final title = (e['title'] ?? '').toString().trim();
        final subtitle = (e['subtitle'] ?? '').toString().trim();
        final image = (e['image'] ?? '').toString();
        slides.add(_SlideData(title.isNotEmpty ? title : (base?.title ?? ''), subtitle.isNotEmpty ? subtitle : (base?.subtitle ?? ''), base?.icon ?? Icons.directions_car_filled_rounded, base?.tag ?? 'سِكّة', base?.image ?? '', poster: base?.poster ?? false));
        urls.add(image.startsWith('https://') ? image : null);
        explicit.add((title, subtitle));
      }
      if (mounted) {
        setState(() {
          _slides = slides;
          _posterUrls = urls;
          _explicit = explicit;
          if (_index >= slides.length) _index = 0;
        });
      }
      return urls;
    } catch (_) {
      return _loadLegacyImages();
    }
  }

  Future<List<String?>> _loadLegacyImages() async {
    try {
      final s = await FirebaseDatabase.instance.ref('settings/welcome').once();
      final v = s.snapshot.value;
      final m = v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      final raw = m['driverImages'];
      final out = List<String?>.filled(4, null);
      if (raw is Map) {
        for (var i = 0; i < 4; i++) {
          final u = raw['$i']?.toString();
          if (u != null && u.startsWith('https://')) out[i] = u;
        }
      } else if (raw is List) {
        for (var i = 0; i < 4 && i < raw.length; i++) {
          final u = raw[i]?.toString();
          if (u != null && u.startsWith('https://')) out[i] = u;
        }
      }
      final legacy = m['driverImageUrl']?.toString();
      if (legacy != null &&
          legacy.startsWith('https://') &&
          out.every((e) => e == null))
        out[0] = legacy;
      return out;
    } catch (_) {
      return List<String?>.filled(4, null);
    }
  }

  static const _defaults = <_SlideData>[
    _SlideData('', '', Icons.directions_car_filled_rounded, 'سِكّة', 'assets/onboarding/driver_welcome.jpg', poster: true),
    _SlideData(
      'رحلتك .. بأسهل طريقة',
      'اترك وجهتك علينا، ونوصلك بأمان وسرعة مع أفضل السائقين في مدينتك.',
      Icons.directions_car_filled_rounded,
      'سِكّة',
      'assets/onboarding/driver_captain.jpg',
    ),
    _SlideData(
      'اختر وجهتك بسهولة',
      'حدد نقطة الانطلاق والوجهة، واختر نوع الخدمة التي تناسبك.',
      Icons.map_rounded,
      'حدد الطريق',
      'assets/onboarding/driver_trips.jpg',
    ),
    _SlideData(
      'اختر السائق الأنسب لك',
      'قارن السعر والتقييم والمسافة ونوع السيارة قبل تأكيد الرحلة.',
      Icons.verified_user_rounded,
      'اختيارك بإيدك',
      'assets/onboarding/driver_accepted_ride.jpg',
    ),
    _SlideData(
      'رحلتك بأمان في كل وقت',
      'تابع رحلتك مباشرة، وتواصل مع السائق من داخل التطبيق.',
      Icons.location_on_rounded,
      'تابع رحلتك',
      'assets/onboarding/driver_complete_trip.jpg',
    ),
  ];
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openLogin() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: widget.homeBuilder)),
      );

  void _openRegister() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RegisterScreen(homeBuilder: widget.homeBuilder)),
      );

  bool get _isLast => _index >= _slides.length - 1;

  void _next() {
    if (!_isLast) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _openRegister();
    }
  }

  /// شريحة بحجم الشاشة كاملة (صورة من لوحة التحكم أو الصورة الافتراضية).
  Widget _fullSlide(int i) {
    final slide = _slides[i];
    final url = i < _posterUrls.length ? _posterUrls[i] : null;
    final ex = i < _explicit.length ? _explicit[i] : ('', '');
    final title = url != null ? ex.$1 : slide.title;
    final subtitle = url != null ? ex.$2 : slide.subtitle;
    final fallback = Container(
      color: const Color(0xFF0C3155),
      child: Center(child: Icon(slide.icon, size: 120, color: const Color(0xFFFFCC00))),
    );
    final Widget image = url != null
        ? Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => fallback)
        : Image.asset(slide.image, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => fallback);
    return Stack(fit: StackFit.expand, children: [
      image,
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x66000000), Color(0x00000000), Color(0xD9000000)],
            stops: [0, 0.35, 1],
          ),
        ),
      ),
      if (title.isNotEmpty || subtitle.isNotEmpty)
        Positioned(
          left: 24,
          right: 24,
          bottom: 190,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (title.isNotEmpty)
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD84D), fontSize: 26, fontWeight: FontWeight.w900, height: 1.3)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
            ],
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF03172D),
          body: Stack(children: [
            // الصور تملأ الشاشة بالكامل
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _fullSlide(i),
              ),
            ),
            // زر «التالي» أعلى الصفحة حتى تنتهي الصور
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!_isLast)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCC00),
                          foregroundColor: const Color(0xFF061B31),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: const Text('التالي'),
                      )
                    else
                      const SizedBox(height: 44),
                  ]),
                ),
              ),
            ),
            // المؤشر وأزرار النهاية
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? const Color(0xFFFFCC00) : Colors.white54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    if (_isLast) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            foregroundColor: const Color(0xFF061B31),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                          ),
                          onPressed: _openRegister,
                          child: const Text('ابدأ الآن'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70, width: 1.4),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          onPressed: _openLogin,
                          child: const Text('تسجيل الدخول'),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _SlideData {
  final String title, subtitle, image;
  final IconData icon;
  final String tag;
  final bool poster;
  const _SlideData(this.title, this.subtitle, this.icon, this.tag, this.image, {this.poster = false});
}

class _CityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF183B5B);
    const heights = [.45, .7, .55, .82, .42, .66, .9, .53, .73, .4, .62, .78];
    for (var i = 0; i < heights.length; i++) {
      final w = size.width / 12;
      final h = size.height * heights[i];
      final r = Rect.fromLTWH(i * w, size.height - h, w - 3, h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), p);
      final win = Paint()
        ..color = const Color(0xFFFFC84A).withValues(alpha: .65);
      for (var y = r.top + 8; y < r.bottom - 4; y += 13) {
        canvas.drawRect(Rect.fromLTWH(r.left + 5, y, 3, 4), win);
        if (w > 13) canvas.drawRect(Rect.fromLTWH(r.left + 12, y, 3, 4), win);
      }
    }
    final road = Paint()
      ..color = const Color(0xFFFFCC00)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height - 12)
      ..quadraticBezierTo(
        size.width * .35,
        size.height * .45,
        size.width * .58,
        size.height * .72,
      )
      ..quadraticBezierTo(
        size.width * .82,
        size.height * .9,
        size.width,
        size.height * .25,
      );
    canvas.drawPath(path, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شريحة «بوستر» كاملة: الصورة تملأ المساحة (من لوحة التحكم)، والعنوان/النص اختياريان تحتها.
class _PosterSlide extends StatelessWidget {
  final ImageProvider image;
  final String title, subtitle;
  const _PosterSlide({required this.image, this.title = '', this.subtitle = ''});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        child: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image(
                image: image,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white38, size: 64)),
              ),
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD84D), fontSize: 22, fontWeight: FontWeight.w900)),
          ],
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD5DFEA), fontSize: 14, height: 1.5)),
          ],
        ]),
      );
}

Widget _hideIf(bool hide, Widget child) => Visibility(visible: !hide, maintainSize: true, maintainAnimation: true, maintainState: true, child: child);
