import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services with error handling
  try {
    // Create an instance of AuthService and initialize it
    final authService = AuthService();
    await authService.init(); // Ensure init() is called

    runApp(
      MultiProvider(
        providers: [
          // Provide AuthService
          ChangeNotifierProvider<AuthService>(
            create: (_) => authService,
          ),
          // Provide ApiService (depends on AuthService)
          ProxyProvider<AuthService, ApiService>(
            update: (context, authService, _) => ApiService(authService),
          ),
          // Provide LocationService
          Provider<LocationService>(
            create: (_) => LocationService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Error initializing app: $e');
  }
}