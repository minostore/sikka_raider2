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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Color(0x14000000))],
        ),
        child: child,
      );
}
