import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config/platform_config.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';

enum NetworkQuality { unknown, good, fair, poor }

class CallingService {
  CallingService._internal();
  static final CallingService instance = CallingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  final StreamController<NetworkQuality> _networkQualityController =
      StreamController<NetworkQuality>.broadcast();
  Stream<NetworkQuality> get networkQuality => _networkQualityController.stream;

  final StreamController<String> _remoteJoinedController =
      StreamController<String>.broadcast();
  Stream<String> get onRemoteUserJoined => _remoteJoinedController.stream;

  final StreamController<void> _remoteLeftController =
      StreamController<void>.broadcast();
  Stream<void> get onRemoteUserLeft => _remoteLeftController.stream;

  final StreamController<String> _engineErrorController =
      StreamController<String>.broadcast();
  Stream<String> get onEngineError => _engineErrorController.stream;

  bool _initialized = false;

  Future<void> initializeEngine() async {
    if (_initialized) return;
    if (!PlatformConfig.hasAgoraAppId) {
      debugPrint(
        'Agora App ID not provided via --dart-define=AGORA_APP_ID. Call engine uninitialized.',
      );
      return;
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(appId: PlatformConfig.agoraAppId),
    );
    await _engine!.enableAudio();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          _remoteJoinedController.add(remoteUid.toString());
        },
        onUserOffline: (connection, remoteUid, reason) {
          _remoteLeftController.add(null);
        },
        onError: (err, msg) {
          _engineErrorController.add(msg);
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          // Report whichever direction is worse — a call is only as good
          // as its weakest link.
          final txRank = _qualityRank(txQuality);
          final rxRank = _qualityRank(rxQuality);
          final worst = txRank >= rxRank ? txQuality : rxQuality;
          _networkQualityController.add(_mapQuality(worst));
        },
      ),
    );
    _initialized = true;
  }

  /// Higher rank = worse connection. Keeps the comparison above independent
  /// of the underlying enum's declaration order.
  int _qualityRank(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
        return 0;
      case QualityType.qualityGood:
        return 1;
      case QualityType.qualityPoor:
        return 2;
      case QualityType.qualityBad:
        return 3;
      case QualityType.qualityVbad:
        return 4;
      case QualityType.qualityDown:
        return 5;
      default:
        return -1; // unknown — never treated as "worst"
    }
  }

  NetworkQuality _mapQuality(QualityType quality) {
    switch (quality) {
      case QualityType.qualityExcellent:
      case QualityType.qualityGood:
        return NetworkQuality.good;
      case QualityType.qualityPoor:
      case QualityType.qualityBad:
        return NetworkQuality.fair;
      case QualityType.qualityVbad:
      case QualityType.qualityDown:
        return NetworkQuality.poor;
      default:
        return NetworkQuality.unknown;
    }
  }

  // ---------------------------------------------------------------------
  // Signaling (Firestore)
  // ---------------------------------------------------------------------

  /// Caller side: creates the call document and returns it. The caller
  /// then joins the Agora channel immediately so they're ready the moment
  /// the callee accepts; the UI shows a local "Calling…" state until the
  /// document's status flips to `connected`.
  Future<CallModel> startCall({
    required UserModel caller,
    required UserModel callee,
    required CallType type,
  }) async {
    final callId = _uuid.v4();
    final call = CallModel(
      id: callId,
      callerId: caller.id,
      callerName: caller.name,
      callerAvatarUrl: caller.avatarUrl,
      calleeId: callee.id,
      calleeName: callee.name,
      calleeAvatarUrl: callee.avatarUrl,
      type: type,
      status: CallStatus.ringing,
      channelId: callId,
      createdAt: DateTime.now(),
    );
    await _db.collection('calls').doc(callId).set(call.toMap());
    await _joinChannel(callId, video: type == CallType.video);
    return call;
  }

  /// Callee side: marks the call connected and joins the same channel.
  Future<void> acceptCall(CallModel call) async {
    await _db.collection('calls').doc(call.id).update({
      'status': CallStatus.connected.name,
      'connectedAt': DateTime.now().toIso8601String(),
    });
    await _joinChannel(call.id, video: call.type == CallType.video);
  }

  Future<void> rejectCall(CallModel call) async {
    await _db.collection('calls').doc(call.id).update({
      'status': CallStatus.rejected.name,
      'endedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Called when the caller gives up before the callee responds.
  Future<void> markMissed(CallModel call) async {
    await _db.collection('calls').doc(call.id).update({
      'status': CallStatus.missed.name,
      'endedAt': DateTime.now().toIso8601String(),
    });
    await leaveChannel();
  }

  Future<void> markFailed(String callId, {String? reason}) async {
    await _db.collection('calls').doc(callId).update({
      'status': CallStatus.failed.name,
      'endedAt': DateTime.now().toIso8601String(),
      if (reason != null) 'failureReason': reason,
    });
    await leaveChannel();
  }

  Future<void> endCall(CallModel call) async {
    await _db.collection('calls').doc(call.id).update({
      'status': CallStatus.ended.name,
      'endedAt': DateTime.now().toIso8601String(),
    });
    await leaveChannel();
  }

  /// Live updates for a single call — both parties watch this to react to
  /// accept/reject/end from the other side.
  Stream<CallModel> watchCall(String callId) {
    return _db
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((doc) => CallModel.fromMap(doc.id, doc.data()!));
  }

  /// Callee side: any brand-new ringing call addressed to me.
  Stream<CallModel?> watchIncomingCalls(String myUid) {
    return _db
        .collection('calls')
        .where('calleeId', isEqualTo: myUid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          // Most recent first — in the rare case of overlapping calls, only the
          // newest is offered (the caller of the older one will see `busy`).
          final docs = snapshot.docs.toList()
            ..sort(
              (a, b) => (b.data()['createdAt'] as String).compareTo(
                a.data()['createdAt'] as String,
              ),
            );
          return CallModel.fromMap(docs.first.id, docs.first.data());
        });
  }

  // ---------------------------------------------------------------------
  // Media (Agora)
  // ---------------------------------------------------------------------

  Future<void> _joinChannel(String channelId, {required bool video}) async {
    if (_engine == null) {
      await initializeEngine();
    }
    final engine = _engine;
    if (engine == null) {
      throw Exception(
        'Agora Engine not initialized. Configure AGORA_APP_ID in PlatformConfig or pass via --dart-define=AGORA_APP_ID=...',
      );
    }
    if (video) {
      await engine.enableVideo();
      await engine.startPreview();
    }
    await engine.joinChannel(
      token: PlatformConfig.agoraToken,
      channelId: channelId,
      uid: 0, // 0 lets Agora assign a UID automatically.
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: video,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );
  }

  Future<void> leaveChannel() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.stopPreview();
    await engine.leaveChannel();
  }

  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _engine?.enableLocalVideo(enabled);
    await _engine?.muteLocalVideoStream(!enabled);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _initialized = false;
  }
}
