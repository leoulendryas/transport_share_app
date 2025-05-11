import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized before using any async code
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exceptionAsString()}');
  };

  try {
    // Initialize services
    final authService = AuthService();
    final locationService = LocationService();

    print('Initializing authService...');
    await authService.init();
    print('AuthService initialized.');

    // Run the app inside the same zone as initialization
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ProxyProvider<AuthService, ApiService>(
            update: (_, auth, __) => ApiService(auth),
          ),
          Provider<LocationService>.value(value: locationService),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    // If initialization fails, display error
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              'Initialization failed:\n$e',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
