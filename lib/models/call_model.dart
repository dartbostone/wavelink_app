/// Whether the call carries video.
enum CallType { audio, video }

/// All call states the UI must account for (spec §Call States).
enum CallStatus {
  calling,
  ringing,
  connected,
  inCall,
  ended,
  rejected,
  missed,
  busy,
  failed,
  disconnected,
}

CallType callTypeFromString(String value) =>
    value == 'video' ? CallType.video : CallType.audio;

String callTypeToString(CallType type) => type == CallType.video ? 'video' : 'audio';

CallStatus callStatusFromString(String value) {
  return CallStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => CallStatus.ended,
  );
}

/// A call document, mirrored to Firestore's `calls/{callId}`.
/// Firestore also doubles as the *signaling* channel: the callee listens
/// for new documents where `calleeId == myId`, and both sides watch the
/// same document for status changes (accepted / rejected / ended).
class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String calleeId;
  final String calleeName;
  final String? calleeAvatarUrl;
  final CallType type;
  final CallStatus status;
  final String channelId; // Agora channel name
  final DateTime createdAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatarUrl,
    required this.type,
    required this.status,
    required this.channelId,
    required this.createdAt,
    this.connectedAt,
    this.endedAt,
  });

  Duration get duration {
    if (connectedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(connectedAt!);
  }

  bool isIncomingFor(String uid) => calleeId == uid;

  bool wasMissedOrRejectedFor(String uid) {
    if (status == CallStatus.missed) return true;
    if (status == CallStatus.rejected) return true;
    return false;
  }

  factory CallModel.fromMap(String id, Map<String, dynamic> map) {
    return CallModel(
      id: id,
      callerId: map['callerId'] as String,
      callerName: map['callerName'] as String? ?? 'Unknown',
      callerAvatarUrl: map['callerAvatarUrl'] as String?,
      calleeId: map['calleeId'] as String,
      calleeName: map['calleeName'] as String? ?? 'Unknown',
      calleeAvatarUrl: map['calleeAvatarUrl'] as String?,
      type: callTypeFromString(map['type'] as String? ?? 'audio'),
      status: callStatusFromString(map['status'] as String? ?? 'ended'),
      channelId: map['channelId'] as String? ?? id,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      connectedAt: map['connectedAt'] != null
          ? DateTime.tryParse(map['connectedAt'].toString())
          : null,
      endedAt: map['endedAt'] != null ? DateTime.tryParse(map['endedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatarUrl': callerAvatarUrl,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleeAvatarUrl': calleeAvatarUrl,
      'type': callTypeToString(type),
      'status': status.name,
      'channelId': channelId,
      'createdAt': createdAt.toIso8601String(),
      'connectedAt': connectedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  CallModel copyWith({CallStatus? status, DateTime? connectedAt, DateTime? endedAt}) {
    return CallModel(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerAvatarUrl: callerAvatarUrl,
      calleeId: calleeId,
      calleeName: calleeName,
      calleeAvatarUrl: calleeAvatarUrl,
      type: type,
      status: status ?? this.status,
      channelId: channelId,
      createdAt: createdAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
