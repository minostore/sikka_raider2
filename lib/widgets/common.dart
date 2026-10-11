import 'package:flutter/material.dart';
import '../core/theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView(this.message, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyView(this.message, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ]),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const InfoCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // البطاقات بيضاء حتى في الوضع الداكن (كما في تصميم تطبيق السائق)
    final inner = dark
        ? Theme(
            data: AppTheme.light,
            child: DefaultTextStyle.merge(style: const TextStyle(color: AppColors.ink), child: child))
        : child;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 14, color: Color(0x1A0B2A3C), offset: Offset(0, 4))],
      ),
      child: inner,
    );
  }
}

/// الزر الأساسي بتدرج لوني حسب هوية كل تطبيق
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? color;
  final IconData? icon;
  const AppButton(this.text, {super.key, this.onPressed, this.busy = false, this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? AppColors.primary;
    final fg = (color == null && dark) ? AppColors.navy : Colors.white;
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.14)!]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                      Text(text, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// حقل بأيقونة جانبية بنمط التصميم
InputDecoration fieldDec(BuildContext context, String hint, IconData icon, {Widget? suffix}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: dark ? Colors.white70 : Colors.grey.shade600),
    suffixIcon: suffix,
    filled: true,
    fillColor: dark ? const Color(0xFF173B5A) : Colors.white,
    hintStyle: TextStyle(color: dark ? Colors.white60 : Colors.grey.shade600),
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? const Color(0xFF244B6B) : const Color(0xFFDDE5EA))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? const Color(0xFF244B6B) : const Color(0xFFDDE5EA))),
  );
}
