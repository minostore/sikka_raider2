import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../core/utils.dart';
import '../services/finance_service.dart';

/// العمولة المستحقة للمنصة، الحد الأقصى، وطرق السداد. التأكيد النهائي يتم من لوحة التحكم فقط.
class DuesScreen extends StatefulWidget {
  const DuesScreen({super.key});
  @override
  State<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends State<DuesScreen> {
  DriverFinance? _f;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; });
    try {
      await FinanceService.sync();
      final f = await FinanceService.load();
      if (mounted) setState(() => _f = f);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحويل أموال')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _error != null
              ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('تعذر التحميل: $_error', textAlign: TextAlign.center))])
              : f == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      if (f.blocked)
                        _banner(Icons.block, const Color(0xFFD32F2F), 'استقبال الرحلات متوقف',
                            'بلغت العمولة المستحقة الحد الأقصى. يمكنك إكمال أي رحلة جارية، وسدّد المبلغ ثم يؤكد المسؤول استلامه ليعود الاستقبال.')
                      else if (f.near)
                        _banner(Icons.warning_amber_rounded, const Color(0xFFB36B00), 'اقتربت من الحد الأقصى', 'سدّد قريبًا لتفادي إيقاف استقبال الرحلات.'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('المستحق للمنصة', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(money(f.due), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          if (f.max > 0) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: f.ratio, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                            const SizedBox(height: 6),
                            Text('الحد الأقصى المسموح: ${money(f.max)}'),
                          ],
                          const SizedBox(height: 6),
                          Text('نسبة عمولة المنصة الحالية: ${f.percent.toStringAsFixed(f.percent % 1 == 0 ? 0 : 1)}%', style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      const Text('طرق السداد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 6),
                      if (f.methods.isEmpty) const Text('لم تُضف الإدارة أرقام تحويل بعد. تواصل مع الدعم.'),
                      for (final m in f.methods)
                        Card(
                          child: ListTile(
                            title: Text((m['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${m['phone'] ?? ''}${(m['beneficiary'] ?? '').toString().isEmpty ? '' : '\nالمستفيد: ${m['beneficiary']}'}', textDirection: TextDirection.ltr),
                            isThreeLine: (m['beneficiary'] ?? '').toString().isNotEmpty,
                            trailing: ElevatedButton(
                              onPressed: f.due > 0
                                  ? () async {
                                      await Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(method: m, due: f.due)));
                                      _load();
                                    }
                                  : null,
                              child: const Text('تحويل'),
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('اضغط «تحويل» بجانب الرقم الذي ستحوّل عليه، ثم أدخل الرقم الذي حوّلت منه وارفع لقطة الإثبات. لا يُخصم المبلغ ولا يعود الاستقبال إلا بعد تأكيد المسؤول للاستلام.', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 8),
                      if (f.requests.isNotEmpty) ...[
                        const Text('طلبات التحويل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        for (final q in f.requests)
                          ListTile(
                            dense: true,
                            leading: Icon(q['status'] == 'confirmed' ? Icons.check_circle : q['status'] == 'rejected' ? Icons.cancel : Icons.hourglass_top, color: q['status'] == 'confirmed' ? Colors.green : q['status'] == 'rejected' ? Colors.red : Colors.orange),
                            title: Text(money((q['amount'] as num?)?.toDouble() ?? 0)),
                            subtitle: Text(q['status'] == 'confirmed' ? 'تم تأكيد الاستلام' : q['status'] == 'rejected' ? 'مرفوض${(q['reason'] ?? '').toString().isEmpty ? '' : ': ${q['reason']}'}' : 'بانتظار تأكيد المسؤول'),
                          ),
                        const SizedBox(height: 8),
                      ],
                      const Text('السجل المالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      if (f.tx.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد عمليات بعد.')),
                      for (final t in f.tx)
                        ListTile(
                          dense: true,
                          leading: Icon(t['type'] == 'payment' ? Icons.south_west : Icons.north_east, color: t['type'] == 'payment' ? Colors.green : Colors.orange),
                          title: Text(t['type'] == 'payment' ? 'سداد مؤكد' : 'عمولة رحلة'),
                          subtitle: Text(_fmt(t['createdAt'])),
                          trailing: Text('${t['type'] == 'payment' ? '-' : '+'}${money((t['amount'] as num?)?.toDouble() ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                    ]),
        ),
      ),
    );
  }

  String _fmt(dynamic ms) {
    if (ms is! num) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _banner(IconData icon, Color c, String title, String body) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: c),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: c)), const SizedBox(height: 3), Text(body)])),
        ]),
      );
}


/// شاشة التحويل: تعرض الرقم المحوَّل عليه، وتطلب المبلغ والرقم المحوَّل منه ولقطة إثبات الدفع.
class TransferScreen extends StatefulWidget {
  final Map<String, dynamic> method;
  final double due;
  const TransferScreen({super.key, required this.method, required this.due});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  late final TextEditingController _amount = TextEditingController(text: widget.due.toStringAsFixed(widget.due % 1 == 0 ? 0 : 2));
  final _from = TextEditingController();
  File? _proof;
  bool _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    _from.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
    if (x != null && mounted) setState(() => _proof = File(x.path));
  }

  Future<void> _send() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return showSnack(context, 'أدخل المبلغ الذي حوّلته', error: true);
    if (amount > widget.due + 0.001) return showSnack(context, 'المبلغ أكبر من العمولة المستحقة (${money(widget.due)})', error: true);
    if (_from.text.trim().length < 8) return showSnack(context, 'أدخل الرقم الذي حوّلت منه', error: true);
    if (_proof == null) return showSnack(context, 'ارفع لقطة شاشة إثبات الدفع', error: true);
    setState(() => _sending = true);
    try {
      final proof = await FinanceService.uploadProof(_proof!);
      await FinanceService.requestTransfer(
          amount: amount, fromNumber: _from.text.trim(), toNumber: (widget.method['phone'] ?? '').toString(), toName: (widget.method['name'] ?? '').toString(), proof: proof);
      if (!mounted) return;
      showSnack(context, 'تم إرسال الطلب. سيراجعه المسؤول ويؤكد الاستلام.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.method;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحويل أموال')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('حوّل المبلغ إلى هذا الرقم', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text((m['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SelectableText((m['phone'] ?? '').toString(), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              if ((m['beneficiary'] ?? '').toString().isNotEmpty) Text('المستفيد: ${m['beneficiary']}'),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: (m['phone'] ?? '').toString()));
                  showSnack(context, 'تم نسخ الرقم');
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ الرقم'),
              ),
              Text('العمولة المستحقة: ${money(widget.due)}'),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ الذي حوّلته (ج.م)')),
          const SizedBox(height: 10),
          TextField(controller: _from, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الرقم الذي حوّلت منه')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pickProof,
            icon: const Icon(Icons.image_outlined),
            label: Text(_proof == null ? 'رفع لقطة شاشة إثبات التحويل' : 'تم اختيار اللقطة — اضغط للتغيير'),
          ),
          if (_proof != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_proof!, height: 180, fit: BoxFit.cover))),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _sending ? null : _send, icon: const Icon(Icons.send), label: Text(_sending ? 'جارٍ الإرسال…' : 'إرسال طلب التحويل'))),
        ]),
      ),
    );
  }
}
