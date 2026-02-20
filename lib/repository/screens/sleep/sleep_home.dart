import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  // ✅ Tracks weekly data locally so graph updates instantly on save
  List<double> _weeklyData = List.filled(7, 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 18) return "Good Afternoon";
    return "Good Night";
  }

  String getImage() {
    int hour = DateTime.now().hour;
    if (hour < 18) return "assets/images/morning.jpg";
    return "assets/images/night.jpg";
  }

  // ✅ Load weekly data into state so we can update it instantly
  Future<void> _loadWeeklyData() async {
    final data = await getWeeklyData();
    if (mounted) {
      setState(() {
        _weeklyData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> saveTodaySleep(double hours) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(today)
          .set({'sleep': hours, 'date': Timestamp.now()}, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sleep_history')
          .doc(today)
          .set({
        'hours': hours,
        'date': today,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await deleteOldSleepData();

      // ✅ Update today's value in local weekly data instantly — no reload needed
      if (mounted) {
        setState(() {
          _weeklyData[6] = hours; // index 6 = today (rightmost on graph)
        });
      }
    } catch (e) {
      debugPrint('❌ Sleep save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteOldSleepData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sleep_history');
    final snapshot = await collection.get();
    if (snapshot.docs.length <= 7) return;
    List<QueryDocumentSnapshot> docs = snapshot.docs;
    docs.sort((a, b) => a.id.compareTo(b.id));
    int extra = docs.length - 7;
    for (int i = 0; i < extra; i++) {
      await docs[i].reference.delete();
    }
  }

  // ✅ Themed popup matching your app's green/cream style
  void showSleepDialog() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFEDEFD3), // ✅ cream background like other popups
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              const Text("😴", style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),

              const Text(
                "How many hours did\nyou sleep?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
              ),

              const SizedBox(height: 20),

              // ✅ Themed text field
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
                decoration: InputDecoration(
                  hintText: "0",
                  hintStyle: TextStyle(
                    fontSize: 32,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  suffixText: "hrs",
                  suffixStyle: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF95B289),
                    fontWeight: FontWeight.w600,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF95B289)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF95B289), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF95B289)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                "e.g. 7 or 7.5",
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),

              const SizedBox(height: 20),

              // ✅ Themed buttons row
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF95B289)),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Color(0xFF3A4336)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF95A889),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;

                        final double? hours = double.tryParse(controller.text.trim());
                        if (hours == null || hours <= 0 || hours > 24) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid number between 1–24'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(context); // close dialog first
                        await saveTodaySleep(hours); // then save + update graph
                      },
                      child: const Text(
                        "Save",
                        style: TextStyle(color: Color(0xFF3A4336), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<double>> getWeeklyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return List.filled(7, 0);
    DateTime now = DateTime.now();
    List<double> weekly = [];
    for (int i = 6; i >= 0; i--) {
      String date = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sleep_history')
          .doc(date)
          .get();
      weekly.add(doc.exists ? (doc['hours'] as num).toDouble() : 0);
    }
    return weekly;
  }

  Widget buildLineGraph() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF95B289)));
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: 2, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                if (value.toInt() >= days.length) return const Text('');
                return Text(days[value.toInt()], style: const TextStyle(fontSize: 12));
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 8,
              color: const Color(0xFF95B289),
              strokeWidth: 1.5,
              dashArray: [6, 4],
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_weeklyData.length, (i) => FlSpot(i.toDouble(), _weeklyData[i])),
            isCurved: true,
            color: const Color(0xFF95B289),
            barWidth: 4,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF95B289).withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGraphContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFD3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF95B289), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weekly Sleep",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3A4336))),
          const SizedBox(height: 6),
          const Text("Last 7 days overview",
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: buildLineGraph()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEFD3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(getGreeting(), style: const TextStyle(color: Color(0xFF3A4336))),
        iconTheme: const IconThemeData(color: Color(0xFF3A4336)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF95B289)),
                image: DecorationImage(image: AssetImage(getImage()), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF95B289),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              onPressed: showSleepDialog,
              child: const Text("Log Sleep", style: TextStyle(color: Color(0xFF3A4336))),
            ),
            const SizedBox(height: 20),
            buildGraphContainer(),
          ],
        ),
      ),
    );
  }
}