import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class _LegalPage {
  final String id, title, body;
  const _LegalPage(this.id, this.title, this.body);
}

const List<_LegalPage> _riderPages = [
  _LegalPage(
    'terms',
    'شروط وأحكام استخدام التطبيق (العميل)',
    '1) القبول: باستخدامك تطبيق سِكّة فأنت توافق على هذه الشروط. إن لم توافق فلا تستخدم التطبيق.\n\n'
    '2) الحساب: تلتزم بتقديم بيانات صحيحة (الاسم ورقم الهاتف) وبالحفاظ على سرية بيانات دخولك، وأنت مسؤول عن كل نشاط يتم من حسابك.\n\n'
    '3) الخدمة: سِكّة منصة تربط العميل بالكابتن المستقل ولا تملك المركبات ولا تقدم النقل بنفسها. السعر يُحدد حسب العرض الذي تقبله، وتدفعه كما هو ظاهر في التطبيق.\n\n'
    '4) الإلغاء: يمكنك إلغاء الرحلة قبل البدء، وقد تُطبق رسوم إلغاء إذا تأخر الإلغاء بعد وصول الكابتن أو قبوله العرض وفق ما تحدده الإدارة.\n\n'
    '5) السلوك: احترم الكابتن والمركبة، ويُمنع التدخين أو نقل المواد المحظورة أو التسبب في أي ضرر. للكابتن الحق في إنهاء الرحلة عند المخالفة.\n\n'
    '6) المتعلقات الشخصية: أنت مسؤول عن متعلقاتك الشخصية. يرجى مراجعتها قبل النزول من السيارة؛ الشركة غير مسؤولة عن فقدان المتعلقات أو تلفها. يمكنك الإبلاغ عن غرض مفقود من «المساعدة والدعم» وسنحاول التواصل مع الكابتن دون أي التزام بالتعويض.\n\n'
    '7) السلامة: استخدم أدوات السلامة في التطبيق عند الحاجة، واربط حزام الأمان. في الطوارئ اتصل بالجهات المختصة فورًا.\n\n'
    '8) إيقاف الحساب: يحق للإدارة إيقاف أو حذف أي حساب يخالف هذه الشروط أو يسيء استخدام التطبيق.\n\n'
    '9) التعديل: قد نعدّل هذه الشروط من وقت لآخر، واستمرارك في الاستخدام يعني موافقتك على التعديلات.',
  ),
  _LegalPage(
    'privacy',
    'سياسة الخصوصية',
    'نستخدم موقعك أثناء استخدام التطبيق فقط لتحديد نقطة الالتقاط وتتبع الرحلة، ولا نشاركه مع أي جهة خارج الرحلة إلا بطلب قانوني. نحتفظ ببيانات حسابك ورحلاتك لتقديم الخدمة وتحسينها ولأغراض الأمان والدعم. يمكنك طلب تعديل بياناتك أو حذف حسابك بالتواصل مع الدعم.',
  ),
];

