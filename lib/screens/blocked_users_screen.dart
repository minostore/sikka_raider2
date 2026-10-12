import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class BlockedUsersScreen extends StatelessWidget {
  final String role;
  const BlockedUsersScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('سجّل الدخول أولاً')));
    final ref = FirebaseDatabase.instance.ref('blocks/$uid');
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الحظر')),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل قائمة الحظر'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final raw = snapshot.data!.snapshot.value;
          if (raw is! Map || raw.isEmpty) return const Center(child: Text('قائمة الحظر فارغة'));
          final entries = raw.entries.toList();
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final data = entry.value is Map ? Map<String, dynamic>.from(entry.value as Map) : <String, dynamic>{};
              final name = (data['name'] ?? 'حساب محظور').toString();
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
                title: Text(name),
                subtitle: Text((data['role'] ?? (role == 'driver' ? 'rider' : 'driver')) == 'driver' ? 'سائق' : 'مستخدم'),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ref.child(entry.key.toString()).remove();
                    } catch (_) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إزالة الحظر')));
                    }
                  },
                  child: const Text('إلغاء الحظر'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
