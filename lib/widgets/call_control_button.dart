import 'package:flutter/material.dart';

/// The large round control buttons on the in-call screens (mute, camera,
/// switch, speaker, end). Shows an active/inactive visual state so users
/// always know, e.g., whether the mic is currently muted.
class CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final Color iconColorOnInactive;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x33FFFFFF),
    this.iconColorOnInactive = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active ? activeColor : inactiveColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: active ? Colors.black87 : iconColorOnInactive, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
