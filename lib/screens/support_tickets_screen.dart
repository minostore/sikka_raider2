import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'ticket_chat_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  final String role;
  const SupportTicketsScreen({super.key, required this.role});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _db = FirebaseDatabase.instance.ref();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _newTicket() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final category = ValueNotifier<String>('general');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تذكرة دعم جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: category,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  value: v,
                  decoration: const InputDecoration(labelText: 'نوع المشكلة'),
                  items: const [
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('استفسار عام'),
                    ),
                    DropdownMenuItem(value: 'ride', child: Text('مشكلة رحلة')),
                    DropdownMenuItem(
                      value: 'payment',
                      child: Text('مشكلة مالية'),
                    ),
                    DropdownMenuItem(
                      value: 'account',
                      child: Text('الحساب أو المستندات'),
                    ),
                  ],
                  onChanged: (x) {
                    if (x != null) category.value = x;
                  },
                ),
              ),
              TextField(
                controller: title,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'عنوان المشكلة'),
              ),
              TextField(
                controller: body,
                maxLines: 4,
                maxLength: 1500,
                decoration: const InputDecoration(labelText: 'اشرح المشكلة'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (ok != true ||
        _uid == null ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      title.dispose();
      body.dispose();
      category.dispose();
      return;
    }
    final id = _db.child('tickets').push().key!;
    final now = ServerValue.timestamp;
    try {
      await _db.update({
        'tickets/$id': {
          'uid': _uid,
          'role': widget.role,
          'ticketNumber': id.substring(id.length - 8).toUpperCase(),
          'title': title.text.trim(),
          'category': category.value,
          'status': 'open',
          'priority': 'medium',
          'createdAt': now,
          'updatedAt': now,
          'messages': {
            'm1': {
              'from': widget.role == 'driver' ? 'driver' : 'user',
              'uid': _uid,
              'text': body.text.trim(),
              'createdAt': now,
            },
          },
        },
        'userTickets/${_uid}/$id': true,
      });
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketChatScreen(ticketId: id, role: widget.role),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر إرسال التذكرة: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
    } finally {
      title.dispose();
      body.dispose();
      category.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null)
      return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً')));
    return Scaffold(
      appBar: AppBar(title: const Text('الدعم الفني')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTicket,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('تذكرة جديدة'),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _db.child('userTickets/$uid').onValue,
        builder: (context, indexSnap) {
          if (indexSnap.hasError)
            return const Center(child: Text('تعذر تحميل التذاكر'));
          if (!indexSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          final ids = <String>[];
          final raw = indexSnap.data!.snapshot.value;
          if (raw is Map) ids.addAll(raw.keys.map((e) => e.toString()));
          if (ids.isEmpty)
            return const Center(child: Text('لا توجد تذاكر دعم حتى الآن'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ids.length,
            itemBuilder: (context, i) {
              final id = ids[ids.length - 1 - i];
              return StreamBuilder<DatabaseEvent>(
                stream: _db.child('tickets/$id').onValue,
                builder: (context, ticketSnap) {
                  final t = ticketSnap.data?.snapshot.value;
                  if (t is! Map) return const SizedBox.shrink();
                  final ticket = Map<String, dynamic>.from(t);
                  final status = (ticket['status'] ?? 'open').toString();
                  final statusLabel =
                      {
                        'open': 'مفتوحة',
                        'pending': 'قيد المعالجة',
                        'resolved': 'تم الحل',
                        'escalated': 'للإدارة العامة',
                        'closed': 'مغلقة',
                      }[status] ??
                      status;
                  final messages = ticket['messages'] is Map
                      ? (ticket['messages'] as Map).length
                      : 0;
                  return Card(
                    color: AppColors.card,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1AFFCC00),
                        child: Icon(
                          Icons.forum_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        (ticket['title'] ?? 'تذكرة دعم').toString(),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'تذكرة #${ticket['ticketNumber'] ?? id.substring(id.length - 8).toUpperCase()} • $statusLabel • $messages رسالة',
                        style: const TextStyle(color: Color(0xFFA9B4C2)),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left,
                        color: AppColors.ink,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TicketChatScreen(ticketId: id, role: widget.role),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
