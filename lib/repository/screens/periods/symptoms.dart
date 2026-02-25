import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/models/user_data.dart';
import 'package:zyra_final/domain/services/user_services.dart';
import 'package:zyra_final/repository/screens/home/homescreen.dart';

class CycleSymptomsScreen extends StatefulWidget {
  const CycleSymptomsScreen({super.key});

  @override
  State<CycleSymptomsScreen> createState() => _CycleSymptomsScreenState();
}

class _CycleSymptomsScreenState extends State<CycleSymptomsScreen> {
  final List<String> symptoms = [
    "Cramps",
    "Spotting",
    "Bloating",
    "Mood swings",
    "Headaches",
    "Fatigue",
    "Tender breasts",
    "None",
  ];

  Set<String> selectedSymptoms = {};

  void toggleSelection(String symptom) {
    setState(() {
      if (symptom == "None") {
        selectedSymptoms.clear();
        selectedSymptoms.add("None");
      } else {
        selectedSymptoms.remove("None");
        if (selectedSymptoms.contains(symptom)) {
          selectedSymptoms.remove(symptom);
        } else {
          selectedSymptoms.add(symptom);
        }
      }
    });
  }
Future<void> onSave() async {
    if (selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one option")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Save all onboarding data (name, age, cycle info, etc.) to Firestore
      UserData.symptoms = selectedSymptoms.toList();
      await UserService.saveUserData();

      // 2. Also save symptoms as lifestyle data into dailyWellness subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(today)
          .set({
            'symptoms': selectedSymptoms.toList(),
            'date': Timestamp.now(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ZyraHomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget symptomChip(String symptom) {
    bool isSelected = selectedSymptoms.contains(symptom);

    return GestureDetector(
      onTap: () => toggleSelection(symptom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.buttonColor : AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.buttonColor),
        ),
        child: Text(
          symptom,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Image.asset("assets/images/symptom.png", height: 160),

            const SizedBox(height: 10),

            const Text(
              "Do you experience any\ncycle-related symptoms?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: Color(0xFF5D6D57),
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "Select all that apply",
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Outfit',
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Center(
                child: Container(
                  width: 340,
                  height: 340,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.buttonColor.withOpacity(0.25),
                  ),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: symptoms.map((s) => symptomChip(s)).toList(),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: 260,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: onSave,
                child: const Text(
                  "Finish",
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Outfit',
                    color: AppColors.buttonText,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}