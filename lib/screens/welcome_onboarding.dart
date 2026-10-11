import 'package:flutter/material.dart';
import '../core/theme.dart';
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
  static const _slides = <_SlideData>[
    _SlideData('رحلتك .. بأسهل طريقة', 'اترك وجهتك علينا، ونوصلك بأمان وسرعة مع أفضل السائقين في مدينتك.', Icons.directions_car_filled_rounded, 'سِكّة'),
    _SlideData('اختر وجهتك بسهولة', 'حدد نقطة الانطلاق والوجهة، واختر نوع الخدمة التي تناسبك.', Icons.map_rounded, 'حدد الطريق'),
    _SlideData('اختر السائق الأنسب لك', 'قارن السعر والتقييم والمسافة ونوع السيارة قبل تأكيد الرحلة.', Icons.verified_user_rounded, 'اختيارك بإيدك'),
    _SlideData('رحلتك بأمان في كل وقت', 'تابع رحلتك مباشرة، وتواصل مع السائق من داخل التطبيق.', Icons.location_on_rounded, 'تابع رحلتك'),
  ];
  @override
  void dispose() { _pages.dispose(); super.dispose(); }
  void _next() {
    if (_index < _slides.length - 1) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: widget.homeBuilder)));
    }
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF03172D), Color(0xFF082B4C), Color(0xFF031326)])),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(24, 14, 24, 0), child: Row(children: [
            const Spacer(),
            Column(children: [
              const Icon(Icons.add_location_alt_rounded, color: Color(0xFFFFB800), size: 42),
              const Text('سِكّة', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1.0)),
              const Text('— Sikka —', style: TextStyle(color: Color(0xFFFFB800), fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ]),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: widget.homeBuilder))), child: const Text('تخطي', style: TextStyle(color: Colors.white70))),
          ])),
          Expanded(child: PageView.builder(controller: _pages, itemCount: _slides.length, onPageChanged: (i) => setState(() => _index = i), itemBuilder: (context, i) {
            final s = _slides[i];
            return Padding(padding: const EdgeInsets.fromLTRB(28, 14, 28, 8), child: Column(children: [
              const SizedBox(height: 16),
              RichText(textAlign: TextAlign.center, text: TextSpan(style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, height: 1.4), children: [TextSpan(text: s.title.split(' ').take(1).join(' ') + ' ', style: const TextStyle(color: Colors.white)), TextSpan(text: s.title.split(' ').skip(1).join(' '), style: const TextStyle(color: Color(0xFFFFB800)))])),
              const SizedBox(height: 10),
              Text(s.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD5DFEA), fontSize: 16, height: 1.6)),
              const SizedBox(height: 18),
              Expanded(child: Stack(alignment: Alignment.center, children: [
                Positioned(bottom: 18, left: 0, right: 0, child: CustomPaint(size: const Size(double.infinity, 150), painter: _CityPainter())),
                Container(width: 240, height: 300, decoration: BoxDecoration(color: const Color(0xFF0C3155).withOpacity(.8), borderRadius: BorderRadius.circular(36), border: Border.all(color: const Color(0xFFFFB800), width: 1.4), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 28, offset: Offset(0, 12))]),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 148, height: 148, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFB800).withOpacity(.12), border: Border.all(color: const Color(0xFFFFB800).withOpacity(.45))), child: Icon(s.icon, size: 88, color: const Color(0xFFFFB800))),
                    const SizedBox(height: 24), Text(s.tag, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (j) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: j == i % 3 ? 34 : 8, height: 8, decoration: BoxDecoration(color: j == i % 3 ? const Color(0xFFFFB800) : Colors.white30, borderRadius: BorderRadius.circular(8))))),
                  ])),
                Positioned(bottom: 20, right: 22, child: _pin(Icons.location_on_rounded)),
                Positioned(top: 28, left: 22, child: _pin(Icons.flag_rounded)),
              ])),
            ]));
          })),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 5), width: i == _index ? 28 : 10, height: 10, decoration: BoxDecoration(color: i == _index ? const Color(0xFFFFB800) : Colors.white38, borderRadius: BorderRadius.circular(10))))),
          Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 8), child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB800), foregroundColor: const Color(0xFF061B31), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), onPressed: _next, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_index == _slides.length - 1 ? 'ابدأ الآن' : 'التالي'), const SizedBox(width: 12), const Icon(Icons.arrow_forward_rounded, size: 28)])))),
          Padding(padding: const EdgeInsets.only(bottom: 18, top: 8), child: Wrap(alignment: WrapAlignment.center, children: [const Text('لديك حساب بالفعل؟ ', style: TextStyle(color: Colors.white70)), GestureDetector(onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(homeBuilder: widget.homeBuilder))), child: const Text('تسجيل الدخول', style: TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold)))])),
        ])),
      ),
    ),
  );
  Widget _pin(IconData icon) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF092849), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFB800))), child: Icon(icon, color: const Color(0xFFFFB800), size: 25));
}
class _SlideData { final String title, subtitle; final IconData icon; final String tag; const _SlideData(this.title,this.subtitle,this.icon,this.tag); }
class _CityPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF183B5B);
    const heights = [.45,.7,.55,.82,.42,.66,.9,.53,.73,.4,.62,.78];
    for (var i=0;i<heights.length;i++) { final w=size.width/12; final h=size.height*heights[i]; final r=Rect.fromLTWH(i*w,size.height-h,w-3,h); canvas.drawRRect(RRect.fromRectAndRadius(r,const Radius.circular(3)),p); final win=Paint()..color=const Color(0xFFFFC84A).withValues(alpha:.65); for(var y=r.top+8;y<r.bottom-4;y+=13){canvas.drawRect(Rect.fromLTWH(r.left+5,y,3,4),win); if(w>13) canvas.drawRect(Rect.fromLTWH(r.left+12,y,3,4),win);} }
    final road=Paint()..color=const Color(0xFFFFB800)..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round; final path=Path()..moveTo(0,size.height-12)..quadraticBezierTo(size.width*.35,size.height*.45,size.width*.58,size.height*.72)..quadraticBezierTo(size.width*.82,size.height*.9,size.width,size.height*.25); canvas.drawPath(path,road);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
