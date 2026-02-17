import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ZyraCalendar extends StatefulWidget {
  final Set<DateTime> periodDays;
  final Set<DateTime> predictedDays;
  final Set<DateTime> ovulationDays; // not used now (kept for compatibility)
  final Function(DateTime)? onDaySelected;

  const ZyraCalendar({
    super.key,
    required this.periodDays,
    required this.predictedDays,
    required this.ovulationDays,
    this.onDaySelected,
  });

  @override
  State<ZyraCalendar> createState() => _ZyraCalendarState();
}

class _ZyraCalendarState extends State<ZyraCalendar> {
  DateTime _focusedDay = DateTime.now();

  bool contains(Set<DateTime> set, DateTime day) {
    return set.any((d) => isSameDay(d, day));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
        rowHeight: 44,

        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });

          if (widget.onDaySelected != null) {
            widget.onDaySelected!(selectedDay);
          }
        },

        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronVisible: true,
          rightChevronVisible: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
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
          rangeHighlightColor: Colors.transparent,
        ),

        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            bool isToday = isSameDay(day, DateTime.now());

            // 1. Actual period (highest priority)
            if (contains(widget.periodDays, day)) {
              return _circleDay(
                day,
                const Color(0xFF9E4B6E),
                filled: true,
              );
            }

            // 2. Predicted period → border circle
            if (contains(widget.predictedDays, day)) {
              return _borderCircleDay(
                day,
                const Color(0xFF9E4B6E),
              );
            }

            // 3. Today (only if not period/predicted)
            if (isToday) {
              return _circleDay(
                day,
                const Color(0xFF95A889),
                filled: true,
              );
            }

            return null;
          },
        ),
      ),
    );
  }

  // Filled circle (actual period / today)
  Widget _circleDay(DateTime day, Color color, {bool filled = false}) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  // Border circle (predicted period)
  Widget _borderCircleDay(DateTime day, Color color) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
