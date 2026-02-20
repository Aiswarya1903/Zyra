import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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

  /// ================================
  /// FIRESTORE LOAD
  /// ================================
  Future<void> loadExistingDatesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('periodDates')) {
      List<dynamic> timestamps = doc['periodDates'];

      selectedDays =
          timestamps.map((t) => (t as Timestamp).toDate()).toSet();
    }

    setState(() {
      isLoading = false;
    });
  }

  /// ================================
  /// HELPERS
  /// ================================

  bool isSelected(DateTime day) {
    return selectedDays.any((d) => isSameDay(d, day));
  }

  /// Count selected days in same month
  int getSelectedDaysInSameMonth(DateTime day) {
    return selectedDays.where((d) =>
        d.month == day.month && d.year == day.year).length;
  }

  /// Prevent future date selection
  bool isFutureDate(DateTime day) {
    DateTime today = DateTime.now();
    DateTime onlyToday =
        DateTime(today.year, today.month, today.day);
    DateTime selected =
        DateTime(day.year, day.month, day.day);

    return selected.isAfter(onlyToday);
  }

  /// ================================
  /// ALERTS (Zyra Theme)
  /// ================================

  void showFutureDateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFEDEFD3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Invalid Selection",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          content: const Text(
            "You cannot add period dates for future days.\nSelect only past or today's dates.",
            style: TextStyle(color: Color(0xFF3A4336)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xFF95A889)),
              ),
            )
          ],
        );
      },
    );
  }

  void showPeriodWarningDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFEDEFD3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Health Alert",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          content: const Text(
            "Periods usually last 2–7 days.\nHaving more than 8 days of bleeding is not considered normal.\n\nPlease consult a doctor.",
            style: TextStyle(color: Color(0xFF3A4336)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xFF95A889)),
              ),
            )
          ],
        );
      },
    );
  }

  /// ================================
  /// SAVE TO FIRESTORE
  /// ================================
  Future<void> saveDates() async {
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one date")),
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
        .set({
      'periodDates': firestoreDates,
    }, SetOptions(merge: true));

    Navigator.pop(context);
  }

  /// ================================
  /// UI
  /// ================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFD3),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      const Text(
                        "Edit your period days",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Calendar
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E8C8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime.now(), // 🚫 no future months
                          focusedDay: _focusedDay,

                          selectedDayPredicate: (day) =>
                              isSelected(day),

                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              // Block future date
                              if (isFutureDate(selectedDay)) {
                                showFutureDateDialog();
                                return;
                              }

                              if (isSelected(selectedDay)) {
                                selectedDays.removeWhere(
                                    (d) => isSameDay(d, selectedDay));
                              } else {
                                int count =
                                    getSelectedDaysInSameMonth(selectedDay);

                                if (count < 8) {
                                  selectedDays.add(selectedDay);
                                } else {
                                  showPeriodWarningDialog();
                                }
                              }

                              _focusedDay = focusedDay;
                            });
                          },

                          headerStyle: const HeaderStyle(
                            titleCentered: true,
                            formatButtonVisible: false,
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
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      /// Save Button
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
                            color: Colors.black,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
