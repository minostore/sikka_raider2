import 'package:flutter/material.dart';
import 'auth_driver.dart';

/// رحلة تعريفية من أربع خطوات لكابتن سِكّة، تظهر قبل تسجيل الدخول.
class SikkaWelcome extends StatefulWidget {
  final Widget Function() homeBuilder;
  const SikkaWelcome({super.key, required this.homeBuilder});

  @override
  State<SikkaWelcome> createState() => _SikkaWelcomeState();
}

class _SikkaWelcomeState extends State<SikkaWelcome> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      'ابدأ معنا يا كابتن',
      'انضم إلى سِكّة، وابدأ مشاويرك بسيارتك وحقق دخلًا مع كل رحلة.',
      'assets/onboarding/driver_captain.jpg',
      Icons.drive_eta_rounded,
    ),
    _SlideData(
      'اختار رحلتك',
      'تصفّح الطلبات القريبة منك وشوف تفاصيل كل مشوار قبل ما تقدم عرضك.',
      'assets/onboarding/driver_trips.jpg',
      Icons.route_rounded,
    ),
    _SlideData(
      'اقبل الرحلة واعرف تفاصيلها',
      'راجع نقطة الاستلام والوجهة والسعر، وتواصل مع الراكب من التطبيق.',
      'assets/onboarding/driver_accepted_ride.jpg',
      Icons.receipt_long_rounded,
    ),
    _SlideData(
      'أكمل الرحلة بثقة',
      'تابع المسار حتى الوجهة، ثم أنهِ الرحلة وشاهد ملخص مشوارك.',
      'assets/onboarding/driver_complete_trip.jpg',
      Icons.check_circle_rounded,
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

  void _next() {
    if (_index < _slides.length - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      _openLogin();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF03172D), Color(0xFF082B4C), Color(0xFF031326)],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(children: [
                    const Spacer(),
                    Column(children: const [
                      Icon(Icons.add_location_alt_rounded, color: Color(0xFFFFB800), size: 36),
                      Text('سِكّة', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, height: 1.0)),
                      Text('— Sikka —', style: TextStyle(color: Color(0xFFFFB800), fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    ]),
                    const Spacer(),
                    TextButton(onPressed: _openLogin, child: const Text('تخطي', style: TextStyle(color: Colors.white70))),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Column(children: [
                          const SizedBox(height: 8),
                          Text(slide.title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC23D), fontSize: 27, fontWeight: FontWeight.w900, height: 1.3)),
                          const SizedBox(height: 9),
                          Text(slide.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD5DFEA), fontSize: 15, height: 1.55)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 350, maxHeight: 360),
                                child: AspectRatio(
                                  aspectRatio: 4 / 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C3155),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: const Color(0xFFFFB800), width: 1.4),
                                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10))],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.asset(
                                      slide.image,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(child: Icon(slide.fallbackIcon, size: 100, color: const Color(0xFFFFB800))),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: i == _index ? const Color(0xFFFFB800) : Colors.white38, borderRadius: BorderRadius.circular(8)),
                ))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: const Color(0xFF061B31), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      onPressed: _next,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_index == _slides.length - 1 ? 'ابدأ معنا' : 'التالي'), const SizedBox(width: 10), const Icon(Icons.arrow_forward_rounded)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15, top: 5),
                  child: Wrap(alignment: WrapAlignment.center, children: [
                    const Text('لديك حساب بالفعل؟ ', style: TextStyle(color: Colors.white70)),
                    GestureDetector(onTap: _openLogin, child: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _SlideData {
  final String title;
  final String subtitle;
  final String image;
  final IconData fallbackIcon;
  const _SlideData(this.title, this.subtitle, this.image, this.fallbackIcon);
}
