import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';

class EditCalendar extends StatefulWidget {
  const EditCalendar({super.key});

  @override
  State<EditCalendar> createState() => _EditCalendarState();
}

class _EditCalendarState extends State<EditCalendar> {
  DateTime _focusedDay = DateTime.now();

  // Selected period days
  Set<DateTime> selectedDays = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExistingDatesFromFirestore();
  }

  /// Fetch existing period dates from Firestore
  Future<void> loadExistingDatesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('periodDates')) {
      List<dynamic> timestamps = doc['periodDates'];

      selectedDays = timestamps
          .map((t) => (t as Timestamp).toDate())
          .toSet();
    }

    setState(() {
      isLoading = false;
    });
  }

  bool isSelected(DateTime day) {
    return selectedDays.any((d) => isSameDay(d, day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    
                      const SizedBox(height: 10),

                      const Text(
                        "Edit your period days",
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Outfit',
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Calendar Container
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E8C8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2035),
                          focusedDay: _focusedDay,
                          rangeSelectionMode:
                              RangeSelectionMode.disabled,

                          selectedDayPredicate: (day) {
                            return isSelected(day);
                          },

                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              if (isSelected(selectedDay)) {
                                selectedDays.removeWhere(
                                    (d) => isSameDay(d, selectedDay));
                              } else {
                                selectedDays.add(selectedDay);
                              }
                              _focusedDay = focusedDay;
                            });
                          },

                          headerStyle: const HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
                            titleTextStyle: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                            weekendStyle: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),

                          calendarStyle: const CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: Color(0xFF9E4B6E),
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Color(0xFF95A889),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Save Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF95A889),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: saveDates,
                        child: const Text(
                          "Save",
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Outfit',
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Save updated dates to Firestore
  Future<void> saveDates() async {
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select at least one date")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<Timestamp> firestoreDates =
        selectedDays.map((d) => Timestamp.fromDate(d)).toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'periodDates': firestoreDates,
    });

    Navigator.pop(context);
  }
}
