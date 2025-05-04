import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_screen.dart';
import 'screens/rides/ride_list_screen.dart';
import 'screens/rides/create_ride_screen.dart';
import 'screens/profile/profile_completion_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'services/auth_service.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleDeepLink(initialUri);
      _appLinks.uriLinkStream.listen(_handleDeepLink);
    } catch (e) {
      debugPrint('Deep linking error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    try {
      if (navigatorKey.currentContext == null) return;

      final authService = Provider.of<AuthService>(
        navigatorKey.currentContext!,
        listen: false,
      );

      if (uri.pathSegments.contains('verify-email')) {
        final token = uri.queryParameters['token'];
        if (token != null) {
          await authService.verifyEmail(token);
          if (authService.isAuthenticated && authService.isVerified) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/rides', 
              (route) => false
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Deep link handling error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Met Share',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.purple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: Colors.black,
        ),
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/rides': (context) => const RideListScreen(),
          '/verify': (context) => const VerifyScreen(),
          '/profile-complete': (context) => const ProfileCompletionScreen(), 
          '/create-ride': (context) => const CreateRideScreen(),
          '/sos': (context) => const SosScreen(rideId: 'defaultRideId'),
        },
        onGenerateRoute: (settings) {
          final authService = Provider.of<AuthService>(
            navigatorKey.currentContext!,
            listen: false,
          );

          // Route protection
          if (settings.name != '/login' && 
              settings.name != '/register' && 
              settings.name != '/verify' &&
              !authService.isAuthenticated) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }

          if (settings.name == '/rides' && !authService.isVerified) {
            return MaterialPageRoute(builder: (_) => const VerifyScreen());
          }

          // app.dart - onGenerateRoute
          if (settings.name == '/create-ride') {
            final auth = Provider.of<AuthService>(navigatorKey.currentContext!, listen: false);
            if (!auth.isIdVerified) {
              return MaterialPageRoute(builder: (_) => const ProfileCompletionScreen());
            }
          }

          return null;
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.init();

    if (mounted) {
      final route = authService.isAuthenticated 
          ? authService.isVerified
              ? authService.isIdVerified 
                  ? '/rides' 
                  : '/profile-complete'
              : '/verify'
          : '/login';

      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
      ),
    );
  }
}