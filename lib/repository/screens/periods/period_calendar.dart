import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/periods/edit_calendar.dart';
import 'package:zyra_final/repository/widgets/calendar_widget.dart';
class PeriodCalendarScreen extends StatefulWidget {
  const PeriodCalendarScreen({super.key});

  @override
  State<PeriodCalendarScreen> createState() => _PeriodCalendarScreenState();
}

class _PeriodCalendarScreenState extends State<PeriodCalendarScreen> {
  Set<DateTime> periodDays = {};
  Set<DateTime> predictedDays = {};
  Set<DateTime> ovulationDays = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDataFromFirestore();
  }

  /// Fetch period dates from Firestore
  Future<void> fetchDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('periodDates')) {
      List<dynamic> timestamps = doc['periodDates'];

      periodDays = timestamps
          .map((t) => (t as Timestamp).toDate())
          .toSet();

      calculatePredictions();
    }

    setState(() {
      isLoading = false;
    });
  }

  /// Prediction Logic
  void calculatePredictions() {
  if (periodDays.isEmpty) return;

  DateTime lastPeriod =
      periodDays.reduce((a, b) => a.isAfter(b) ? a : b);

  int cycleLength = 28;
  int periodLength = 5;

  predictedDays.clear();

  // Predict next 2 cycles (2 months)
  for (int cycle = 1; cycle <= 2; cycle++) {
    DateTime nextStart =
        lastPeriod.add(Duration(days: cycleLength * cycle));

    for (int i = 0; i < periodLength; i++) {
      predictedDays.add(nextStart.add(Duration(days: i)));
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFD3),
      appBar: AppBar(
        title: const Text("Cycle Calendar"),
        backgroundColor: const Color(0xFF95A889),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ZyraCalendar(
                  periodDays: periodDays,
                  predictedDays: predictedDays,
                  ovulationDays: ovulationDays,
                ),

                const SizedBox(height: 20),

                // Edit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF95A889),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditCalendar(),
                      ),
                    );

                    // Refresh after editing
                    periodDays.clear();
                    predictedDays.clear();
                    ovulationDays.clear();
                    isLoading = true;

                    fetchDataFromFirestore();
                  },
                  child: const Text(
                    "Edit Periods",
                    style: TextStyle(color: AppColors.buttonText),
                  ),
                )
              ],
            ),
    );
  }
}
