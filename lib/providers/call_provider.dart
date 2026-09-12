import 'dart:async';

import 'package:flutter/material.dart';

import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/calling_service.dart';
import '../services/notification_service.dart';

/// Drives every call screen (audio, video, incoming). Holds the single
/// "currently active call" for the app — ConnectCall only supports 1-to-1
/// calls, so one active call at a time is a deliberate simplification.
class CallProvider extends ChangeNotifier {
  final CallingService _callingService = CallingService.instance;

  static const Duration ringTimeout = Duration(seconds: 30);

  CallModel? activeCall;
  bool isMuted = false;
  bool isSpeakerOn = true;
  bool isCameraEnabled = true;
  Duration elapsed = Duration.zero;
  NetworkQuality quality = NetworkQuality.unknown;
  String? engineErrorMessage;

  StreamSubscription<CallModel>? _callSub;
  StreamSubscription<NetworkQuality>? _qualitySub;
  StreamSubscription<String>? _errorSub;
  Timer? _ringTimer;
  Timer? _durationTimer;

  bool _iAmCaller = false;
  bool get isCaller => _iAmCaller;

  /// Subscribes once (call from main.dart) to be notified of any incoming
  /// call the moment its Firestore document appears.
  Stream<CallModel?> incomingCallStream(String myUid) =>
      _callingService.watchIncomingCalls(myUid);

  Future<CallModel> placeCall({
    required UserModel caller,
    required UserModel callee,
    required CallType type,
  }) async {
    _iAmCaller = true;
    final call = await _callingService.startCall(caller: caller, callee: callee, type: type);
    activeCall = call;
    isCameraEnabled = type == CallType.video;
    _subscribeToCall(call.id);
    _startRingTimeout();
    notifyListeners();
    return call;
  }

  Future<void> accept(CallModel call) async {
    _iAmCaller = false;
    await NotificationService.instance.cancelIncomingCall();
    activeCall = call;
    isCameraEnabled = call.type == CallType.video;
    await _callingService.acceptCall(call);
    _subscribeToCall(call.id);
    notifyListeners();
  }

  Future<void> reject(CallModel call) async {
    await NotificationService.instance.cancelIncomingCall();
    await _callingService.rejectCall(call);
  }

  void _subscribeToCall(String callId) {
    _callSub?.cancel();
    _callSub = _callingService.watchCall(callId).listen(_onCallUpdated, onError: (_) {
      engineErrorMessage = 'Lost connection to the call.';
      notifyListeners();
    });
    _qualitySub?.cancel();
    _qualitySub = _callingService.networkQuality.listen((q) {
      quality = q;
      notifyListeners();
    });
    _errorSub?.cancel();
    _errorSub = _callingService.onEngineError.listen((msg) async {
      engineErrorMessage = msg;
      if (activeCall != null) {
        await _callingService.markFailed(activeCall!.id, reason: msg);
      }
      notifyListeners();
    });
  }

  void _onCallUpdated(CallModel call) {
    activeCall = call;
    if (call.status == CallStatus.connected || call.status == CallStatus.inCall) {
      _ringTimer?.cancel();
      _startDurationTimer(call);
    }
    if (_isTerminal(call.status)) {
      _stopTimers();
    }
    notifyListeners();
  }

  bool _isTerminal(CallStatus s) => {
        CallStatus.ended,
        CallStatus.rejected,
        CallStatus.missed,
        CallStatus.busy,
        CallStatus.failed,
        CallStatus.disconnected,
      }.contains(s);

  void _startRingTimeout() {
    _ringTimer?.cancel();
    _ringTimer = Timer(ringTimeout, () async {
      if (activeCall != null && activeCall!.status == CallStatus.ringing) {
        await _callingService.markMissed(activeCall!);
      }
    });
  }

  void _startDurationTimer(CallModel call) {
    _durationTimer?.cancel();
    final start = call.connectedAt ?? DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed = DateTime.now().difference(start);
      notifyListeners();
    });
  }

  void _stopTimers() {
    _ringTimer?.cancel();
    _durationTimer?.cancel();
  }

  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _callingService.setMuted(isMuted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn = !isSpeakerOn;
    await _callingService.setSpeakerEnabled(isSpeakerOn);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    isCameraEnabled = !isCameraEnabled;
    await _callingService.setCameraEnabled(isCameraEnabled);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _callingService.switchCamera();
  }

  Future<void> hangUp() async {
    final call = activeCall;
    if (call == null) return;
    if (_iAmCaller && call.status == CallStatus.ringing) {
      await _callingService.markMissed(call);
    } else {
      await _callingService.endCall(call);
    }
    await _reset();
  }

  Future<void> _reset() async {
    _stopTimers();
    await _callSub?.cancel();
    await _qualitySub?.cancel();
    await _errorSub?.cancel();
    activeCall = null;
    elapsed = Duration.zero;
    isMuted = false;
    isCameraEnabled = true;
    quality = NetworkQuality.unknown;
    engineErrorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimers();
    _callSub?.cancel();
    _qualitySub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }
}
