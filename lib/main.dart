import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/create_ride_screen.dart';
import 'screens/ride_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAh1iLwWMkbI8UYhlK1oaQoZwuCNbE9x80",
      authDomain: "transport-sharing-app.firebaseapp.com",
      projectId: "transport-sharing-app",
      storageBucket: "transport-sharing-app.appspot.com",
      messagingSenderId: "457231856077",
      appId: "1:457231856077:web:2a259b3f91204c83641484",
      measurementId: "G-TZPHRVS0QG",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride Share App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(), // Login Screen
        '/signup': (context) => SignupScreen(), // Signup Screen
        '/home': (context) => RideListScreen(), // Home Screen (Ride List)
        '/create-ride': (context) => CreateRideScreen(), // Create Ride Screen
      },
    );
  }
}