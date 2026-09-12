import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_control_button.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

/// Spec §8 — Incoming Call Screen: caller name, avatar, Decline / Accept.
/// Pushed by the app-wide incoming-call listener in main.dart the instant
/// a new `calls` document addressed to this user appears.
class IncomingCallScreen extends StatelessWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final isVideo = call.type == CallType.video;
    return PopScope(
      canPop: false, // Force an explicit accept/decline decision.
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 64,
                backgroundColor: AppColors.primary.withOpacity(0.25),
                backgroundImage: call.callerAvatarUrl != null
                    ? NetworkImage(call.callerAvatarUrl!)
                    : null,
                child: call.callerAvatarUrl == null
                    ? Text(
                        call.callerName.isNotEmpty
                            ? call.callerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 44,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                call.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isVideo ? 'wants to video call' : 'wants to audio call',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 40,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CallControlButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      active: true,
                      activeColor: AppColors.danger,
                      onPressed: () async {
                        await context.read<CallProvider>().reject(call);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                    CallControlButton(
                      icon: Icons.call,
                      label: 'Accept',
                      active: true,
                      activeColor: AppColors.accent,
                      onPressed: () async {
                        final callProvider = context.read<CallProvider>();
                        await callProvider.accept(call);
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => isVideo
                                ? VideoCallScreen.fromAccepted(call: call)
                                : AudioCallScreen.fromAccepted(call: call),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
