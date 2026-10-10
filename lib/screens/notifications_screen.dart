import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  Map<String, Map<String, dynamic>> _mine = {};
  List<Map<String, dynamic>> _broadcasts = [];
  bool _loaded = false;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _subs.add(_db.child('notifications/$_uid').onValue.listen((e) {
      if (!mounted) return;
      setState(() {
        _mine = asMap(e.snapshot.value).map((k, v) => MapEntry(k, asMap(v)));
        _loaded = true;
      });
    }, onError: (_) => setState(() => _loaded = true)));
    _subs.add(_db.child('broadcasts').onValue.listen((e) {
      if (!mounted) return;
      setState(() => _broadcasts = asMap(e.snapshot.value)
          .values
          .map((v) => asMap(v))
          .where((m) => m['audience'] == 'all' || m['audience'] == 'riders')
          .toList());
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _readAll() async {
    final up = <String, Object?>{};
    _mine.forEach((k, v) {
      if (v['read'] != true) up['notifications/$_uid/$k/read'] = true;
    });
    if (up.isNotEmpty) await _db.update(up);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ..._mine.values.map((m) => {...m, '_p': true}),
      ..._broadcasts,
    ]..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات'), actions: [
        TextButton(onPressed: _readAll, child: const Text('تحديد الكل كمقروء')),
      ]),
      body: !_loaded
          ? const LoadingView()
          : items.isEmpty
              ? const EmptyView('لا توجد إشعارات', icon: Icons.notifications_none)
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    final unread = n['_p'] == true && n['read'] != true;
                    return ListTile(
                      leading: Icon(unread ? Icons.circle : Icons.circle_outlined, size: 12),
                      title: Text((n['title'] ?? '').toString()),
                      subtitle: Text('${n['body'] ?? n['message'] ?? ''}\n${timeAgo((n['createdAt'] as num?)?.toInt())}'),
                      isThreeLine: true,
                    );
                  },
                ),
    );
  }
}
