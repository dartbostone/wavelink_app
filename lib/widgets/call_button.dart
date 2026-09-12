import 'package:flutter/material.dart';

/// Small round icon button used for audio/video call actions on the
/// Contacts screen.
class CallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color background;

  const CallButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
