import 'package:firebase_auth/firebase_auth.dart';


class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  

  // SIGN UP (called after onboarding)
  static Future<void> signUp(String email, String password) async {
  await _auth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
}


  // LOGIN (existing user)
  static Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
}
