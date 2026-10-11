import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/driver_service.dart';
import '../widgets/common.dart';

class RatingsScreen extends StatelessWidget {
  const RatingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقييمات')),
        body: FutureBuilder<({double avg, int count, List<Map<String, dynamic>> list})>(
          future: DriverService.ratings(),
          builder: (c, s) {
            if (!s.hasData) return const LoadingView();
            final v = s.data!;
            final dist = List.generate(5, (i) {
              final star = 5 - i;
              final n = v.list.where((x) => numD(x['stars']).round() == star).length;
              return (star, v.count == 0 ? 0 : (n * 100 / v.count).round());
            });
            return ListView(padding: const EdgeInsets.all(16), children: [
              InfoCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(v.count == 0 ? '—' : v.avg.toStringAsFixed(1), style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 1; i <= 5; i++) Icon(i <= v.avg.round() ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.orange, size: 30)]),
                  Text('(${v.count}) تقييم', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  for (final d in dist)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(width: 18, child: Text('${d.$1}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: d.$2 / 100, minHeight: 8, backgroundColor: const Color(0xFFE6ECF0), color: AppColors.green))),
                        SizedBox(width: 44, child: Text('${d.$2}%', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, color: Colors.grey))),
                      ]),
                    ),
                  if (v.list.any((x) => (x['comment'] ?? '').toString().isNotEmpty)) ...[
                    const Divider(height: 28),
                    for (final x in v.list.where((x) => (x['comment'] ?? '').toString().isNotEmpty).take(8)) ListTile(dense: true, leading: Text('★ ${numD(x['stars']).toInt()}', style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)), title: Text(x['comment'].toString())),
                  ],
                ]),
              ),
            ]);
          },
        ),
      );
}
