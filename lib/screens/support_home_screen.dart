import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import 'safety_support_screen.dart';
import 'support_tickets_screen.dart';
import 'ticket_chat_screen.dart';

/// موضوع تواصل مع الدعم (يُعدَّل من لوحة التحكم ← محتوى التطبيق ← صفحة المساعدة والدعم).
class SupportTopic {
  final String id, title, description;
  const SupportTopic(this.id, this.title, this.description);
}

IconData _topicIcon(String id) {
  switch (id) {
    case 'trips':
      return Icons.route_outlined;
    case 'driver':
      return Icons.drive_eta_outlined;
    case 'rider':
      return Icons.person_outline;
    case 'profile':
      return Icons.manage_accounts_outlined;
    case 'lost':
      return Icons.help_outline;
    case 'fare':
      return Icons.attach_money;
    case 'driver_issues':
      return Icons.person_off_outlined;
    case 'payment':
      return Icons.payments_outlined;
    case 'account':
      return Icons.person_outline;
    case 'safety':
      return Icons.health_and_safety_outlined;
    case 'about':
      return Icons.info_outline;
    case 'messages':
      return Icons.forum_outlined;
    case 'lost':
      return Icons.luggage_outlined;
    default:
      return Icons.help_outline;
  }
}

List<SupportTopic> _defaultTopics(String role) => role == 'driver'
    ? const [
        SupportTopic('trips', 'الرحلات والأرباح', 'استفسار أو مشكلة تخص رحلة أو أرباح.'),
        SupportTopic('fare', 'راجع أجرة رحلتي', 'اعتراض أو استفسار عن أجرة رحلة محددة.'),
        SupportTopic('lost', 'الأغراض المفقودة', 'عميل ينسى غرضًا في سيارتك؟ بلّغنا للتنسيق.'),
        SupportTopic('payment', 'المحفظة والدفع', 'شحن الرصيد، العمولة أو مشاكل الدفع.'),
        SupportTopic('account', 'الحساب والمستندات', 'تعديل الملف الشخصي أو المستندات وبيانات المركبة.'),
        SupportTopic('safety', 'السلامة والطوارئ', 'بلاغ أو مشكلة تخص سلامتك أثناء الرحلة.'),
        SupportTopic('about', 'عن سكة وتطبيقها', 'كيف يعمل التطبيق والأسئلة العامة.'),
        SupportTopic('messages', 'سجل الرسائل', 'مراجعة رسائلك ومحادثاتك مع الدعم.'),
      ]
    : const [
        SupportTopic('lost', 'الأغراض المفقودة', 'نسيت شيئًا في السيارة؟ بلّغنا وسنتواصل مع السائق.'),
        SupportTopic('fare', 'راجع أجرة رحلتي', 'اعتراض أو استفسار عن أجرة رحلة محددة.'),
        SupportTopic('driver_issues', 'المشاكل التي يسببها السائق', 'سلوك، تأخير، تغيير المسار أو أي شكوى من سائق.'),
        SupportTopic('payment', 'الدفع', 'مشاكل المحفظة أو الدفع أو الشحن.'),
        SupportTopic('account', 'الحساب', 'تعديل البيانات أو مشاكل تسجيل الدخول.'),
        SupportTopic('safety', 'السلامة والطوارئ', 'أدوات السلامة، جهات الاتصال الموثوقة وبلاغات الطوارئ.'),
        SupportTopic('about', 'عن سكة وتطبيقها', 'كيف يعمل التطبيق والأسئلة العامة.'),
        SupportTopic('messages', 'سجل الرسائل', 'مراجعة رسائلك ومحادثاتك مع الدعم والسائقين.'),
      ];

/// صفحة «المساعدة والدعم» كاملة: اختر سبب التواصل ثم اكتب رسالتك.
class SupportHomeScreen extends StatefulWidget {
  final String role; // rider | driver
  const SupportHomeScreen({super.key, required this.role});
  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  String _q = '';
  late final Future<({String title, String intro, List<SupportTopic> topics})> _f = _load();

