import 'package:agora_rtc_engine/agora_rtc_engine.dart';
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
import '../../services/calling_service.dart';
import '../../widgets/call_control_button.dart';
import '../../widgets/network_quality_indicator.dart';

/// Spec §7 — Video Calling Screen: remote video (fullscreen), local
/// camera preview (small overlay), caller info, and mute/camera/switch/end
/// controls.
class VideoCallScreen extends StatefulWidget {
  final UserModel? callee;
  final CallModel? existingCall;

  const VideoCallScreen({super.key, this.callee}) : existingCall = null;
  const VideoCallScreen.fromAccepted({super.key, required CallModel call})
      : existingCall = call,
        callee = null;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  String? _localError;
  bool _starting = true;
  int? _remoteUid;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    CallingService.instance.onRemoteUserJoined.listen((uidStr) {
      if (mounted) setState(() => _remoteUid = int.tryParse(uidStr));
    });
    CallingService.instance.onRemoteUserLeft.listen((_) {
      if (mounted) setState(() => _remoteUid = null);
    });

    if (widget.callee != null) {
      _startOutgoing();
    } else {
      _starting = false;
    }
  }

  Future<void> _startOutgoing() async {
    final granted = await PermissionUtils.requestForVideoCall();
    if (!granted) {
      setState(() {
        _starting = false;
        _localError = AppStrings.cameraPermissionDenied;
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
            type: CallType.video,
          );
    } catch (_) {
      if (mounted) setState(() => _localError = AppStrings.callFailed);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        backgroundColor: Colors.black,
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
        final engine = CallingService.instance.engine;
        final connected = call.status == CallStatus.connected || call.status == CallStatus.inCall;

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
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Remote video fills the screen once connected & the other
              // party's video track has arrived; otherwise show a
              // placeholder with the caller's name (spec: "connection
              // status" must always be visible).
              Positioned.fill(
                child: (connected && _remoteUid != null && engine != null)
                    ? AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: engine,
                          canvas: VideoCanvas(uid: _remoteUid),
                          connection: RtcConnection(channelId: call.channelId),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1B1E2B),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 56,
                                backgroundColor: AppColors.primary.withOpacity(0.25),
                                child: Text(
                                  otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 40, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(otherName, style: const TextStyle(color: Colors.white, fontSize: 22)),
                              const SizedBox(height: 6),
                              Text(statusText, style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
              ),

              // Local camera preview.
              if (callProvider.isCameraEnabled && engine != null)
                Positioned(
                  top: 48,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 110,
                      height: 150,
                      color: Colors.black,
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ),

              // Top bar: name + status + network quality.
              Positioned(
                top: 48,
                left: 16,
                right: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(statusText, style: const TextStyle(color: Colors.white70)),
                    if (connected) ...[
                      const SizedBox(height: 8),
                      NetworkQualityIndicator(quality: callProvider.quality),
                    ],
                  ],
                ),
              ),

              // Controls.
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
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
                      icon: callProvider.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                      label: 'Camera',
                      active: !callProvider.isCameraEnabled,
                      onPressed: callProvider.toggleCamera,
                    ),
                    CallControlButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onPressed: callProvider.switchCamera,
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
        );
      },
    );
  }

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
      backgroundColor: Colors.black,
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
