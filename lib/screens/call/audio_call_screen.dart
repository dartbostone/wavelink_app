import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/permission_utils.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_control_button.dart';
import '../../widgets/network_quality_indicator.dart';

/// Spec §6 — Audio Calling Screen.
///
/// Two ways to reach this screen:
///  * [callee] is set → this device is the *caller*; we request mic
///    permission and start a new outgoing call.
///  * [existingCall] is set → this device just *accepted* an incoming
///    audio call from [IncomingCallScreen]; the call is already active in
///    [CallProvider] and we just render it.
class AudioCallScreen extends StatefulWidget {
  final UserModel? callee;
  final CallModel? existingCall;

  const AudioCallScreen({super.key, this.callee}) : existingCall = null;
  const AudioCallScreen.fromAccepted({super.key, required CallModel call})
      : existingCall = call,
        callee = null;

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  String? _localError;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    if (widget.callee != null) {
      _startOutgoing();
    } else {
      _starting = false;
    }
  }

  Future<void> _startOutgoing() async {
    final granted = await PermissionUtils.requestForAudioCall();
    if (!granted) {
      setState(() {
        _starting = false;
        _localError = AppStrings.micPermissionDenied;
      });
      return;
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final caller = auth.currentUser;
    if (caller == null) return;
    try {
      await context.read<CallProvider>().placeCall(
            caller: caller,
            callee: widget.callee!,
            type: CallType.audio,
          );
    } catch (_) {
      if (mounted) {
        setState(() {
          _localError = AppStrings.callFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_localError != null) {
      return _ErrorScaffold(message: _localError!);
    }

    return Consumer<CallProvider>(
      builder: (context, callProvider, _) {
        final call = callProvider.activeCall;
        if (call == null) {
          return const _ErrorScaffold(message: AppStrings.callFailed);
        }
        final myUid = context.read<AuthProvider>().uid;
        final isIncomingSide = call.calleeId == myUid;
        final otherName = isIncomingSide ? call.callerName : call.calleeName;

        _maybePopOnTerminal(context, call.status);

        final statusText = switch (call.status) {
          CallStatus.ringing => 'Ringing…',
          CallStatus.connected || CallStatus.inCall => DateFormatUtils.duration(callProvider.elapsed),
          CallStatus.busy => 'User is busy',
          CallStatus.rejected => AppStrings.callRejected,
          CallStatus.missed => 'No answer',
          CallStatus.failed => AppStrings.callFailed,
          _ => 'Call ended',
        };

        return Scaffold(
          backgroundColor: AppColors.surfaceDark,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (call.status == CallStatus.connected || call.status == CallStatus.inCall)
                  NetworkQualityIndicator(quality: callProvider.quality),
                const Spacer(),
                CircleAvatar(
                  radius: 64,
                  backgroundColor: AppColors.primary.withOpacity(0.25),
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 44, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                Text(otherName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CallControlButton(
                        icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                        label: 'Mute',
                        active: callProvider.isMuted,
                        onPressed: callProvider.toggleMute,
                      ),
                      CallControlButton(
                        icon: callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: 'Speaker',
                        active: callProvider.isSpeakerOn,
                        onPressed: callProvider.toggleSpeaker,
                      ),
                      CallControlButton(
                        icon: Icons.call_end,
                        label: 'End',
                        activeColor: AppColors.danger,
                        active: true,
                        onPressed: () async {
                          await callProvider.hangUp();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _popped = false;
  void _maybePopOnTerminal(BuildContext context, CallStatus status) {
    const terminal = {
      CallStatus.ended,
      CallStatus.rejected,
      CallStatus.missed,
      CallStatus.busy,
      CallStatus.failed,
      CallStatus.disconnected,
    };
    if (_popped || !terminal.contains(status)) return;
    _popped = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) Navigator.of(context).maybePop();
    });
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
