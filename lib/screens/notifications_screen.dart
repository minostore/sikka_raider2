import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../core/theme.dart';
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
  Set<String> _hidden = {}; // حملات عامة أخفاها هذا المستخدم
  bool _loaded = false;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _subs.add(
      _db.child('notifications/$_uid').onValue.listen(
        (e) {
          if (!mounted) return;
          setState(() {
            _mine = asMap(e.snapshot.value).map((k, v) => MapEntry(k, {...asMap(v), '_id': k}));
            _loaded = true;
          });
        },
        onError: (_) {
          if (mounted) setState(() => _loaded = true);
        },
      ),
    );
    _subs.add(
      _db.child('broadcasts').onValue.listen((e) {
        if (!mounted) return;
        setState(
          () => _broadcasts = asMap(e.snapshot.value)
              .entries
              .map((en) => {...asMap(en.value), '_bid': en.key})
              .where((m) => (m['audience'] == 'all' || m['audience'] == 'drivers') && m['delivery'] != 'push')
              .toList(),
        );
      }, onError: (_) {}),
    );
    _subs.add(
      _db.child('hiddenBroadcasts/$_uid').onValue.listen((e) {
        if (!mounted) return;
        setState(() => _hidden = asMap(e.snapshot.value).keys.toSet());
      }, onError: (_) {}),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['_p'] != true || item['read'] == true) return;
    final id = (item['_id'] ?? '').toString();
    if (id.isEmpty) return;
    try {
      await _db.child('notifications/$_uid/$id/read').set(true);
    } catch (_) {
      _toast('تعذر تحديث الإشعار. حاول مرة أخرى.');
    }
  }

  Future<void> _readAll() async {
    final up = <String, Object?>{};
    _mine.forEach((k, v) {
      if (v['read'] != true) up['notifications/$_uid/$k/read'] = true;
    });
    if (up.isEmpty) return;
    try {
      await _db.update(up);
      _toast('تم تحديد الإشعارات كمقروءة');
    } catch (_) {
      _toast('تعذر تحديث الإشعارات. حاول مرة أخرى.');
    }
  }

  /// حذف إشعار واحد: الإشعار الشخصي يُحذف، والحملة العامة تُخفى عن هذا الحساب فقط.
  Future<void> _delete(Map<String, dynamic> n) async {
    try {
      if (n['_p'] == true) {
        await _db.child('notifications/$_uid/${n['_id']}').remove();
      } else {
        await _db.child('hiddenBroadcasts/$_uid/${n['_bid']}').set(true);
      }
    } catch (_) {
      _toast('تعذر حذف الإشعار. حاول مرة أخرى.');
    }
  }

  Future<void> _deleteAll(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    if (!await confirmDialog(context, 'حذف الإشعارات', 'هل تريد حذف كل الإشعارات؟')) return;
    final up = <String, Object?>{};
    for (final n in items) {
      if (n['_p'] == true) {
        up['notifications/$_uid/${n['_id']}'] = null;
      } else {
        up['hiddenBroadcasts/$_uid/${n['_bid']}'] = true;
      }
    }
    try {
      await _db.update(up);
    } catch (_) {
      _toast('تعذر حذف الإشعارات. حاول مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final personalCampaigns = _mine.values.map((m) => (m['campaignId'] ?? '').toString()).where((e) => e.isNotEmpty).toSet();
    final items = [
      ..._mine.values.where((m) => m['delivery'] != 'push').map((m) => {...m, '_p': true}),
      // الحملات التي وصلت كإشعار شخصي لا تُعرض مرتين
      ..._broadcasts.where((b) => !_hidden.contains(b['_bid']) && !personalCampaigns.contains(b['_bid'])),
    ]..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(onPressed: _readAll, child: const Text('تحديد الكل كمقروء')),
          IconButton(tooltip: 'حذف الكل', icon: const Icon(Icons.delete_sweep_outlined), onPressed: () => _deleteAll(items)),
        ],
      ),
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
                    final imageUrl = (n['imageUrl'] ?? '').toString();
                    final key = (n['_p'] == true ? 'p_${n['_id']}' : 'b_${n['_bid']}');
                    return Dismissible(
                      key: ValueKey(key),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        color: AppColors.red,
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: AppColors.red,
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(n),
                      child: Card(
                        color: unread ? const Color(0xFF221D10) : AppColors.card,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(unread ? Icons.circle : Icons.circle_outlined, size: 12, color: AppColors.ink),
                              title: Text((n['title'] ?? '').toString(), style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${n['body'] ?? n['message'] ?? ''}\n${timeAgo((n['createdAt'] as num?)?.toInt())}',
                                style: const TextStyle(color: Color(0xFFA9B4C2)),
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFA9B4C2)),
                                onPressed: () => _delete(n),
                              ),
                              onTap: () => _markRead(n),
                            ),
                            if (imageUrl.startsWith('https://'))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                child: GestureDetector(
                                  onTap: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain))),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(imageUrl, height: 170, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
