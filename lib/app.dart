import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/rides/ride_list_screen.dart';
import 'screens/rides/create_ride_screen.dart';
import 'screens/sos/sos_screen.dart';
import 'services/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthService()..init(),
      child: MaterialApp(
        title: 'Ride Share',
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
    
    // Check if we're authenticated
    if (authService.isAuthenticated) {
      return const RideListScreen();
    } else {
      return const LoginScreen();
    }
  }
}