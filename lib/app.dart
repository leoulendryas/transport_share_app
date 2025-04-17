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
      // Handle initial link if app was terminated
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleDeepLink(initialUri);

      // Listen for links while app is running
      _appLinks.uriLinkStream.listen(_handleDeepLink);
    } catch (e) {
      debugPrint('Deep linking initialization error: $e');
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
        if (token != null && navigatorKey.currentState?.mounted == true) {
          await authService.verifyEmail(token);
          navigatorKey.currentState?.pushReplacementNamed('/rides');
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
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isAuthenticated) {
      if (authService.email != null && !authService.isEmailVerified) {
        return const VerifyScreen(email: '', phone: null);
      }
      if (authService.phone != null && !authService.isPhoneVerified) {
        return const VerifyScreen(email: null, phone: '');
      }
      return const RideListScreen();
    }
    return const LoginScreen();
  }
}