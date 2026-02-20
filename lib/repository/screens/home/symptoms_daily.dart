import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final List<String> symptoms = [
    "None",
    "Cramps",
    "Bloating",
    "Headache",
    "Acne",
    "Fatigue",
    "Anxiety",
    "Cravings",
    "Mood Swings",
    "Breast Tenderness",
    "Back Pain",
  ];

  Set<String> selectedSymptoms = {};

  @override
  void initState() {
    super.initState();
    fetchSymptomsFromFirestore();
  }

  void toggleSymptom(String symptom) {
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

  // FIX: Fetch from dailyWellness/{today} instead of dailyLogs
  Future<void> fetchSymptomsFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .get();

    if (doc.exists && doc.data()!.containsKey('symptoms')) {
      List list = doc['symptoms'] ?? [];
      setState(() {
        selectedSymptoms = list.cast<String>().toSet();
      });
    }
  }

  // FIX: Save to dailyWellness/{today} with merge — same doc as sleep/water/mood
  Future<void> saveSymptoms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .set({
          'symptoms': selectedSymptoms.toList(),
          'date': Timestamp.now(),
        }, SetOptions(merge: true));

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFD3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Image.asset("assets/images/symptom.png", height: 180),

              const SizedBox(height: 10),

              const Text(
                "How are you feeling?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                "Log your symptoms today",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 20),

              Center(
                child: Container(
                  width: 360,
                  height: 360,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF95B289).withOpacity(0.25),
                  ),
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: symptoms.map((symptom) {
                        bool isSelected = selectedSymptoms.contains(symptom);
                        return GestureDetector(
                          onTap: () => toggleSymptom(symptom),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.buttonColor
                                  : AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF95B289)),
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
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF95A889),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: saveSymptoms,
                child: const Text(
                  "Save",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}