import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'models/call_model.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/contacts_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/call/incoming_call_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/calling_service.dart';
import 'services/notification_service.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (error) {
    runApp(StartupErrorApp(error: error));
    return;
  }

  runApp(const ConnectCallApp());

  unawaited(_initializeOptionalServices());
}

Future<void> _initializeOptionalServices() async {
  try {
    await CallingService.instance.initializeEngine();
  } catch (error) {
    debugPrint('Agora initialization failed: $error');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (error) {
    debugPrint('Notification initialization failed: $error');
  }
}

class StartupErrorApp extends StatelessWidget {
  final Object? error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'App setup is incomplete',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectCallApp extends StatelessWidget {
  const ConnectCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactsProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const _AuthenticatedShell();
    }
  }
}

class _AuthenticatedShell extends StatefulWidget {
  const _AuthenticatedShell();

  @override
  State<_AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<_AuthenticatedShell> {
  String? _handledCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _listenForIncomingCalls(),
    );
  }

  void _listenForIncomingCalls() {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;
    context.read<CallProvider>().incomingCallStream(uid).listen((call) async {
      if (call == null) return;
      if (_handledCallId == call.id) return; // already showing/handled
      _handledCallId = call.id;

      await NotificationService.instance.showIncomingCall(
        callerName: call.callerName,
        isVideo: call.type == CallType.video,
      );

      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) return;
      await navigator.push(
        MaterialPageRoute(builder: (_) => IncomingCallScreen(call: call)),
      );

      _handledCallId = null;
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