  Future<({String title, String intro, List<SupportTopic> topics})> _load() async {
    var title = 'المساعدة والدعم';
    var intro = 'اختر سبب تواصلك وسنرد عليك في أقرب وقت.';
    var topics = _defaultTopics(widget.role);
    try {
      final key = widget.role == 'driver' ? 'driver' : 'rider';
      final v = asMap((await FirebaseDatabase.instance.ref('settings/supportPage/$key').get()).value);
      if ((v['title'] ?? '').toString().trim().isNotEmpty) title = v['title'].toString().trim();
      if ((v['intro'] ?? '').toString().trim().isNotEmpty) intro = v['intro'].toString().trim();
      final raw = v['topics'];
      final entries = <MapEntry<String, Map<String, dynamic>>>[];
      if (raw is Map) {
        raw.forEach((k, t) {
          if (t is Map) entries.add(MapEntry(k.toString(), Map<String, dynamic>.from(t)));
        });
      } else if (raw is List) {
        for (var i = 0; i < raw.length; i++) {
          if (raw[i] is Map) entries.add(MapEntry('$i', Map<String, dynamic>.from(raw[i] as Map)));
        }
      }
      final list = entries.where((e) => e.value['active'] != false && (e.value['title'] ?? '').toString().trim().isNotEmpty).toList()
        ..sort((a, b) => ((a.value['order'] as num?) ?? 0).compareTo((b.value['order'] as num?) ?? 0));
      if (list.isNotEmpty) {
        topics = [for (final e in list) SupportTopic(e.key, e.value['title'].toString().trim(), (e.value['description'] ?? '').toString().trim())];
      }
    } catch (_) {}
    return (title: title, intro: intro, topics: topics);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<({String title, String intro, List<SupportTopic> topics})>(
        future: _f,
        builder: (context, snap) {
          final d = snap.data;
          return Scaffold(
            appBar: AppBar(title: Text(d?.title ?? 'المساعدة والدعم')),
            body: d == null
                ? const LoadingView()
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(d.intro, style: const TextStyle(color: Colors.grey, height: 1.5)),
                    FutureBuilder<SafetySupportData?>(
                      future: SafetySupportData.load(),
                      builder: (c, sn) {
                        final x = sn.data;
                        if (x == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Card(
                            child: ListTile(
                              leading: x.imageUrl.startsWith('https://')
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(x.imageUrl, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.health_and_safety_outlined)))
                                  : const Icon(Icons.health_and_safety_outlined),
                              title: Text(x.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => SafetySupportScreen(data: x))),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: const InputDecoration(hintText: 'ابحث في مقالات المساعدة', prefixIcon: Icon(Icons.search)),
                    ),
                    const SizedBox(height: 14),
                    for (final t in d.topics.where((t) => _q.isEmpty || t.title.contains(_q) || t.description.contains(_q)))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => _NewTicketScreen(role: widget.role, topic: t))),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.card, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Icon(_topicIcon(t.id), color: AppColors.primary, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  if (t.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(t.description, style: const TextStyle(color: Colors.grey, fontSize: 12.5))),
                                ]),
                              ),
                              const Icon(Icons.chevron_left),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportTicketsScreen(role: widget.role))),
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('سجل الرسائل'),
                    ),
                  ]),
          );
        },
      );
}

class _NewTicketScreen extends StatefulWidget {
  final String role;
  final SupportTopic topic;
  const _NewTicketScreen({required this.role, required this.topic});
  @override
  State<_NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<_NewTicketScreen> {
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final text = _body.text.trim();
    if (uid == null) return;
    if (text.length < 5) return showSnack(context, 'اكتب تفاصيل رسالتك', error: true);
    setState(() => _busy = true);
    final db = FirebaseDatabase.instance.ref();
    final id = db.child('tickets').push().key!;
    final now = ServerValue.timestamp;
    try {
      await db.update({
        'tickets/$id': {
          'uid': uid,
          'role': widget.role,
          'ticketNumber': id.substring(id.length - 8).toUpperCase(),
          'title': widget.topic.title,
          'category': widget.topic.id,
          'status': 'open',
          'priority': 'medium',
          'createdAt': now,
          'updatedAt': now,
          'messages': {
            'm1': {'from': widget.role == 'driver' ? 'driver' : 'user', 'uid': uid, 'text': text, 'createdAt': now},
          },
        },
        'userTickets/$uid/$id': true,
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: id, role: widget.role)));
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر إرسال الرسالة'), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.topic.title)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.topic.description.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(widget.topic.description, style: const TextStyle(color: Colors.grey))),
          TextField(controller: _body, maxLines: 8, maxLength: 1500, decoration: const InputDecoration(hintText: 'اشرح مشكلتك أو استفسارك بالتفصيل')),
          const SizedBox(height: 12),
          AppButton('إرسال', onPressed: _send, busy: _busy),
        ]),
      );
}
