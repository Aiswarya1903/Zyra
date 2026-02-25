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
  List<double> _weeklyData = List.filled(7, 0);
  bool _isLoading = true;

  // Today's logged sleep — null means not logged yet
  double? _todaySleep;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Load both weekly graph data AND today's sleep in one go
  Future<void> _loadAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Run both fetches in parallel
    final results = await Future.wait([
      getWeeklyData(),
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(today)
          .get(const GetOptions(source: Source.server))
          .catchError((_) => FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('dailyWellness')
              .doc(today)
              .get()),
    ]);

    if (!mounted) return;

    final weekly = results[0] as List<double>;
    final wellnessDoc = results[1] as DocumentSnapshot;
    final data = wellnessDoc.data() as Map<String, dynamic>? ?? {};
    final savedSleep = (data['sleep'] as num?)?.toDouble();

    setState(() {
      _weeklyData = weekly;
      _todaySleep = savedSleep; // null if not logged today
      _isLoading = false;
    });
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

  Future<void> saveTodaySleep(double hours) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(today)
          .set({'sleep': hours, 'date': Timestamp.now()},
              SetOptions(merge: true));

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

      if (mounted) {
        setState(() {
          _todaySleep = hours;
          _weeklyData[6] = hours;
        });
      }
    } catch (e) {
      debugPrint('Sleep save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> deleteOldSleepData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final collection = FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('sleep_history');
    final snapshot = await collection.get();
    if (snapshot.docs.length <= 7) return;
    List<QueryDocumentSnapshot> docs = snapshot.docs;
    docs.sort((a, b) => a.id.compareTo(b.id));
    int extra = docs.length - 7;
    for (int i = 0; i < extra; i++) {
      await docs[i].reference.delete();
    }
  }

  // Shows dialog — pre-fills current value if editing
  void _showSleepDialog({bool isEditing = false}) {
    final controller = TextEditingController(
      text: isEditing && _todaySleep != null
          ? (_todaySleep! % 1 == 0
              ? _todaySleep!.toInt().toString()
              : _todaySleep!.toString())
          : '',
    );

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFEDEFD3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isEditing ? "✏️" : "😴",
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              Text(
                isEditing
                    ? "Edit today's sleep"
                    : "How many hours did\nyou sleep?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3A4336),
                ),
                decoration: InputDecoration(
                  hintText: "0",
                  hintStyle: TextStyle(
                      fontSize: 32, color: Colors.grey.withOpacity(0.5)),
                  suffixText: "hrs",
                  suffixStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF95B289),
                      fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF95B289)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Color(0xFF95B289), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF95B289)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text("e.g. 7 or 7.5",
                  style: TextStyle(fontSize: 12, color: Colors.black45)),
              const SizedBox(height: 20),
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
                      child: const Text("Cancel",
                          style: TextStyle(color: Color(0xFF3A4336))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF95A889),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        final double? hours =
                            double.tryParse(controller.text.trim());
                        if (hours == null || hours <= 0 || hours > 24) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please enter a valid number between 1–24'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        await saveTodaySleep(hours);
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        isEditing ? "Update" : "Save",
                        style: const TextStyle(
                            color: Color(0xFF3A4336),
                            fontWeight: FontWeight.bold),
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
      String date =
          DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: i)));
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

  // ── SLEEP CARD: shows logged value or log prompt ──────────────────────────
  Widget _sleepStatusCard() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFEDEFD3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF95B289), width: 1.5),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF95B289)),
        ),
      );
    }

    // ── Already logged today ──────────────────────────────────────────────
    if (_todaySleep != null) {
      final display = _todaySleep! % 1 == 0
          ? '${_todaySleep!.toInt()}'
          : '$_todaySleep';

      final emoji = _todaySleep! < 5
          ? '😪'
          : _todaySleep! < 7
              ? '🌙'
              : _todaySleep! <= 9
                  ? '😌'
                  : '💤';

      final message = _todaySleep! < 5
          ? 'You need more rest tonight 💙'
          : _todaySleep! < 7
              ? 'A bit low — aim for 7–9 hours'
              : _todaySleep! <= 9
                  ? 'Great sleep! Your body thanks you 🌿'
                  : 'Quite a lot — are you feeling okay?';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF95B289).withOpacity(0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF95B289).withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 25)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3A4336),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'hrs',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF95B289),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            // Edit button — smaller, secondary style
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF95B289)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: Color(0xFF5D6D57)),
              label: const Text(
                'Edit',
                style: TextStyle(
                    color: Color(0xFF5D6D57),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              onPressed: () => _showSleepDialog(isEditing: true),
            ),
          ],
        ),
      );
    }

    // ── Not logged yet today ──────────────────────────────────────────────
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFD3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF95B289), width: 1.5),
      ),
      child: Column(
        children: [
          const Text('😴', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          const Text(
            "Not logged yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap below to log how many hours\nyou slept last night",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF95B289),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              elevation: 0,
            ),
            icon: const Icon(Icons.bedtime_outlined,
                size: 18, color: Color(0xFF3A4336)),
            label: const Text(
              'Log Sleep',
              style: TextStyle(
                  color: Color(0xFF3A4336), fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showSleepDialog(isEditing: false),
          ),
        ],
      ),
    );
  }

  Widget buildLineGraph() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF95B289)),
      );
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
            sideTitles: SideTitles(
                showTitles: true, interval: 2, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                if (value.toInt() >= days.length) return const Text('');
                return Text(days[value.toInt()],
                    style: const TextStyle(fontSize: 12));
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 8,
              color: const Color(0xFF95B289),
              strokeWidth: 1.5,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF95B289)),
                labelResolver: (_) => 'Goal',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _weeklyData.length,
              (i) => FlSpot(i.toDouble(), _weeklyData[i]),
            ),
            isCurved: true,
            color: const Color(0xFF95B289),
            barWidth: 4,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF95B289),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF95B289).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _graphCard() {
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
          ),
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
                color: Color(0xFF3A4336)),
          ),
          const SizedBox(height: 4),
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
        title: Text(
          getGreeting(),
          style: const TextStyle(color: Color(0xFF3A4336)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3A4336)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          children: [
            // Hero image
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF95B289)),
                image: DecorationImage(
                  image: AssetImage(getImage()),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sleep status card — shows value or log prompt
            _sleepStatusCard(),

            const SizedBox(height: 20),

            // Weekly graph
            _graphCard(),
          ],
        ),
      ),
    );
  }
}