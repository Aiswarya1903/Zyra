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

  /// Greeting
  String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 18) return "Good Afternoon";
    return "Good Night";
  }

  String getImage() {
    int hour = DateTime.now().hour;
    if (hour < 18) {
      return "assets/images/morning.jpg";
    } else {
      return "assets/images/night.jpg";
    }
  }

  /// Save sleep
Future<void> saveTodaySleep(double hours) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Save for Home (daily wellness)
  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('dailyWellness')
      .doc(today)
      .set({
    'sleep': hours,
    'date': Timestamp.now(),
  }, SetOptions(merge: true));

  /// Save for weekly graph
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

  /// Keep only last 7 days
  await deleteOldSleepData();
}


  /// Delete sleep data older than 7 days
Future<void> deleteOldSleepData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final collection = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('sleep_history');

  final snapshot = await collection.get();

  // If 7 or less, do nothing
  if (snapshot.docs.length <= 7) return;

  // Sort by date (doc id = yyyy-MM-dd)
  List<QueryDocumentSnapshot> docs = snapshot.docs;
  docs.sort((a, b) => a.id.compareTo(b.id));

  // Delete oldest extra documents
  int extra = docs.length - 7;

  for (int i = 0; i < extra; i++) {
    await docs[i].reference.delete();
  }
}

  /// Popup
  void showSleepDialog() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("How many hours did you sleep?"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter hours"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              double hours = double.parse(controller.text);
              await saveTodaySleep(hours);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  /// Fetch last 7 days
  Future<List<double>> getWeeklyData() async {
    final user = FirebaseAuth.instance.currentUser;
    DateTime now = DateTime.now();
    List<double> weekly = [];

    for (int i = 6; i >= 0; i--) {
      String date = DateFormat('yyyy-MM-dd')
          .format(now.subtract(Duration(days: i)));

      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('sleep_history')
          .doc(date)
          .get();

      if (doc.exists) {
        weekly.add((doc['hours'] as num).toDouble());
      } else {
        weekly.add(0);
      }
    }
    return weekly;
  }

  /// Beautiful Line Graph
  Widget buildLineGraph() {
    return FutureBuilder<List<double>>(
      future: getWeeklyData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<double> data = snapshot.data!;

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: 10,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  reservedSize: 30,
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    return Text(
                      days[value.toInt()],
                      style: const TextStyle(fontSize: 12),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),

            /// Target line at 8 hrs
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 8,
                  color: const Color(0xFF95B289),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                )
              ],
            ),

            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  data.length,
                  (i) => FlSpot(i.toDouble(), data[i]),
                ),
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
      },
    );
  }

  /// Graph Container (inside card)
  Widget buildGraphContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFD3),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF95B289), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Weekly Sleep",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Last 7 days overview",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
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
        title: Text(
          getGreeting(),
          style: const TextStyle(color: Color(0xFF3A4336)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3A4336)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// Morning / Night Image
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF95B289)),
                image: DecorationImage(
                  image: AssetImage(getImage()),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// Log Sleep Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF95B289),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: showSleepDialog,
              child: const Text(
                "Log Sleep",
                style: TextStyle(color: Color(0xFF3A4336)),
              ),
            ),

            const SizedBox(height: 20),

            /// Beautiful Graph Card
            buildGraphContainer(),
          ],
        ),
      ),
    );
  }
}
