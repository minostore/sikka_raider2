import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../services/ticket_attachment_service.dart';

class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String role;
  const TicketChatScreen({
    super.key,
    required this.ticketId,
    required this.role,
  });
  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _input = TextEditingController();
  final _ratingComment = TextEditingController();
  bool _sending = false;
  int _stars = 5;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _send({Map<String, dynamic>? attachment}) async {
    final text = _input.text.trim();
    final uid = _uid;
    if ((text.isEmpty && attachment == null) || uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      final snapshot = await _db.child('tickets/${widget.ticketId}').get();
      if (!snapshot.exists || snapshot.value is! Map)
        throw Exception('التذكرة غير موجودة');
      final ticket = Map<String, dynamic>.from(snapshot.value as Map);
      if (ticket['uid']?.toString() != uid)
        throw Exception('غير مسموح بفتح هذه التذكرة');
      if (['closed', 'resolved', 'escalated'].contains(ticket['status']))
        throw Exception('التذكرة مغلقة؛ لا يمكن إضافة رد جديد');
      await _db.child('tickets/${widget.ticketId}/messages').push().set({
        'from': widget.role == 'driver' ? 'driver' : 'user',
        'uid': uid,
        'text': text,
        if (attachment != null) 'attachment': attachment,
        'createdAt': ServerValue.timestamp,
      });
      await _db
          .child('tickets/${widget.ticketId}/updatedAt')
          .set(ServerValue.timestamp);
      _input.clear();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(error, fallback: 'تعذر إرسال الرسالة')),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final uid = _uid;
    if (uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      final attachment = await TicketAttachmentService.pickAndUpload(
        uid: uid,
        ticketId: widget.ticketId,
      );
      if (attachment == null || !mounted) {
        if (mounted) setState(() => _sending = false);
        return;
      }
      setState(() => _sending = false);
      await _send(attachment: attachment);
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(error, fallback: 'تعذر رفع الملف')),
          ),
        );
      }
    }
  }

  Future<void> _rate() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final ref = _db.child('tickets/${widget.ticketId}/rating');
      final result = await ref.runTransaction((value) {
        if (value != null) return Transaction.abort();
        return Transaction.success({
          'uid': uid,
          'stars': _stars,
          'comment': _ratingComment.text.trim(),
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      });
      if (!result.committed && mounted)
        throw Exception('تم إرسال تقييم لهذه التذكرة مسبقاً.');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكراً لك، تم حفظ تقييمك.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, fallback: 'تعذر حفظ التقييم')),
          ),
        );
    }
  }

  Future<void> _openImage(String path, String? directUrl) async {
    try {
      final url =
          directUrl ??
          await FirebaseStorage.instance.ref(path).getDownloadURL();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('تعذر عرض الصورة'),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل معاينة الملف')),
        );
    }
  }

  Future<void> _openFile(String path, String? directUrl) async {
    try {
      final url =
          directUrl ??
          await FirebaseStorage.instance.ref(path).getDownloadURL();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر فتح الملف')));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _ratingComment.dispose();
    super.dispose();
  }

  Widget _attachment(Map<String, dynamic> message) {
    final a = message['attachment'];
    if (a is! Map || a['storagePath'] == null) return const SizedBox.shrink();
    final path = a['storagePath'].toString();
    final mime = (a['contentType'] ?? '').toString();
    final name = (a['name'] ?? 'ملف مرفق').toString();
    final candidateUrl = a['downloadUrl']?.toString();
    final directUrl =
        candidateUrl != null &&
            candidateUrl.startsWith('https://firebasestorage.googleapis.com/')
        ? candidateUrl
        : null;
    if (mime.startsWith('image/')) {
      return FutureBuilder<String>(
        future: directUrl != null
            ? Future<String>.value(directUrl)
            : FirebaseStorage.instance.ref(path).getDownloadURL(),
        builder: (context, snap) => snap.hasData
            ? GestureDetector(
                onTap: () => _openImage(path, directUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    snap.data!,
                    width: 220,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 48),
                  ),
                ),
              )
            : Container(
                width: 200,
                height: 72,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
      );
    }
    return TextButton.icon(
      onPressed: () => _openFile(path, directUrl),
      icon: const Icon(Icons.description_outlined),
      label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _ratingPanel(Map<String, dynamic> ticket) {
    final saved = ticket['rating'];
    if (saved is Map) {
      final stars = (saved['stars'] as num?)?.toInt() ?? 0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: AppColors.field,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تقييمك لخدمة الدعم',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${'★' * stars}${'☆' * (5 - stars)}',
              style: const TextStyle(color: AppColors.orange, fontSize: 22),
            ),
            if ((saved['comment'] ?? '').toString().isNotEmpty)
              Text(
                saved['comment'].toString(),
                style: const TextStyle(color: AppColors.ink),
              ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      color: AppColors.field,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'قيّم تجربتك مع خدمة الدعم',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star : Icons.star_border,
                    color: AppColors.orange,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _ratingComment,
            maxLength: 250,
            decoration: const InputDecoration(
              hintText: 'تعليق اختياري',
              counterText: '',
              isDense: true,
            ),
          ),
          TextButton.icon(
            onPressed: _rate,
            icon: const Icon(Icons.send),
            label: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    final ticketStream = _db.child('tickets/${widget.ticketId}').onValue;
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DatabaseEvent>(
          stream: ticketStream,
          builder: (context, snapshot) {
            final value = snapshot.data?.snapshot.value;
            final ticket = value is Map
                ? Map<String, dynamic>.from(value)
                : <String, dynamic>{};
            final status = (ticket['status'] ?? 'open').toString();
            final label =
                {
                  'open': 'مفتوحة',
                  'pending': 'قيد المعالجة',
                  'resolved': 'تم الحل',
                  'escalated': 'للإدارة العامة',
                  'closed': 'مغلقة',
                }[status] ??
                status;
            final no =
                (ticket['ticketNumber'] ??
                        widget.ticketId.substring(
                          widget.ticketId.length > 8
                              ? widget.ticketId.length - 8
                              : 0,
                        ))
                    .toString();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('تذكرة #$no', style: const TextStyle(fontSize: 15)),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA9B4C2),
                  ),
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
                if (snapshot.hasError)
                  return const Center(child: Text('تعذر تحميل المحادثة'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final raw = snapshot.data!.snapshot.value;
                final messages = <Map<String, dynamic>>[];
                if (raw is Map)
                  for (final v in raw.values) {
                    if (v is Map) messages.add(Map<String, dynamic>.from(v));
                  }
                messages.sort(
                  (a, b) => ((a['createdAt'] as num?) ?? 0).compareTo(
                    (b['createdAt'] as num?) ?? 0,
                  ),
                );
                if (messages.isEmpty)
                  return const Center(
                    child: Text('ابدأ المحادثة مع خدمة العملاء'),
                  );
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final m in messages)
                      Align(
                        alignment: m['uid']?.toString() == uid
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: m['from'] == 'admin'
                                ? const Color(0xFF3A2F0C)
                                : AppColors.field,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m['from'] == 'admin')
                                const Text(
                                  'خدمة العملاء',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink,
                                  ),
                                ),
                              if ((m['text'] ?? '').toString().isNotEmpty)
                                Text(
                                  (m['text']).toString(),
                                  style: const TextStyle(color: AppColors.ink),
                                ),
                              _attachment(m),
                              Text(
                                m['createdAt'] is num
                                    ? DateTime.fromMillisecondsSinceEpoch(
                                        (m['createdAt'] as num).toInt(),
                                      ).toLocal().toString().substring(11, 16)
                                    : '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFA9B4C2),
                                ),
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
          StreamBuilder<DatabaseEvent>(
            stream: ticketStream,
            builder: (context, snapshot) {
              final raw = snapshot.data?.snapshot.value;
              final ticket = raw is Map
                  ? Map<String, dynamic>.from(raw)
                  : <String, dynamic>{};
              final status = (ticket['status'] ?? 'open').toString();
              if (['closed', 'resolved'].contains(status))
                return _ratingPanel(ticket);
              if (['escalated'].contains(status))
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('تمت إحالة التذكرة للإدارة العامة.'),
                );
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _sending ? null : _attach,
                        tooltip: 'إرفاق صورة أو مستند',
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.attach_file,
                                color: AppColors.ink,
                              ),
                      ),
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
                        onPressed: _sending ? null : () => _send(),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
