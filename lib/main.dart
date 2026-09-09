import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:velza/firebase_options.dart';
import 'package:velza/app_theme.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';
import 'package:velza/viewmodels/settings_viewmodel.dart';
import 'package:velza/services/notification_service.dart';
import 'package:velza/services/app_lock_service.dart';
import 'package:velza/views/auth/app_lock_screen.dart';
import 'package:velza/views/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase Init] Startup initialization warning: $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[FCM] Background handler registration warning: $e');
  }

  // Initialize App Lock Service
  await AppLockService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
      ],
      child: const VelzaApp(),
    ),
  );
}

class VelzaApp extends StatefulWidget {
  const VelzaApp({super.key});

  @override
  State<VelzaApp> createState() => _VelzaAppState();
}

class _VelzaAppState extends State<VelzaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AppLockService().onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      AppLockService().onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = Provider.of<SettingsViewModel>(context);

    return MaterialApp(
      title: 'Velza Chat',
      navigatorKey: NotificationService().navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: VelzaTheme.lightTheme,
      darkTheme: VelzaTheme.darkTheme,
      themeMode: settingsVM.themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        return AnimatedBuilder(
          animation: AppLockService(),
          builder: (context, _) {
            final isLocked = AppLockService().isLockEnabled && AppLockService().isCurrentlyLocked;
            return Stack(
              children: [
                if (child != null) child,
                if (isLocked)
                  const Positioned.fill(
                    child: AppLockScreen(),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}