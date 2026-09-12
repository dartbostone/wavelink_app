import 'package:flutter/material.dart';

import '../services/calling_service.dart';

class NetworkQualityIndicator extends StatelessWidget {
  final NetworkQuality quality;

  const NetworkQualityIndicator({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    final (label, color, bars) = switch (quality) {
      NetworkQuality.good => ('Good', Colors.greenAccent, 3),
      NetworkQuality.fair => ('Fair', Colors.orangeAccent, 2),
      NetworkQuality.poor => ('Poor', Colors.redAccent, 1),
      NetworkQuality.unknown => ('—', Colors.white54, 0),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 3,
                height: 6.0 + (i * 3),
                color: i < bars ? color : Colors.white24,
              );
            }),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
