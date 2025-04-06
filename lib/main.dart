import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  await authService.init(); // Await before runApp to ensure user state is ready

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
          value: authService,
        ),
        ProxyProvider<AuthService, ApiService>(
          update: (context, auth, _) => ApiService(auth),
        ),
        Provider<LocationService>(
          create: (_) => LocationService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
