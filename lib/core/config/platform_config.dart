class PlatformConfig {
  PlatformConfig._();

  static const agoraAppId = String.fromEnvironment('AGORA_APP_ID');
  static const agoraToken = String.fromEnvironment('AGORA_TOKEN');

  static bool get hasAgoraAppId => agoraAppId.isNotEmpty;
}
