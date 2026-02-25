import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;

  // Last 7 days data
  List<double> wellnessScores = [];
  List<double> sleepHours = [];
  List<double> waterIntake = [];
  List<double> moodScores = [];
  List<String> dayLabels = [];

  // Symptoms frequency
  Map<String, int> symptomFrequency = {};

  // Cycle history
  List<int> cycleLengths = [];
  String currentPhase = '';
  int cycleDay = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadWellnessData(),
        _loadCycleData(),
      ]);
    } catch (e) {
      debugPrint('Analytics load error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadWellnessData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List<double> ws = [];
    final List<double> sl = [];
    final List<double> wa = [];
    final List<double> mo = [];
    final List<String> labels = [];
    final Map<String, int> symFreq = {};

    // Fetch last 7 days
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final label = DateFormat('EEE').format(date); // Mon, Tue...

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyWellness')
          .doc(dateStr)
          .get();

      labels.add(label);

      if (doc.exists) {
        final data = doc.data()!;
        final mood = (data['mood'] as num?)?.toDouble() ?? 3;
        final water = (data['water'] as num?)?.toDouble() ?? 0;
        final sleep = (data['sleep'] as num?)?.toDouble() ?? 0;
        final syms = List<String>.from(data['symptoms'] ?? []);

        // Calculate wellness score on the fly
        int score = 0;
        if (sleep >= 7 && sleep <= 9) score += 30;
        else if (sleep >= 6) score += 20;
        else if (sleep >= 5) score += 10;
        if (water >= 8) score += 25;
        else if (water >= 6) score += 18;
        else if (water >= 4) score += 10;
        else score += 5;
        final mp = {1.0: 5, 2.0: 8, 3.0: 15, 4.0: 22, 5.0: 25};
        score += mp[mood] ?? 10;
        final heavy = syms.where((s) => s.toLowerCase() != 'none').length;
        if (heavy == 0) score += 20;
        else if (heavy == 1) score += 14;
        else if (heavy == 2) score += 8;
        else score += 3;

        ws.add(score.toDouble().clamp(0, 100));
        sl.add(sleep.clamp(0, 12));
        wa.add(water.clamp(0, 8));
        mo.add(mood.clamp(1, 5));

        // Count symptoms
        for (final s in syms) {
          if (s.toLowerCase() != 'none') {
            symFreq[s] = (symFreq[s] ?? 0) + 1;
          }
        }
      } else {
        ws.add(0);
        sl.add(0);
        wa.add(0);
        mo.add(3);
      }
    }

    if (mounted) {
      setState(() {
        wellnessScores = ws;
        sleepHours = sl;
        waterIntake = wa;
        moodScores = mo;
        dayLabels = labels;
        symptomFrequency = symFreq;
      });
    }
  }

  Future<void> _loadCycleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return;
    final data = doc.data()!;

    List<DateTime> dates = [];
    if (data.containsKey('periodDates')) {
      dates = (data['periodDates'] as List)
          .map((t) => (t as Timestamp).toDate())
          .toList();
      dates.sort();
    }

    // Calculate cycle lengths from consecutive period dates
    final List<int> lengths = [];
    for (int i = 1; i < dates.length; i++) {
      final diff = dates[i].difference(dates[i - 1]).inDays;
      if (diff >= 20 && diff <= 60) lengths.add(diff);
    }

    // Current cycle day
    int day = 0;
    String phase = 'Unknown';
    if (dates.isNotEmpty) {
      day = DateTime.now().difference(dates.last).inDays + 1;
      day = ((day - 1) % 28) + 1;
      if (day <= 5) phase = 'Menstrual';
      else if (day <= 13) phase = 'Follicular';
      else if (day <= 16) phase = 'Ovulation';
      else phase = 'Luteal';
    }

    if (mounted) {
      setState(() {
        cycleLengths = lengths;
        cycleDay = day;
        currentPhase = phase;
      });
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  double get avgWellness {
    final valid = wellnessScores.where((s) => s > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  double get avgSleep {
    final valid = sleepHours.where((s) => s > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  double get avgWater {
    final valid = waterIntake.where((w) => w > 0).toList();
    if (valid.isEmpty) return 0;
    return valid.reduce((a, b) => a + b) / valid.length;
  }

  String _moodLabel(double score) {
    switch (score.round()) {
      case 1: return 'Very Low';
      case 2: return 'Low';
      case 3: return 'Neutral';
      case 4: return 'Good';
      case 5: return 'Great';
      default: return 'Neutral';
    }
  }

  String _moodEmoji(double score) {
    switch (score.round()) {
      case 1: return '😞';
      case 2: return '🙁';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😄';
      default: return '😐';
    }
  }

  Color _wellnessColor(double score) {
    if (score >= 75) return const Color(0xFF81C784);
    if (score >= 50) return const Color(0xFFFFD54F);
    return const Color(0xFFE57373);
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'Menstrual': return const Color(0xFFE57373);
      case 'Follicular': return const Color(0xFF81C784);
      case 'Ovulation': return const Color(0xFFFFD54F);
      case 'Luteal': return const Color(0xFF9575CD);
      default: return const Color(0xFF95B289);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDF4D3),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/background.png',
                fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              children: [
                _appBar(),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF95B289)))
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          color: const Color(0xFF95B289),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _summaryRow(),
                                const SizedBox(height: 20),
                                _sectionTitle('Wellness Score', '📊'),
                                const SizedBox(height: 10),
                                _wellnessChart(),
                                const SizedBox(height: 20),
                                _sectionTitle('Sleep Hours', '🌙'),
                                const SizedBox(height: 10),
                                _sleepChart(),
                                const SizedBox(height: 20),
                                _sectionTitle('Water Intake', '💧'),
                                const SizedBox(height: 10),
                                _waterChart(),
                                const SizedBox(height: 20),
                                _sectionTitle('Mood Tracker', '😊'),
                                const SizedBox(height: 10),
                                _moodChart(),
                                const SizedBox(height: 20),
                                _sectionTitle('Symptoms This Week', '🩺'),
                                const SizedBox(height: 10),
                                _symptomsCard(),
                                const SizedBox(height: 20),
                                _sectionTitle('Cycle Overview', '🌸'),
                                const SizedBox(height: 10),
                                _cycleCard(),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF5D6D57), size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'Your Analytics',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A4336),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadAllData,
            child: const Icon(Icons.refresh_rounded,
                color: Color(0xFF95B289), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3A4336),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF95B289).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Last 7 days',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              color: Color(0xFF5D6D57),
            ),
          ),
        ),
      ],
    );
  }

  // ── SUMMARY ROW ───────────────────────────────────────────────────────────

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
            child: _summaryCard('Avg Wellness',
                '${avgWellness.toStringAsFixed(0)}%',
                _wellnessColor(avgWellness), '📊')),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard('Avg Sleep',
                '${avgSleep.toStringAsFixed(1)}h',
                const Color(0xFF9575CD), '🌙')),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard('Avg Water',
                '${avgWater.toStringAsFixed(1)}/8',
                const Color(0xFF4FC3F7), '💧')),
      ],
    );
  }

  Widget _summaryCard(
      String label, String value, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ── CHART CONTAINER ───────────────────────────────────────────────────────

  Widget _chartContainer(Widget chart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF95B289).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: chart,
    );
  }

  // ── WELLNESS CHART ────────────────────────────────────────────────────────

  Widget _wellnessChart() {
    return _chartContainer(
      SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF95B289).withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= dayLabels.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(dayLabels[i],
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: Colors.grey)),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 25,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: Colors.grey),
                  ),
                  reservedSize: 28,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                spots: wellnessScores
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value))
                    .toList(),
                isCurved: true,
                color: const Color(0xFF95B289),
                barWidth: 3,
                isStrokeCapRound: true,
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
                  color: const Color(0xFF95B289).withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SLEEP CHART ───────────────────────────────────────────────────────────

  Widget _sleepChart() {
    return _chartContainer(
      SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 3,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF9575CD).withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= dayLabels.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(dayLabels[i],
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: Colors.grey)),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 3,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}h',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: Colors.grey),
                  ),
                  reservedSize: 30,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            maxY: 12,
            barGroups: sleepHours
                .asMap()
                .entries
                .map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value,
                          color: e.value >= 7
                              ? const Color(0xFF9575CD)
                              : const Color(0xFFE57373),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                        ),
                      ],
                    ))
                .toList(),
            // Reference line at 7 hours (recommended)
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 7,
                  color: const Color(0xFF9575CD).withOpacity(0.4),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        color: Color(0xFF9575CD)),
                    labelResolver: (_) => 'Goal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── WATER CHART ───────────────────────────────────────────────────────────

  Widget _waterChart() {
    return _chartContainer(
      SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF4FC3F7).withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= dayLabels.length)
                      return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(dayLabels[i],
                          style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10,
                              color: Colors.grey)),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: Colors.grey),
                  ),
                  reservedSize: 24,
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            maxY: 8,
            barGroups: waterIntake
                .asMap()
                .entries
                .map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value,
                          color: e.value >= 8
                              ? const Color(0xFF4FC3F7)
                              : const Color(0xFF4FC3F7).withOpacity(0.5),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8)),
                        ),
                      ],
                    ))
                .toList(),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 8,
                  color: const Color(0xFF4FC3F7).withOpacity(0.5),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 9,
                        color: Color(0xFF4FC3F7)),
                    labelResolver: (_) => 'Goal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── MOOD CHART ────────────────────────────────────────────────────────────

  Widget _moodChart() {
    return _chartContainer(
      Column(
        children: [
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFFFB74D).withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dayLabels.length)
                          return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(dayLabels[i],
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 10,
                                  color: Colors.grey)),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final emojis = {
                          1.0: '😞',
                          2.0: '🙁',
                          3.0: '😐',
                          4.0: '🙂',
                          5.0: '😄'
                        };
                        return Text(
                          emojis[value] ?? '',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 1,
                maxY: 5,
                lineBarsData: [
                  LineChartBarData(
                    spots: moodScores
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: const Color(0xFFFFB74D),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFFFFB74D),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFFB74D).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Today's mood summary
          if (moodScores.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _moodEmoji(moodScores.last),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  'Today: ${_moodLabel(moodScores.last)}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    color: Color(0xFF5D6D57),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── SYMPTOMS CARD ─────────────────────────────────────────────────────────

  Widget _symptomsCard() {
    if (symptomFrequency.isEmpty) {
      return _chartContainer(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              '🌿 No symptoms logged this week',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    final sorted = symptomFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFE57373),
      const Color(0xFFFFB74D),
      const Color(0xFF9575CD),
      const Color(0xFF4FC3F7),
      const Color(0xFF81C784),
      const Color(0xFFFF8A65),
      const Color(0xFF4DB6AC),
    ];

    return _chartContainer(
      Column(
        children: sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final sym = entry.value;
          final color = colors[i % colors.length];
          final maxCount = sorted.first.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    sym.key,
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: Color(0xFF3A4336),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: sym.value / maxCount,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${sym.value}x',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── CYCLE CARD ────────────────────────────────────────────────────────────

  Widget _cycleCard() {
    final pColor = _phaseColor(currentPhase);
    final avgCycle = cycleLengths.isEmpty
        ? 28
        : cycleLengths.reduce((a, b) => a + b) ~/ cycleLengths.length;

    return _chartContainer(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current phase row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: pColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pColor.withOpacity(0.4)),
                ),
                child: Text(
                  currentPhase.isEmpty ? 'No data yet' : '$currentPhase Phase',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: pColor,
                  ),
                ),
              ),
              const Spacer(),
              if (cycleDay > 0)
                Text(
                  'Day $cycleDay',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF3A4336),
                  ),
                ),
            ],
          ),

          if (cycleDay > 0) ...[
            const SizedBox(height: 16),
            // Cycle progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: cycleDay / avgCycle,
                backgroundColor: pColor.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(pColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Day 1',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: Colors.grey)),
                Text('Day $avgCycle',
                    style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: Colors.grey)),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Phase timeline
          Row(
            children: [
              _phaseChip('🌸', 'Menstrual', '1–5', const Color(0xFFE57373)),
              const SizedBox(width: 6),
              _phaseChip(
                  '🌱', 'Follicular', '6–13', const Color(0xFF81C784)),
              const SizedBox(width: 6),
              _phaseChip('🌟', 'Ovulation', '14–16', const Color(0xFFFFD54F)),
              const SizedBox(width: 6),
              _phaseChip('🍂', 'Luteal', '17–28', const Color(0xFF9575CD)),
            ],
          ),

          if (cycleLengths.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _cycleStat('Avg Cycle', '${avgCycle}d'),
                _cycleStat('Shortest', '${cycleLengths.reduce((a, b) => a < b ? a : b)}d'),
                _cycleStat('Longest', '${cycleLengths.reduce((a, b) => a > b ? a : b)}d'),
                _cycleStat('Cycles Logged', '${cycleLengths.length}'),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Text(
              'Log more period dates to see your cycle history',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _phaseChip(String emoji, String name, String days, Color color) {
    final isCurrentPhase = currentPhase == name;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isCurrentPhase ? color.withOpacity(0.2) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentPhase ? color : color.withOpacity(0.2),
            width: isCurrentPhase ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              days,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cycleStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF3A4336),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}