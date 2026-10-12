import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikka_driver/core/utils.dart';

void main() {
  test('Firebase permission errors include a useful reason and diagnostic code', () {
    final text = errorMessage(
      FirebaseException(plugin: 'database', code: 'permission-denied'),
    );
    expect(text, contains('قواعد Firebase'));
    expect(text, contains('database/permission-denied'));
  });

  test('ordinary exceptions keep their original reason', () {
    expect(errorMessage(Exception('الاتصال مرفوض')), 'الاتصال مرفوض');
  });
}
