import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:zyra_final/repository/screens/workout/level.dart';
import 'package:zyra_final/domain/models/user_data.dart';


class SelectPeriodCalendar extends StatefulWidget {
  const SelectPeriodCalendar({super.key});

  @override
  State<SelectPeriodCalendar> createState() => _SelectPeriodCalendarState();
}

class _SelectPeriodCalendarState extends State<SelectPeriodCalendar> {
  DateTime _focusedDay = DateTime.now();

  // Selected period days
  Set<DateTime> selectedDays = {};

  bool isSelected(DateTime day) {
    return selectedDays.any((d) => isSameDay(d, day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFD3),

      // No AppBar
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/mark.png", // change to your image name
                  height: 250,
                  fit: BoxFit.contain,
                ),

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

                    rangeSelectionMode: RangeSelectionMode.disabled,

                    selectedDayPredicate: (day) {
                      if (isSameDay(day, DateTime.now())) {
                        return false; // keep today green
                      }
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

                    // Header style
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      leftChevronVisible: true,
                      rightChevronVisible: true,
                      titleTextStyle: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),

                    // Weekdays style
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

                    // Calendar style
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
                      rangeHighlightColor: Colors.transparent,
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
                    "Next",
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

  void saveDates() {
  if (selectedDays.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select at least one date")),
    );
    return;
  }

  List<DateTime> periodDates = selectedDays.toList();
  periodDates.sort();

  // Save globally
  UserData.periodDates = periodDates;

  // Navigate to Workout Level screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ActivityLevelScreen(),
    ),
  );
}

}
