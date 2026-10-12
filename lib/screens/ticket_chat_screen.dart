import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/utils.dart';

class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String role;

  const TicketChatScreen({super.key, required this.ticketId, required this.role});

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _input = TextEditingController();
  bool _sending = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _send() async {
    final text = _input.text.trim();
    final uid = _uid;
    if (text.isEmpty || uid == null || _sending) return;

    setState(() => _sending = true);
    try {
      final snapshot = await _db.child('tickets/${widget.ticketId}').get();
      if (!snapshot.exists || snapshot.value is! Map) {
        throw Exception('التذكرة غير موجودة');
      }
      final ticket = Map<String, dynamic>.from(snapshot.value as Map);
      if (ticket['uid']?.toString() != uid) {
        throw Exception('غير مسموح بفتح هذه التذكرة');
      }
      if (['closed', 'resolved', 'escalated'].contains(ticket['status'])) {
        throw Exception('التذكرة مغلقة أو أُحيلت للإدارة؛ لا يمكن إضافة رد جديد');
      }

      await _db.child('tickets/${widget.ticketId}/messages').push().set({
        'from': widget.role == 'driver' ? 'driver' : 'user',
        'uid': uid,
        'text': text,
        'createdAt': ServerValue.timestamp,
      });
      await _db.child('tickets/${widget.ticketId}/updatedAt').set(ServerValue.timestamp);
      _input.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(error, fallback: 'تعذر إرسال الرسالة'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketStream = _db.child('tickets/${widget.ticketId}').onValue;
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DatabaseEvent>(
          stream: ticketStream,
          builder: (context, snapshot) {
            final value = snapshot.data?.snapshot.value;
            final ticket = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
            final status = (ticket['status'] ?? 'open').toString();
            final label = {
              'open': 'مفتوحة',
              'pending': 'قيد المعالجة',
              'resolved': 'تم حل المشكلة',
              'escalated': 'أُحيلت للإدارة العامة',
              'closed': 'مغلقة',
            }[status] ?? status;
            final ticketNumber = (ticket['ticketNumber'] ?? widget.ticketId.substring(
              widget.ticketId.length > 8 ? widget.ticketId.length - 8 : 0,
            )).toString();
            final assigned = ticket['assignedName']?.toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تذكرة #$ticketNumber', style: const TextStyle(fontSize: 15)),
                Text(
                  '$label${assigned == null ? '' : ' • ممثل الدعم: $assigned'}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _db.child('tickets/${widget.ticketId}/messages').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل المحادثة'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw = snapshot.data!.snapshot.value;
                final messages = <Map<String, dynamic>>[];
                if (raw is Map) {
                  for (final value in raw.values) {
                    if (value is Map) messages.add(Map<String, dynamic>.from(value));
                  }
                }
                messages.sort((a, b) =>
                    ((a['createdAt'] as num?) ?? 0).compareTo((b['createdAt'] as num?) ?? 0));
                if (messages.isEmpty) {
                  return const Center(child: Text('ابدأ المحادثة مع خدمة العملاء'));
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final message in messages)
                      Align(
                        alignment: message['uid']?.toString() == _uid
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: message['from'] == 'admin'
                                ? const Color(0xFFE7F2FF)
                                : const Color(0xFFF0F1F3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message['from'] == 'admin')
                                const Text(
                                  'خدمة العملاء',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              Text((message['text'] ?? '').toString()),
                              Text(
                                message['createdAt'] is num
                                    ? DateTime.fromMillisecondsSinceEpoch(
                                        (message['createdAt'] as num).toInt(),
                                      ).toLocal().toString().substring(11, 16)
                                    : '',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: StreamBuilder<DatabaseEvent>(
                stream: _db.child('tickets/${widget.ticketId}/status').onValue,
                builder: (context, snapshot) {
                  final status = snapshot.data?.snapshot.value?.toString() ?? 'open';
                  if (['closed', 'resolved', 'escalated'].contains(status)) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('التذكرة مغلقة أو أُحيلت للإدارة؛ لا يمكن إضافة رد جديد.'),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLines: 4,
                          minLines: 1,
                          maxLength: 1000,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالتك...',
                            counterText: '',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
