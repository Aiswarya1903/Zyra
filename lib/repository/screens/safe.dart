//homescreen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyra_final/repository/screens/home/analytics.dart';
import 'package:zyra_final/repository/screens/home/diet.dart';
import 'package:zyra_final/repository/screens/home/symptoms_daily.dart';
import 'package:zyra_final/repository/screens/home/workout.dart';
import 'package:zyra_final/repository/screens/meditation/meditation_home.dart';
import 'package:zyra_final/repository/screens/periods/period_calendar.dart';
import 'package:zyra_final/repository/screens/sleep/sleep_home.dart';
import 'dart:async';

class ZyraHomePage extends StatefulWidget {
  const ZyraHomePage({super.key});

  @override
  State<ZyraHomePage> createState() => _ZyraHomePageState();
}

class _ZyraHomePageState extends State<ZyraHomePage>
    with WidgetsBindingObserver {
  String userName = "";
  int selectedIndex = 0;
  List<DateTime> periodDates = [];
  String currentPhase = "Loading...";
  double phaseProgress = 0.0;
  int cycleDay = 0;
  int moodScore = 3;
  int cycleLength = 28;
  int waterGlasses = 0;
  double sleepHours = 0;
  List<String> todaySymptoms = [];
  StreamSubscription<DocumentSnapshot>? wellnessSubscription;
  String _lastTrackedDate = '';

  int getDaysUntilNextPeriod() {
    int days = cycleLength - cycleDay;
    if (days < 0) days = 0;
    return days;
  }

  String getDay() => DateFormat('EEEE').format(DateTime.now());
  String getDate() => DateFormat('dd MMM yyyy').format(DateTime.now());

  String getCurrentPhaseFromDay(int day) {
    if (day <= 5) return "Menstrual Phase";
    if (day <= 13) return "Follicular Phase";
    if (day == 14) return "Ovulation Phase";
    return "Luteal Phase";
  }

  Future<void> fetchPeriodDates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('periodDates')) {
      List<dynamic> timestamps = doc['periodDates'];
      periodDates = timestamps.map((t) => (t as Timestamp).toDate()).toList();
      cycleLength = getCycleLength(periodDates);
      cycleDay = getCycleDay(periodDates, cycleLength);
      currentPhase = getCurrentPhaseFromDay(cycleDay);
      phaseProgress = cycleDay / cycleLength;
      if (mounted) setState(() {});
    }

    // Save phase + cycleDay so all screens can read directly from Firestore
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'currentPhase': currentPhase,
      'cycleDay': cycleDay, 
      'cycleLength': cycleLength, 
      'phaseUpdatedOn': today, 
    });
  }

  void _showWaterCompletedPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFEDEFD3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🎉 Task Completed!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "You reached your daily water goal 💧",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF95A889),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Great!"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveDailyWellness() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .set({
          'mood': moodScore,
          'water': waterGlasses,
          //'sleep': sleepHours,
          'symptoms': todaySymptoms,
          'date': Timestamp.now(),
        }, SetOptions(merge: true));
  }

  Future<void> _refreshWellnessData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        moodScore = doc['mood'] ?? 3;
        waterGlasses = doc['water'] ?? 0;
        sleepHours = (doc['sleep'] as num?)?.toDouble() ?? 0;
        todaySymptoms = List<String>.from(doc['symptoms'] ?? []);
      });
    }
  }

  void _checkDateAndReinitialize() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (today != _lastTrackedDate) {
      _lastTrackedDate = today;
      listenTodayWellness();
    }
  }

  Future<void> _showMoodPopup() async {
    int tempMood = moodScore;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFD3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "How is your mood today?",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(5, (index) {
                      int value = index + 1;
                      List<String> emojis = ["😞", "🙁", "😐", "🙂", "😄"];
                      bool selected = tempMood == value;
                      return GestureDetector(
                        onTap: () => setDialogState(() => tempMood = value),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? const Color(0xFF9E4B6E)
                                : Colors.white,
                            border: Border.all(color: const Color(0xFF95B289)),
                          ),
                          child: Text(
                            emojis[index],
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF95A889),
                    ),
                    onPressed: () async {
                      moodScore = tempMood;
                      await saveDailyWellness();
                      if (mounted) Navigator.pop(context);
                      if (mounted) setState(() {});
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String getMoodEmoji() {
    switch (moodScore) {
      case 1:
        return "😞";
      case 2:
        return "🙁";
      case 3:
        return "😐";
      case 4:
        return "🙂";
      case 5:
        return "😄";
      default:
        return "😐";
    }
  }

  String getMoodText() {
    switch (moodScore) {
      case 1:
        return "Very Low";
      case 2:
        return "Low";
      case 3:
        return "Neutral";
      case 4:
        return "Good";
      case 5:
        return "Great";
      default:
        return "Neutral";
    }
  }

  String getSleepEmoji() {
    if (sleepHours == 0) return "😴";
    if (sleepHours < 5) return "😪";
    if (sleepHours < 7) return "🌙";
    if (sleepHours <= 9) return "😌";
    return "💤";
  }

  String getWaterEmoji() {
    if (waterGlasses == 0) return "🥤";
    if (waterGlasses < 4) return "💧";
    if (waterGlasses < 8) return "🚰";
    return "🏆";
  }

  Future<void> _showWaterPopup() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFEDEFD3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Water Tracker",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    if (waterGlasses < 8) {
                      final newCount = waterGlasses + 1;
                      setState(() => waterGlasses = newCount);
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        String today = DateFormat(
                          'yyyy-MM-dd',
                        ).format(DateTime.now());
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('dailyWellness')
                            .doc(today)
                            .set({'water': newCount}, SetOptions(merge: true));
                      }
                    }
                    setDialogState(() {});
                    if (waterGlasses == 8) {
                      Navigator.pop(context);
                      _showWaterCompletedPopup();
                    }
                  },
                  child: const Text("🥛", style: TextStyle(fontSize: 70)),
                ),
                const SizedBox(height: 10),
                Text(
                  "$waterGlasses glasses today",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF95A889),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int getCycleDay(List<DateTime> dates, int cycleLength) {
    if (dates.isEmpty) return 0;
    dates.sort();
    DateTime latestDate = dates.last;
    DateTime periodStart = latestDate;
    for (int i = dates.length - 1; i >= 0; i--) {
      if (latestDate.difference(dates[i]).inDays <= 5) {
        periodStart = dates[i];
      } else {
        break;
      }
    }
    int day = DateTime.now().difference(periodStart).inDays + 1;
    day = ((day - 1) % cycleLength) + 1;
    return day;
  }

  int getCycleLength(List<DateTime> dates) {
    if (dates.length < 2) return 28;
    dates.sort();
    DateTime last = dates[dates.length - 1];
    DateTime previous = dates[dates.length - 2];
    int length = last.difference(previous).inDays;
    if (length < 20 || length > 60) return 28;
    return length;
  }

  void listenTodayWellness() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    wellnessSubscription?.cancel();
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    wellnessSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dailyWellness')
        .doc(today)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted) return;
            if (doc.exists) {
              setState(() {
                moodScore = doc['mood'] ?? 3;
                waterGlasses = doc['water'] ?? 0;
                sleepHours = sleepHours = (doc['sleep'] as num?)?.toDouble() ?? 0;
                todaySymptoms = List<String>.from(doc['symptoms'] ?? []);
              });
            } else {
              setState(() {
                moodScore = 3;
                waterGlasses = 0;
                sleepHours = 0;
                todaySymptoms = [];
              });
            }
          },
          onError: (error) {
            debugPrint('Wellness stream error: $error');
            Future.delayed(const Duration(seconds: 3), listenTodayWellness);
          },
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastTrackedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    fetchUserName();
    fetchPeriodDates();
    listenTodayWellness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDateAndReinitialize();
    }
  }

  Future<void> fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => userName = doc['name'] ?? "");
      }
    }
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  // ── NAVIGATE TO SCREEN BY NAV INDEX ───────────────────────────────────────
  void _navigateTo(int index) {
    setState(() => selectedIndex = index);
    Widget screen;
    switch (index) {
      case 1:
        screen = const WorkoutScreen();
        break;
      case 2:
        screen = const DietScreen();
        break;
      case 3:
        screen = const AnalyticsScreen();
        break;
      default:
        return; // index 0 is home, no navigation needed
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      // Reset selected index back to home when returning
      if (mounted) setState(() => selectedIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/background.png",
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 20),
                  _phaseSection(),
                  const SizedBox(height: 20),
                  const Text(
                    "Lifestyle",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          _checkDateAndReinitialize();
                          await _showWaterPopup();
                        },
                        child: _lifestyleCard("assets/images/water.png"),
                      ),
                      GestureDetector(
                        onTap: () async {
                          _checkDateAndReinitialize();
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SleepPage(),
                            ),
                          );
                          
                        },
                        child: _lifestyleCard("assets/images/sleep.png"),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MeditationPage(),
                            ),
                          );
                        },
                        child: _lifestyleCard("assets/images/meditation.png"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Discipline",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _disciplineSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color.fromARGB(255, 237, 250, 209),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Color(0xFF3A4336),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: const Text(
                  "Do you want to Logout?",
                  style: TextStyle(color: Color(0xFF3A4336)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Logout"),
                  ),
                ],
              ),
            );
            if (confirm == true) await FirebaseAuth.instance.signOut();
          },
          child: Container(
            height: 64,
            width: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage("assets/images/profile.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              getDay(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A4336),
              ),
            ),
            Text(
              getDate(),
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PeriodCalendarScreen()),
            );
            fetchPeriodDates();
          },
          child: Container(
            height: 58,
            width: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage("assets/images/calender.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _phaseSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF95B289).withOpacity(0.25),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                "${currentPhase.split(" ")[0]}\nPhase",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 110,
                    width: 110,
                    child: CircularProgressIndicator(
                      value: phaseProgress,
                      strokeWidth: 12,
                      backgroundColor: const Color(0xFF95B289).withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF95B289),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Text("Period in"),
                      Text(
                        "${getDaysUntilNextPeriod()}",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text("days"),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF95B289)),
              color: Colors.white.withOpacity(0.7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _lifestyleItem(getWaterEmoji(), "$waterGlasses / 8 glass"),
                _divider(),
                _lifestyleItem(getSleepEmoji(), "${sleepHours % 1 == 0 ? sleepHours.toInt() : sleepHours} hrs"),
                _divider(),
                GestureDetector(
                  onTap: _showMoodPopup,
                  child: _lifestyleItem(getMoodEmoji(), getMoodText()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifestyleItem(String emoji, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 30, width: 1, color: const Color(0xFF95B289));

  Widget _lifestyleCard(String image) {
    return Container(
      height: 100,
      width: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF95B289), width: 2),
        image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
      ),
    );
  }

  // ── DISCIPLINE SECTION — workout and diet cards now navigate ──────────────
  Widget _disciplineSection() {
    return Row(
      children: [
        // Workout card — tapping navigates to WorkoutScreen
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => selectedIndex = 1);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkoutScreen()),
              ).then((_) {
                if (mounted) setState(() => selectedIndex = 0);
              });
            },
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF95B289), width: 2),
                image: const DecorationImage(
                  image: AssetImage("assets/images/workout.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              // Symptoms card
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                  );
                  await _refreshWellnessData();
                },
                child: Container(
                  height: 95,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF95B289),
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image: AssetImage("assets/images/analytics.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Diet card — tapping navigates to DietScreen
              GestureDetector(
                onTap: () {
                  setState(() => selectedIndex = 2);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DietScreen()),
                  ).then((_) {
                    if (mounted) setState(() => selectedIndex = 0);
                  });
                },
                child: Container(
                  height: 95,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF95B289),
                      width: 2,
                    ),
                    image: const DecorationImage(
                      image: AssetImage("assets/images/food.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //bottom navbar
  Widget _bottomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 209, 231, 200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem("assets/images/home_nav.png", 0),
          _navItem("assets/images/workout_nav.png", 1),
          _navItem("assets/images/diet_nav.png", 2),
          _navItem("assets/images/analytics_na.png", 3),
        ],
      ),
    );
  }

  Widget _navItem(String image, int index) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => _navigateTo(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? const Color(0xFF95B289).withOpacity(0.2)
                  : Colors.transparent,
            ),
            child: Image.asset(
              image,
              height: 26,
              width: 26,
              fit: BoxFit.contain,
              color: isSelected ? const Color(0xFF95B289) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    wellnessSubscription?.cancel();
    super.dispose();
  }
}
