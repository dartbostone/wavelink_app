Project description

ConnectCall is a 1-to-1 audio and video calling app built in Flutter for the Flutter Development Intern assignment. It covers the full user journey: sign up / log in, browse and search contacts, place or receive an audio or video call, control the call (mute, speaker, camera, camera switch), and review past calls in a history log — with real authentication, a real-time backend, and a real calling SDK rather than a static UI mock-up.

Features

All mandatory features from the assignment are implemented:

Auth: Firebase Authentication (email/password) — register, login, logout. Real auth, not mocked.
Users: live contact list (Firestore), online/offline presence, client-side search, user profile with edit.
Calling: 1-to-1 audio and video calls, incoming call screen with accept/reject, ringing/connected/ended lifecycle.
Call controls: mute/unmute, speaker on/off (audio), camera on/off + front/rear switch (video), end call.
Call history: caller/callee, type, time, duration, missed/declined indicator.
Permissions: mic/camera requested just-in-time, with granted / denied / permanently-denied handling.
Error handling: no-internet, permission-denied, call-failed, user-offline, call-rejected states all surface a real message instead of crashing.

Bonus features implemented:

Push/local notifications for incoming calls (Bonus 1 & 2) — see "Known limitations" for the one piece (waking a fully-killed app) that needs a server-side component not included here.
Dark mode (Bonus 3), persisted with shared_preferences.
Network quality indicator — Good/Fair/Poor (Bonus 9), sourced from Agora's onNetworkQuality callback.

Not implemented (out of scope for the time available): block user, recent contacts shortcut, call recording, group calling, screen sharing.

Flutter version

Target: Flutter 3.24+ / Dart 3.5+ (anything satisfying the environment: sdk: '>=3.3.0 <4.0.0' constraint in pubspec.yaml). Verify with flutter --version and run flutter upgrade if you're on something older.

Packages used
Package	Why
provider	State management (see "Architecture" below)
firebase_core, firebase_auth, cloud_firestore	Backend: auth + user/call data + call signaling
agora_rtc_engine	Real-time audio/video media
permission_handler	Mic/camera runtime permissions
connectivity_plus	Detects "no internet" for error states
flutter_local_notifications	Incoming-call notifications
shared_preferences	Persists the dark-mode choice
intl, uuid	Date formatting, call/channel IDs
Architecture
lib/
├── core/
│   ├── constants/   # colors, strings, light+dark theme
│   └── utils/       # validators, permission helper, date/duration formatting
├── models/          # UserModel, CallModel (+ CallType/CallStatus enums)
├── services/        # one class per backend concern — the only layer that
│                     # talks to Firebase/Agora/permission_handler directly
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── calling_service.dart      # signaling (Firestore) + media (Agora)
│   ├── call_history_service.dart
│   ├── connectivity_service.dart
│   └── notification_service.dart
├── providers/       # ChangeNotifiers that expose service state to widgets
│   ├── auth_provider.dart
│   ├── contacts_provider.dart
│   ├── call_provider.dart        # drives every call screen
│   └── theme_provider.dart
├── screens/         # one folder per spec screen (splash/auth/home/...)
├── widgets/         # shared, stateless UI pieces (buttons, tiles, states)
└── main.dart         # Firebase/Agora/notifications bootstrap + routing

State management: Provider (ChangeNotifier + MultiProvider). Chosen over Bloc/Riverpod/GetX because the app's state shape is simple (auth status, a contacts list, one active call at a time, a theme mode) and Provider keeps that mapped directly to idiomatic ChangeNotifiers without extra boilerplate or code generation — a reasonable fit for an app this size, while still being a "real" state-management solution rather than raw setState scattered across screens.

Where business logic lives: entirely in services/. Providers translate service streams/futures into ChangeNotifier state; screens only read providers via Provider/Consumer and never call Firebase or Agora directly (the one deliberate exception is VideoCallScreen, which reads CallingService.instance.engine to build the AgoraVideoView — rendering a live video surface is presentation-layer work that has to touch the engine object).

Backend used

Firebase — Authentication for sign-up/login, and Firestore for two collections:

users/{uid} — name, email, avatarUrl, isOnline, lastSeen.
calls/{callId} — caller/callee ids & names, call type, status, the Agora channel id, and timestamps. This single collection serves double duty as both the call signaling channel (the callee listens for new ringing documents; both sides watch status changes) and the call history (finished documents are simply queried back out).

Firebase was chosen because it needed no custom server, its real-time listeners are a natural fit for signaling, and it's explicitly listed as a suggested backend in the assignment.

Calling SDK used

Agora RTC Engine (agora_rtc_engine) handles the actual audio/video media. Reasoning:

It's a mature, well-documented Flutter plugin with a generous free tier — appropriate for an assignment/demo rather than production infrastructure.
Raw WebRTC would require running our own signaling + TURN/STUN infrastructure; Agora (like ZEGOCLOUD, Stream Video, LiveKit) provides that as a managed service, which is the right trade-off given "the goal is to demonstrate Flutter development, not backend engineering."
It reports live network quality out of the box, which directly enables Bonus 9.
