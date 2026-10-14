import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// يمنع الرجوع للصفحة السابقة أثناء الرحلة المؤكدة:
/// الضغطة الأولى على زر الرجوع تعرض تنبيهاً فقط، والثانية (خلال ثانيتين) تُغلق التطبيق.
class DoubleBackExit extends StatefulWidget {
  final Widget child;

  /// عند false يعمل الرجوع بشكل عادي (مثلاً بعد انتهاء الرحلة).
  final bool enabled;

  /// يُستدعى عند الضغط على الرجوع وهو غير مفعّل الحماية (اختياري، مثل تنظيف الحالة).
  final VoidCallback? onPoppedFreely;
  const DoubleBackExit({super.key, required this.child, this.enabled = true, this.onPoppedFreely});

  @override
  State<DoubleBackExit> createState() => _DoubleBackExitState();
}

class _DoubleBackExitState extends State<DoubleBackExit> {
  DateTime? _last;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.enabled,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            widget.onPoppedFreely?.call();
            return;
          }
          final now = DateTime.now();
          if (_last != null && now.difference(_last!) < const Duration(seconds: 2)) {
            SystemNavigator.pop();
            return;
          }
          _last = now;
          final m = ScaffoldMessenger.maybeOf(context);
          m?.hideCurrentSnackBar();
          m?.showSnackBar(const SnackBar(
            content: Text('اضغط مرة أخرى للخروج من التطبيق'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
        },
        child: widget.child,
      );
}
