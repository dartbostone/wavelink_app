import 'package:permission_handler/permission_handler.dart';

/// Result of a permission check, distinguishing "denied" from
/// "permanently denied" so the UI can react correctly (see spec §Permissions).
enum PermissionResult { granted, denied, permanentlyDenied }

class PermissionUtils {
  PermissionUtils._();

  static Future<PermissionResult> requestMicrophone() =>
      _request(Permission.microphone);

  static Future<PermissionResult> requestCamera() =>
      _request(Permission.camera);

  /// Requests both mic + camera together (used before a video call).
  static Future<bool> requestForVideoCall() async {
    final mic = await requestMicrophone();
    final cam = await requestCamera();
    return mic == PermissionResult.granted && cam == PermissionResult.granted;
  }

  static Future<bool> requestForAudioCall() async {
    final mic = await requestMicrophone();
    return mic == PermissionResult.granted;
  }

  static Future<PermissionResult> _request(Permission permission) async {
    final status = await permission.request();
    if (status.isGranted) return PermissionResult.granted;
    if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }
}
