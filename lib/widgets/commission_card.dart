import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../screens/dues_screen.dart';
import '../services/finance_service.dart';

/// عمولة المنصة المستحقة داخل المحفظة. عند بلوغ الحد الأقصى يتوقف استقبال الرحلات ويظهر زر «تحويل أموال»
/// الذي يعرض أرقام التحويل المضافة من لوحة التحكم.
class CommissionCard extends StatefulWidget {
  const CommissionCard({super.key});
  @override
  State<CommissionCard> createState() => CommissionCardState();
}

class CommissionCardState extends State<CommissionCard> {
  DriverFinance? _f;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await FinanceService.sync();
      final f = await FinanceService.load();
      if (mounted) setState(() => _f = f);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    if (f == null) return const SizedBox.shrink();
    final c = f.blocked ? const Color(0xFFD32F2F) : (f.near ? const Color(0xFFB36B00) : Theme.of(context).colorScheme.primary);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(16), border: Border.all(color: c)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(f.blocked ? Icons.lock_outline : Icons.account_balance_wallet_outlined, color: c),
          const SizedBox(width: 8),
          Text('عمولة المنصة المستحقة', style: TextStyle(fontWeight: FontWeight.w900, color: c)),
          const Spacer(),
          Text(money(f.due), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        if (f.max > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: f.ratio, minHeight: 7, borderRadius: BorderRadius.circular(8), color: c),
          const SizedBox(height: 4),
          Text('الحد الأقصى ${money(f.max)}', style: const TextStyle(fontSize: 12)),
        ],
        if (f.blocked) ...[
          const SizedBox(height: 8),
          const Text('تم إيقاف استقبال الرحلات لبلوغ الحد الأقصى. حوّل المبلغ المستحق ثم يؤكد المسؤول الاستلام ليعود الاستقبال.', style: TextStyle(height: 1.5)),
        ],
        if (f.due > 0) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const DuesScreen()));
                _load();
              },
              icon: const Icon(Icons.send_to_mobile),
              label: const Text('تحويل أموال'),
            ),
          ),
        ],
      ]),
    );
  }
}
