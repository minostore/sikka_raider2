import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';
import '../core/theme.dart';

class AppUpdateBanner extends StatelessWidget {
  final String role;
  const AppUpdateBanner({super.key, required this.role});

  int _compare(String a, String b) {
    List<int> parse(String s) => s
        .split(RegExp(r'[^0-9]+'))
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final xv = i < x.length ? x[i] : 0, yv = i < y.length ? y[i] : 0;
      if (xv != yv) return xv.compareTo(yv);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: FirebaseDatabase.instance.ref('appUpdates').onValue,
    builder: (context, snapshot) {
      if (snapshot.hasError || !snapshot.hasData)
        return const SizedBox.shrink();
      final raw = snapshot.data!.snapshot.value;
      if (raw is! Map) return const SizedBox.shrink();
      final items = <Map<String, dynamic>>[];
      raw.forEach((id, value) {
        if (value is Map) {
          final item = Map<String, dynamic>.from(value);
          final target = (item['target'] ?? '').toString();
          if (item['active'] == true && (target == role || target == 'both'))
            items.add({...item, '_id': id.toString()});
        }
      });
      items.sort(
        (a, b) => ((b['createdAt'] as num?) ?? 0).compareTo(
          (a['createdAt'] as num?) ?? 0,
        ),
      );
      if (items.isEmpty) return const SizedBox.shrink();
      final update = items.first;
      final version = (update['version'] ?? '').toString();
      if (version.isEmpty || _compare(version, AppVersion.current) <= 0)
        return const SizedBox.shrink();
      final title = (update['title'] ?? 'تحديث جديد متاح').toString();
      final message = (update['message'] ?? '').toString();
      final url = (update['downloadUrl'] ?? '').toString();
      return Card(
        elevation: 3,
        color: AppColors.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.system_update_alt, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$title • $version',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (message.isNotEmpty)
                      Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA9B4C2),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: url.isEmpty
                    ? null
                    : () async {
                        final uri = Uri.tryParse(url);
                        if (uri == null ||
                            !await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            )) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر فتح رابط التحديث'),
                              ),
                            );
                        }
                      },
                child: const Text('تنزيل'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
