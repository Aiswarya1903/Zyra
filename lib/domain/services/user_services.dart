import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zyra_final/domain/models/user_data.dart';

class UserService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save all onboarding data at once
  static Future<void> saveUserData() async {
    try {
      User? user = _auth.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      String uid = user.uid;

      await _firestore.collection('users').doc(uid).set({
        // Basic
        'name': UserData.name,
        'email': UserData.email,

        // Body
        'weight': UserData.weight,
        'height': UserData.height,
        'birthYear': UserData.birthYear,
        'age': UserData.age,

        // Cycle
        'cycleRegularity': UserData.cycleRegularity,
        'periodDates': UserData.periodDates
            .map((e) => Timestamp.fromDate(e))
            .toList(),

        // Lifestyle
        'activityLevel': UserData.activityLevel,
        'energyImpact': UserData.energyImpact,
        'sleepImpact': UserData.sleepImpact,
        'dietImpact': UserData.dietImpact,
        'dietPreference': UserData.dietPreference,

        // Health
        'symptoms': UserData.symptoms,

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true));

      print("User data saved successfully");
    } catch (e) {
      print("Error saving user data: $e");
    }
  }
}
