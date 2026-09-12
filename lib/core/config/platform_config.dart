class PlatformConfig {
  PlatformConfig._();

  static const String _envAgoraAppId = String.fromEnvironment('AGORA_APP_ID');

  /// Fallback Agora App ID if not supplied via --dart-define=AGORA_APP_ID=...
  static const String defaultAgoraAppId = '';

  static const String _envAgoraToken = String.fromEnvironment('AGORA_TOKEN');

  /// Fallback Agora Token if not supplied via --dart-define=AGORA_TOKEN=...
  static const String defaultAgoraToken = '';

  static String get agoraAppId =>
      _envAgoraAppId.isNotEmpty ? _envAgoraAppId : defaultAgoraAppId;

  static String get agoraToken =>
      _envAgoraToken.isNotEmpty ? _envAgoraToken : defaultAgoraToken;

  static bool get hasAgoraAppId => agoraAppId.isNotEmpty;
}