const List<_LegalPage> _driverPages = [
  _LegalPage(
    'driver_terms',
    'شروط وأحكام الكابتن',
    '1) الاستقلالية: الكابتن مقدّم خدمة مستقل، وسِكّة وسيط تقني يربطه بالعملاء، ولا تنشأ علاقة عمل بين الكابتن والشركة.\n\n'
    '2) المستندات: يلتزم الكابتن بتقديم مستندات سارية وصحيحة (البطاقة الشخصية، رخصة القيادة، رخصة المركبة بوجهيها) وتحديثها عند انتهائها، ويحق للإدارة رفض أو إيقاف الحساب عند نقصها أو عدم صحتها.\n\n'
    '3) المركبة: تكون المركبة نظيفة وصالحة للسير ومطابقة للبيانات المسجلة، ويُمنع استخدام مركبة غير مسجلة.\n\n'
    '4) التحقق: قد يُطلب من الكابتن التحقق من هويته بالصورة عند الاتصال، ويُمنع تسليم الحساب أو استخدامه من شخص آخر.\n\n'
    '5) قبول الرحلات والالتزام بالسعر: يلتزم الكابتن بالعرض الذي قدّمه وبالوصول في الوقت المذكور، ويُمنع طلب مبالغ إضافية خارج التطبيق.\n\n'
    '6) العمولة والمحفظة: تُخصم عمولة الشركة وفق النسبة المعلنة في التطبيق. للمحفظة حد أقصى للرصيد تحدده الإدارة، وطلبات الشحن تخضع لمراجعتها.\n\n'
    '7) السلوك والسلامة: يلتزم الكابتن بحسن المعاملة وقواعد المرور وعدم القيادة تحت تأثير مواد محظورة، ويُمنع أي تحرش أو إساءة أو عنف. قد تُوقف المخالفات الحساب فورًا.\n\n'
    '8) متعلقات العملاء: يلتزم الكابتن بمراجعة المقعد الخلفي بعد كل رحلة وتسليم أي غرض منسي للعميل عبر الدعم، والشركة غير مسؤولة عن فقدان المتعلقات.\n\n'
    '9) الإيقاف: يحق للإدارة إيقاف الحساب أو تقييده عند المخالفة أو تكرار الشكاوى أو الإلغاء المتكرر.\n\n'
    '10) التعديل: قد تُعدَّل هذه الشروط، واستمرارك في استخدام التطبيق يعني موافقتك عليها.',
  ),
  _LegalPage(
    'driver_privacy',
    'سياسة الخصوصية',
    'نجمع موقعك أثناء اتصالك بالتطبيق لعرض الرحلات القريبة وتتبع الرحلة، ونحتفظ بمستنداتك وصورتك لأغراض التحقق من الهوية فقط ولا نشاركها مع أي جهة خارجية إلا بطلب قانوني. يمكنك التواصل مع الدعم لتعديل بياناتك.',
  ),
];

/// شروط الاستخدام وسياسة الخصوصية (وأي صفحات أخرى تضيفها الإدارة من لوحة التحكم ← محتوى التطبيق).
class LegalScreen extends StatefulWidget {
  final String role; // rider | driver
  const LegalScreen({super.key, this.role = 'rider'});
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final Future<List<_LegalPage>> _f = _load();

  Future<List<_LegalPage>> _load() async {
    try {
      final raw = (await FirebaseDatabase.instance.ref(widget.role == 'driver' ? 'settings/legal/driverPages' : 'settings/legal/pages').get()).value;
      final entries = <MapEntry<String, Map<String, dynamic>>>[];
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map) entries.add(MapEntry(k.toString(), Map<String, dynamic>.from(v)));
        });
      } else if (raw is List) {
        for (var i = 0; i < raw.length; i++) {
          if (raw[i] is Map) entries.add(MapEntry('$i', Map<String, dynamic>.from(raw[i] as Map)));
        }
      }
      final list = entries.where((e) => e.value['active'] != false && (e.value['title'] ?? '').toString().trim().isNotEmpty).toList()
        ..sort((a, b) => ((a.value['order'] as num?) ?? 0).compareTo((b.value['order'] as num?) ?? 0));
      if (list.isNotEmpty) {
        return [for (final e in list) _LegalPage(e.key, e.value['title'].toString().trim(), (e.value['body'] ?? '').toString())];
      }
    } catch (_) {}
    return widget.role == 'driver' ? _driverPages : _riderPages;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.role == 'driver' ? 'شروط وأحكام الكابتن' : 'الشروط والخصوصية')),
        body: FutureBuilder<List<_LegalPage>>(
          future: _f,
          builder: (context, snap) {
            if (!snap.hasData) return const LoadingView();
            final pages = snap.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final p in pages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LegalPageScreen(page: p))),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.description_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        const Icon(Icons.chevron_left),
                      ]),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

class _LegalPageScreen extends StatelessWidget {
  final _LegalPage page;
  const _LegalPageScreen({required this.page});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(page.title)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          SelectableText(page.body, style: const TextStyle(fontSize: 15.5, height: 1.8)),
        ]),
      );
}
