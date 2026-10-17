import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/utils.dart';

/// قسم «السلامة والدعم»: الاسم والصورة والمحتوى وأرقام الدعم تُدار من لوحة التحكم
/// (settings/safetySupport/{role}) ويظهر دون تحديث APK.
class SafetySupportData {
  final String title, body, imageUrl;
  final List<Map<String, String>> contacts;
  const SafetySupportData({required this.title, required this.body, required this.imageUrl, required this.contacts});
  static Future<SafetySupportData?> load() async {
    try {
      final v = asMap((await FirebaseDatabase.instance.ref('settings/safetySupport/${AppConfig.role}').get()).value);
      if (v.isEmpty || v['active'] == false) return null;
      final title = (v['title'] ?? '').toString().trim();
      if (title.isEmpty) return null;
      final raw = v['contacts'];
      final vals = raw is Map ? raw.values.toList() : raw is List ? raw : const [];
      final contacts = <Map<String, String>>[
        for (final c in vals)
          if (c is Map && (c['phone'] ?? c['url'] ?? '').toString().trim().isNotEmpty)
            {'title': (c['title'] ?? '').toString(), 'phone': (c['phone'] ?? '').toString().trim(), 'url': (c['url'] ?? '').toString().trim()},
      ];
      return SafetySupportData(title: title, body: (v['body'] ?? '').toString(), imageUrl: (v['imageUrl'] ?? '').toString(), contacts: contacts);
    } catch (_) {
      return null;
    }
  }
}

class SafetySupportScreen extends StatelessWidget {
  final SafetySupportData data;
  const SafetySupportScreen({super.key, required this.data});

  Future<void> _open(Map<String, String> c) async {
    final phone = c['phone'] ?? '', url = c['url'] ?? '';
    final uri = phone.isNotEmpty ? Uri(scheme: 'tel', path: phone) : Uri.tryParse(url);
    if (uri != null && (phone.isNotEmpty || url.startsWith('https://'))) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text(data.title)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (data.imageUrl.startsWith('https://'))
              ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(data.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            if (data.body.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(data.body, style: const TextStyle(height: 1.7, fontSize: 15))),
            for (final c in data.contacts)
              Card(
                child: ListTile(
                  leading: Icon((c['phone'] ?? '').isNotEmpty ? Icons.call : Icons.link),
                  title: Text((c['title'] ?? '').isEmpty ? (c['phone'] ?? c['url'] ?? '') : c['title']!),
                  subtitle: (c['phone'] ?? '').isNotEmpty ? Text(c['phone']!, textDirection: TextDirection.ltr) : null,
                  onTap: () => _open(c),
                ),
              ),
          ]),
        ),
      );
}
