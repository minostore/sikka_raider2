import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common.dart';

/// رقم الهاتف المصري: «+20» ثابتة ثم 10 أرقام تبدأ بـ 10 أو 11 أو 12 أو 15.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const PhoneField({super.key, required this.controller, this.hint = 'رقم الهاتف (10 أرقام)'});

  static final RegExp _re = RegExp(r'^1[0125][0-9]{8}$');

  /// يقبل الأرقام العشرة فقط (بدون +20).
  static bool isValid(String digits) => _re.hasMatch(digits.trim());

  /// الصيغة الكاملة بعد إضافة رمز الدولة.
  static String full(String digits) => '+20${digits.trim()}';

  static const String errorText = 'أدخل 10 أرقام بعد +20 وتبدأ بـ 10 أو 11 أو 12 أو 15';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark ? Colors.white70 : Colors.grey.shade600;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
        style: TextStyle(color: dark ? Colors.white : null),
        decoration: fieldDec(context, hint, Icons.phone_outlined).copyWith(
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.phone_outlined, size: 22, color: iconColor),
              const SizedBox(width: 8),
              Text('+20', style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : Colors.black87)),
            ]),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }
}
