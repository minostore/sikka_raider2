import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// Lightweight in-ride chat backed by Firebase Realtime Database.
class RideChatScreen extends StatefulWidget {
  final String rideId;
  const RideChatScreen({super.key, required this.rideId});

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _db = FirebaseDatabase.instance.ref();
  bool _sending = false;
  String? _error;
  String _myName = 'أنا';
  String _otherName = 'الطرف الآخر';
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final uid = _uid;
      if (uid == null) throw Exception('سجّل الدخول أولاً.');
      final snap = await _db.child('rides/${widget.rideId}').get();
      if (!snap.exists || snap.value is! Map) throw Exception('الرحلة غير موجودة.');
      final ride = Map<String, dynamic>.from(snap.value as Map);
      final riderId = (ride['riderId'] ?? '').toString();
      final driverId = (ride['driverId'] ?? '').toString();
      if (uid != riderId && uid != driverId) throw Exception('لا يمكنك فتح محادثة هذه الرحلة.');
      final isRider = uid == riderId;
      if (mounted) setState(() {
        _myName = (isRider ? ride['riderName'] : ride['driverName'])?.toString() ?? 'أنا';
        _otherName = (isRider ? ride['driverName'] : ride['riderName'])?.toString() ?? 'الطرف الآخر';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final uid = _uid;
    if (text.isEmpty || uid == null || _sending || _error != null) return;
    if (text.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرسالة طويلة جداً؛ الحد الأقصى 1000 حرف.')));
      return;
    }
    setState(() => _sending = true);
    try {
      final rideSnap = await _db.child('rides/${widget.rideId}').get();
      if (!rideSnap.exists || rideSnap.value is! Map) throw Exception('الرحلة غير موجودة.');
      final ride = Map<String, dynamic>.from(rideSnap.value as Map);
      if (uid != ride['riderId'] && uid != ride['driverId']) throw Exception('غير مسموح لك بإرسال رسالة.');
      if (ride['status'] == 'cancelled' || ride['status'] == 'completed') throw Exception('المحادثة مغلقة بعد انتهاء الرحلة.');
      final ref = _db.child('rides/${widget.rideId}/messages').push();
      await ref.set({
        'senderId': uid,
        'senderName': _myName,
        'text': text,
        'createdAt': ServerValue.timestamp,
      });
      _input.clear();
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _time(dynamic value) {
    final ms = value is num ? value.toInt() : 0;
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(title: Text('محادثة مع $_otherName'), centerTitle: true),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
          : Column(children: [
              Container(width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.amber.shade50,
                child: const Text('استخدم المحادثة لتنسيق تفاصيل الرحلة فقط، ولا تشارك بياناتك الحساسة.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
              Expanded(child: StreamBuilder<DatabaseEvent>(
                stream: _db.child('rides/${widget.rideId}/messages').onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الرسائل.'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final value = snapshot.data!.snapshot.value;
                  final messages = <Map<String, dynamic>>[];
                  if (value is Map) {
                    value.forEach((key, item) {
                      if (item is Map) messages.add({...Map<String, dynamic>.from(item), '_key': key.toString()});
                    });
                  }
                  messages.sort((a, b) => ((a['createdAt'] as num?) ?? 0).compareTo((b['createdAt'] as num?) ?? 0));
                  if (messages.isEmpty) return const Center(child: Text('ابدأ المحادثة برسالة قصيرة 👋'));
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  });
                  return ListView.builder(controller: _scroll, padding: const EdgeInsets.all(14), itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final mine = m['senderId']?.toString() == uid;
                      return Align(alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(constraints: const BoxConstraints(maxWidth: 300), margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(color: mine ? const Color(0xFFDCEBFF) : const Color(0xFFF0F1F3), borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (!mine) Text((m['senderName'] ?? _otherName).toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1769AA))),
                            Text((m['text'] ?? '').toString(), style: const TextStyle(fontSize: 15)),
                            Align(alignment: AlignmentDirectional.centerEnd, child: Text(_time(m['createdAt']), style: TextStyle(fontSize: 10, color: Colors.grey.shade700))),
                          ]),
                        ),
                      );
                    });
                },
              )),
              SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
                Expanded(child: TextField(controller: _input, minLines: 1, maxLines: 4, maxLength: 1000, textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(hintText: 'اكتب رسالتك...', counterText: '', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send), tooltip: 'إرسال'),
              ]))),
            ]),
    );
  }
}
