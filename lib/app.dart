import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/verify_screen.dart';
import 'screens/rides/ride_list_screen.dart';
import 'screens/rides/create_ride_screen.dart';
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
      final authService = Provider.of<AuthService>(
        navigatorKey.currentContext!,
        listen: false,
      );
  
      if (uri.pathSegments.contains('verify-email')) {
        final token = uri.queryParameters['token'];
        if (token != null) {
          try {
            await authService.verifyEmail(token);
          } catch (e) {
            debugPrint('Error during email verification: $e');
            // Even if there's an error, we still want to proceed
          } finally {
            if (navigatorKey.currentState?.mounted == true) {
              navigatorKey.currentState?.pushReplacementNamed('/rides');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Deep link handling error: $e');
      // If something went wrong before, still try to navigate to /rides
      if (navigatorKey.currentState?.mounted == true) {
        navigatorKey.currentState?.pushReplacementNamed('/rides');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Met Share',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/rides': (context) => const RideListScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/verify': (context) => const VerifyScreen(),
        '/create-ride': (context) => const CreateRideScreen(),
        '/sos': (context) => const SosScreen(rideId: 'defaultRideId'),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!authService.isInitialized) {
      await authService.init();
    }

    if (authService.isAuthenticated) {
      await authService.getToken();
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final authService = Provider.of<AuthService>(context);

    if (!authService.isAuthenticated) {
      return const LoginScreen();
    }

    if (authService.email != null && !authService.isEmailVerified) {
      return VerifyScreen(email: authService.email, phone: null);
    }

    if (authService.phone != null && !authService.isPhoneVerified) {
      return VerifyScreen(email: null, phone: authService.phone);
    }

    return const RideListScreen();
  }
}
