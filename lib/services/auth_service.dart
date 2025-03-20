import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Error signing up: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Error signing in: ${e.message}');
      return null;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}