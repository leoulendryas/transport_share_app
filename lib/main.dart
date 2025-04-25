import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final authService = AuthService();
  final locationService = LocationService();
  
  try {
    // Initialize auth service before running app
    await authService.init();
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ProxyProvider<AuthService, ApiService>(
            update: (context, auth, _) => ApiService(auth),
          ),
          Provider<LocationService>.value(value: locationService),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Initialization failed: $e'),
          ),
        ),
      ),
    );
  }
}