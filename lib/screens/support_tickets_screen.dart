import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Live support inbox shared by rider/driver apps; tickets are stored at /tickets
/// to match the existing admin dashboard schema.
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
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تذكرة دعم جديدة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder<String>(valueListenable: category, builder: (_, v, __) => DropdownButtonFormField<String>(value: v, decoration: const InputDecoration(labelText: 'نوع المشكلة'), items: const [DropdownMenuItem(value:'general',child:Text('استفسار عام')),DropdownMenuItem(value:'ride',child:Text('مشكلة رحلة')),DropdownMenuItem(value:'payment',child:Text('مشكلة مالية')),DropdownMenuItem(value:'account',child:Text('الحساب أو المستندات'))], onChanged: (x) { if (x != null) category.value = x; })),
        TextField(controller: title, maxLength: 100, decoration: const InputDecoration(labelText: 'عنوان المشكلة')),
        TextField(controller: body, maxLines: 4, maxLength: 1500, decoration: const InputDecoration(labelText: 'اشرح المشكلة')),
      ])),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال'))],
    ));
    if (ok != true || _uid == null || title.text.trim().isEmpty || body.text.trim().isEmpty) return;
    final id = _db.child('tickets').push().key!;
    final now = ServerValue.timestamp;
    try {
      await _db.update({
        'tickets/$id': {'uid':_uid,'role':widget.role,'title':title.text.trim(),'category':category.value,'status':'open','priority':'medium','createdAt':now,'updatedAt':now,'messages':{'m1':{'from':widget.role == 'driver' ? 'driver' : 'user','uid':_uid,'text':body.text.trim(),'createdAt':now}}},
        'userTickets/${_uid}/$id': true,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال التذكرة بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التذكرة: ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      title.dispose();
      body.dispose();
      category.dispose();
    }
  }

  Future<Map<String, String>?> _pickAndUploadAttachment() async {
    if (_uid == null) return null;
    try {
      final choice = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('اختيار صورة'), onTap: () => Navigator.pop(ctx, 'gallery')),
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('التقاط صورة'), onTap: () => Navigator.pop(ctx, 'camera')),
        ListTile(leading: const Icon(Icons.attach_file), title: const Text('اختيار ملف'), onTap: () => Navigator.pop(ctx, 'file')),
      ])));
      if (choice == null) return null;
      String name; String contentType = 'application/octet-stream'; late final List<int> bytes;
      if (choice == 'gallery' || choice == 'camera') {
        final picker = ImagePicker();
        final XFile? file = choice == 'camera' ? await picker.pickImage(source: ImageSource.camera, imageQuality: 82) : await picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
        if (file == null) return null;
        name = file.name; bytes = await file.readAsBytes(); contentType = 'image/jpeg';
      } else {
        final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.any);
        if (result == null || result.files.single.bytes == null) return null;
        final f = result.files.single; name = f.name; bytes = f.bytes!;
        if (bytes.length > 12 * 1024 * 1024) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى لحجم الملف 12 ميجابايت'))); return null; }
        contentType = 'application/octet-stream';
      }
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = FirebaseStorage.instance.ref('support_attachments/$_uid/${DateTime.now().millisecondsSinceEpoch}_$safeName');
      await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: contentType));
      return {'url': await ref.getDownloadURL(), 'name': name};
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر رفع المرفق. تحقق من صلاحيات Firebase Storage.')));
      return null;
    }
  }

  Future<void> _reply(String id, Map<String,dynamic> ticket) async {
    final c = TextEditingController();
    Map<String, String>? attachment;
    final ok = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16,16,16,MediaQuery.of(ctx).viewInsets.bottom+16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Text('الرد على: ${ticket['title'] ?? 'الدعم'}',style: Theme.of(ctx).textTheme.titleMedium), TextField(controller:c, autofocus:true, maxLength:1000, maxLines:4, decoration:const InputDecoration(hintText:'اكتب رسالتك')), const SizedBox(height:8), StatefulBuilder(builder: (ctx2, setSheet) => Row(children: [IconButton(tooltip: 'إرفاق صورة أو ملف', onPressed: () async { final a = await _pickAndUploadAttachment(); if (a != null) setSheet(() => attachment = a); }, icon: const Icon(Icons.attach_file)), Expanded(child: Text(attachment?['name'] ?? 'إرفاق صورة أو ملف', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(tooltip: 'إرسال', onPressed:()=>Navigator.pop(ctx,true), icon: const Icon(Icons.send))]))]),
    ));
    if (ok != true || (c.text.trim().isEmpty && attachment == null) || _uid == null) return;
    if (ticket['status'] == 'closed') { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('التذكرة مغلقة؛ افتح تذكرة جديدة إذا استمرت المشكلة.'))); return; }
    try {
      await _db.child('tickets/$id/messages').push().set({'from':widget.role == 'driver' ? 'driver' : 'user','uid':_uid,'text':c.text.trim(),'attachmentUrl':attachment?['url'],'attachmentName':attachment?['name'],'createdAt':ServerValue.timestamp});
      await _db.child('tickets/$id/updatedAt').set(ServerValue.timestamp);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الرد: ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً')));
    return Scaffold(appBar: AppBar(title: const Text('الدعم الفني')), floatingActionButton: FloatingActionButton.extended(onPressed:_newTicket,icon:const Icon(Icons.add_comment_outlined),label:const Text('تذكرة جديدة')),
      body: StreamBuilder<DatabaseEvent>(stream:_db.child('userTickets/$uid').onValue,builder:(context, indexSnap) {
        if (indexSnap.hasError) return const Center(child:Text('تعذر تحميل التذاكر'));
        if (!indexSnap.hasData) return const Center(child:CircularProgressIndicator());
        final ids = <String>[]; final raw = indexSnap.data!.snapshot.value;
        if (raw is Map) ids.addAll(raw.keys.map((e)=>e.toString()));
        if (ids.isEmpty) return const Center(child:Text('لا توجد تذاكر دعم حتى الآن'));
        return ListView.builder(padding:const EdgeInsets.all(12),itemCount:ids.length,itemBuilder:(context,i) {
          final id=ids[ids.length-1-i];
          return StreamBuilder<DatabaseEvent>(stream:_db.child('tickets/$id').onValue,builder:(context,ticketSnap) {
            final t=ticketSnap.data?.snapshot.value; if (t is! Map) return const SizedBox.shrink();
            final ticket=Map<String,dynamic>.from(t); final messages=<Map<String,dynamic>>[]; final mm=ticket['messages'];
            if(mm is Map) for(final v in mm.values) { if(v is Map) messages.add(Map<String,dynamic>.from(v)); }
            messages.sort((a,b)=>((a['createdAt'] as num?)??0).compareTo((b['createdAt'] as num?)??0));
            final status=(ticket['status']??'open').toString();
            return Card(child:ExpansionTile(title:Text((ticket['title']??'تذكرة دعم').toString()),subtitle:Text('الحالة: ${status=='open'?'مفتوحة':status=='pending'?'قيد المعالجة':status=='closed'?'مغلقة':status} • ${messages.length} رسالة'),children:[
              for(final m in messages) ListTile(dense:true,leading:Icon(m['from']=='admin'?Icons.support_agent:Icons.person_outline),title:Text((m['text']??'').toString()),subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m['from']=='admin'?'الدعم الفني':'أنت'), if ((m['attachmentUrl'] ?? '').toString().startsWith('https://')) TextButton.icon(onPressed: () async { final u = Uri.tryParse(m['attachmentUrl'].toString()); if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.attach_file), label: Text((m['attachmentName'] ?? 'فتح المرفق').toString()))])),
              if(status!='closed') Padding(padding:const EdgeInsets.all(12),child:Align(alignment:AlignmentDirectional.centerEnd,child:TextButton.icon(onPressed:()=>_reply(id,ticket),icon:const Icon(Icons.reply),label:const Text('فتح المحادثة / إرسال رسالة')))),
              if(status=='closed') Padding(padding: const EdgeInsets.all(12), child: Column(children: [const Text('قيّم تجربة الدعم'), Wrap(alignment: WrapAlignment.center, children: [for (var stars=1; stars<=5; stars++) IconButton(icon: Icon(stars <= ((ticket['rating'] as num?)?.toInt() ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber), onPressed: () async { await _db.child('tickets/$id/rating').set(stars); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكرًا لتقييمك'))); })])])),
            ]));
          });
        });
      }),
    );
  }
}
