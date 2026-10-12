import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays the latest administrator-published update targeting this app.
class AppUpdateBanner extends StatelessWidget {
  final String role;
  const AppUpdateBanner({super.key, required this.role});

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('appUpdates').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError || !snapshot.hasData) return const SizedBox.shrink();
          final raw = snapshot.data!.snapshot.value;
          if (raw is! Map) return const SizedBox.shrink();
          final items = <Map<String, dynamic>>[];
          raw.forEach((id, value) {
            if (value is! Map) return;
            final item = Map<String, dynamic>.from(value);
            final target = (item['target'] ?? '').toString();
            if (item['active'] == true && (target == role || target == 'both')) {
              items.add({...item, '_id': id.toString()});
            }
          });
          if (items.isEmpty) return const SizedBox.shrink();
          items.sort((a, b) => ((b['createdAt'] as num?) ?? 0)
              .compareTo((a['createdAt'] as num?) ?? 0));
          final update = items.first;
          final version = (update['version'] ?? '').toString();
          final title = (update['title'] ?? 'تحديث جديد متاح').toString();
          final message = (update['message'] ?? '').toString();
          final url = (update['downloadUrl'] ?? '').toString();
          return Card(
            elevation: 5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(children: [
                const Icon(Icons.system_update_alt, color: Color(0xFF0A78FA)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(version.isEmpty ? title : '$title • $version', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (message.isNotEmpty) Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ])),
                TextButton(
                  onPressed: url.isEmpty ? null : () async {
                    final uri = Uri.tryParse(url);
                    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط التحديث')));
                    }
                  },
                  child: const Text('تنزيل'),
                ),
              ]),
            ),
          );
        },
      );
}
