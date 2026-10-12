import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class TicketChatScreen extends StatefulWidget {
  final String ticketId;
  final String role;
  const TicketChatScreen({super.key, required this.ticketId, required this.role});
  @override State<TicketChatScreen> createState() => _TicketChatScreenState();
}
class _TicketChatScreenState extends State<TicketChatScreen> {
  final _db = FirebaseDatabase.instance.ref();
  final _input = TextEditingController();
  bool _sending = false;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  Future<void> _send() async {
    final text = _input.text.trim(); final uid = _uid;
    if (text.isEmpty || uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      final snap = await _db.child('tickets/${widget.ticketId}').get();
      if (!snap.exists || snap.value is! Map) throw Exception('التذكرة غير موجودة');
      final t = Map<String,dynamic>.from(snap.value as Map);
      if (t['uid']?.toString() != uid) throw Exception('غير مسموح بفتح هذه التذكرة');
      if (t['status'] == 'closed') throw Exception('التذكرة مغلقة؛ افتح تذكرة جديدة إذا استمرت المشكلة');
      await _db.child('tickets/${widget.ticketId}/messages').push().set({'from':widget.role == 'driver' ? 'driver' : 'user','uid':uid,'text':text,'createdAt':ServerValue.timestamp});
      await _db.child('tickets/${widget.ticketId}/updatedAt').set(ServerValue.timestamp);
      _input.clear();
    } catch(e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ','')))); }
    finally { if (mounted) setState(() => _sending = false); }
  }
  @override void dispose(){_input.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: StreamBuilder<DatabaseEvent>(stream:_db.child('tickets/${widget.ticketId}').onValue,builder:(c,s){final v=s.data?.snapshot.value; final m=v is Map ? Map<String,dynamic>.from(v) : <String,dynamic>{}; return Text('تذكرة #${widget.ticketId.length > 8 ? widget.ticketId.substring(widget.ticketId.length-8) : widget.ticketId} • ${(m['status']=='closed')?'مغلقة':(m['status']=='pending')?'قيد المعالجة':'مفتوحة'}',style:const TextStyle(fontSize:15));})),
    body: Column(children:[Expanded(child:StreamBuilder<DatabaseEvent>(stream:_db.child('tickets/${widget.ticketId}/messages').onValue,builder:(c,s){if(s.hasError)return const Center(child:Text('تعذر تحميل المحادثة'));if(!s.hasData)return const Center(child:CircularProgressIndicator());final raw=s.data!.snapshot.value;final msgs=<Map<String,dynamic>>[];if(raw is Map){for(final v in raw.values){if(v is Map)msgs.add(Map<String,dynamic>.from(v));}}msgs.sort((a,b)=>((a['createdAt'] as num?)??0).compareTo((b['createdAt'] as num?)??0));if(msgs.isEmpty)return const Center(child:Text('ابدأ المحادثة مع خدمة العملاء'));return ListView(padding:const EdgeInsets.all(12),children:[for(final m in msgs) Align(alignment:(m['uid']?.toString()==_uid)?AlignmentDirectional.centerEnd:AlignmentDirectional.centerStart,child:Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(12),constraints:const BoxConstraints(maxWidth:300),decoration:BoxDecoration(color:m['from']=='admin'?const Color(0xFFE7F2FF):const Color(0xFFF0F1F3),borderRadius:BorderRadius.circular(14)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(m['from']=='admin')const Text('خدمة العملاء',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.blue)),Text((m['text']??'').toString()),Text(m['createdAt'] is num ? DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num).toInt()).toLocal().toString().substring(11,16) : '',style:const TextStyle(fontSize:10,color:Colors.grey))]))]);})),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:TextField(controller:_input,maxLines:4,minLines:1,maxLength:1000,decoration:const InputDecoration(hintText:'اكتب رسالتك...',counterText:'',border:OutlineInputBorder()))),const SizedBox(width:8),IconButton.filled(onPressed:_sending?null:_send,icon:_sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send))]))) ]));
}
