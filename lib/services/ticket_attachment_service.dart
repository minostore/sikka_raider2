import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TicketAttachmentService {
  static const _extensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'doc',
    'docx',
  ];

  static Future<Map<String, dynamic>?> pickAndUpload({
    required String uid,
    required String ticketId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final path = file.path;
    if (path == null)
      throw Exception('تعذر قراءة الملف المحدد. حاول اختيار ملف آخر.');
    if (file.size > 15 * 1024 * 1024)
      throw Exception('الحد الأقصى لحجم الملف 15 ميجابايت.');
    final ext = (file.extension ?? '').toLowerCase();
    if (!_extensions.contains(ext)) throw Exception('نوع الملف غير مدعوم.');
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storageRef = FirebaseStorage.instance.ref(
      'ticketAttachments/$uid/$ticketId/${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await storageRef.putFile(File(path), SettableMetadata(contentType: mime));
    return {
      'storagePath': storageRef.fullPath,
      'name': file.name,
      'contentType': mime,
      'size': file.size,
    };
  }
}
