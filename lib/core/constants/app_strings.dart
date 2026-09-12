/// All user-facing copy in one place — makes localisation and copy edits easy.
class AppStrings {
  AppStrings._();

  static const String appName = 'ConnectCall';
  static const String tagline = 'Connect with anyone, anywhere.';

  // Auth
  static const String login = 'Login';
  static const String createAccount = 'Create Account';
  static const String emailOrPhone = 'Email / Phone';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String name = 'Name';
  static const String email = 'Email';
  static const String noAccount = "Don't have an account? ";
  static const String haveAccount = 'Already have an account? ';

  // Errors
  static const String noInternet =
      'No internet connection. Please check your network.';
  static const String micPermissionDenied =
      'Microphone permission is required to make calls.';
  static const String cameraPermissionDenied =
      'Camera permission is required for video calls.';
  static const String permissionPermanentlyDenied =
      'Permission was permanently denied. Please enable it from app settings.';
  static const String callFailed = 'Call failed to connect. Please try again.';
  static const String userOffline = 'This user is currently offline.';
  static const String callRejected = 'Call was declined.';
  static const String genericError = 'Something went wrong. Please try again.';
}
