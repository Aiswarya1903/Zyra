import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current logged user id
  static String getUserId() {
    return _auth.currentUser!.uid;
  }

  // Create user document (called after signup)
  static Future<void> createUserDocument(
      String name, String email) async {
    String userId = _auth.currentUser!.uid;

    await _firestore.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'onboardingStep': 0,
    });
  }

  // Update onboarding step
  static Future<void> updateStep(int step) async {
    String userId = _auth.currentUser!.uid;

    await _firestore
        .collection('users')
        .doc(userId)
        .set({
      'onboardingStep': step,
    }, SetOptions(merge: true));
  }
}
