import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _checkInitialLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // Handle links while app is running
    linkStream.listen((String? link) {
      if (link != null) {
        final uri = Uri.tryParse(link);
        if (uri != null) {
          _handleDeepLink(uri);
        } else {
          debugPrint('Failed to parse deep link: $link');
        }
      }
    });
  }

  Future<void> _checkInitialLink() async {
    // Handle links when app is launched from terminated state
    try {
      final Uri? initialUri = await getInitialUri();
      if (initialUri != null) _handleDeepLink(initialUri);
    } catch (e) {
      debugPrint('Initial link error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri? uri) async {
    if (uri == null) return;
    
    final authService = Provider.of<AuthService>(
      navigatorKey.currentContext!,
      listen: false,
    );

    if (uri.pathSegments.contains('verify-email')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        try {
          await authService.verifyEmail(token);
          navigatorKey.currentState?.pushReplacementNamed('/rides');
        } catch (e) {
          debugPrint('Email verification failed: $e');
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialLink();
    }
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Ride Share',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
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
      // Check if user needs verification
      if (authService.email != null && !authService.isEmailVerified) {
        return const VerifyScreen(email: '', phone: null);
      }
      if (authService.phone != null && !authService.isPhoneVerified) {
        return const VerifyScreen(email: null, phone: '');
      }
      return const RideListScreen();
    } else {
      return const LoginScreen();
    }
  }
}