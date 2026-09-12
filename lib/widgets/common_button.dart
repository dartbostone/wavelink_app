import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Primary button with a built-in loading state (spec: "Proper button
/// states").
class CommonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final Color? color;

  const CommonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

    if (outlined) {
      return SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color ?? AppColors.primary,
            side: BorderSide(color: color ?? AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: color != null ? ElevatedButton.styleFrom(backgroundColor: color) : null,
        child: child,
      ),
    );
  }
}
