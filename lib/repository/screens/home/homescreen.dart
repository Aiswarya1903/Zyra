import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyra_final/repository/screens/home/analytics.dart';
import 'package:zyra_final/repository/screens/home/diet.dart';
import 'package:zyra_final/repository/screens/home/workout.dart';
import 'package:zyra_final/repository/screens/periods/period_calendar.dart';

class ZyraHomePage extends StatefulWidget {
  const ZyraHomePage({super.key});

  @override
  State<ZyraHomePage> createState() => _ZyraHomePageState();
}

class _ZyraHomePageState extends State<ZyraHomePage> {
  String userName = "";
  int selectedIndex = 0;
  List<DateTime> periodDates = [];
  String currentPhase = "Loading...";
  double phaseProgress = 0.0;
  int cycleDay = 0;
  int cycleLength = 28; //by default if the data is not sufficient use 28 days
  int waterGlasses = 0;
  int sleepHours = 0;
  String mood = "Not set";
  DateTime? lifestyleDate;

  int getDaysUntilNextPeriod() {
    int days = cycleLength - cycleDay;
    if (days < 0) days = 0;
    return days;
  }

  final List<Widget> pages = [
    //const ZyraHomePage(), // Home
    const WorkoutScreen(),
    const DietScreen(),
    const AnalyticsScreen(),
  ];

  String getDay() {
    return DateFormat('EEEE').format(DateTime.now());
  }

  String getDate() {
    return DateFormat('dd MMM yyyy').format(DateTime.now());
  }

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

      // 1. Get dynamic cycle length
      cycleLength = getCycleLength(periodDates);

      // 2. Get cycle day
      cycleDay = getCycleDay(periodDates, cycleLength);

      // 3. Get phase
      currentPhase = getCurrentPhaseFromDay(cycleDay);

      // 4. Dynamic progress
      phaseProgress = cycleDay / cycleLength;

      setState(() {});
    }
  }

  void _showWaterCompletedPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
        );
      },
    );
  }

  Future<void> _showWaterPopup() async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Glass Button
                    GestureDetector(
                      onTap: () {
                        if (waterGlasses < 8) {
                          setState(() {
                            waterGlasses++;
                          });

                          print("Saving water: $waterGlasses"); // ADD THIS

                          saveLifestyleData();
                        }

                        setDialogState(() {});
                        // If goal reached
                        if (waterGlasses == 8) {
                          Navigator.pop(context); // close water popup
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
              );
            },
          ),
        );
      },
    );
  }

  Future<void> fetchLifestyleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()!.containsKey('lifestyle')) {
      Map data = doc['lifestyle'];

      waterGlasses = data['water'] ?? 0;
      sleepHours = data['sleep'] ?? 0;
      mood = data['mood'] ?? "Not set";

      Timestamp? ts = data['date'];
      if (ts != null) {
        lifestyleDate = ts.toDate();
      }

      // DAILY RESET
      if (lifestyleDate == null || !isSameDay(lifestyleDate!, DateTime.now())) {
        waterGlasses = 0;
        sleepHours = 0;
        mood = "Not set";

        await saveLifestyleData();
      }

      setState(() {});
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> saveLifestyleData() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    print("User not logged in");
    return;
  }

  print("Saving to Firestore for UID: ${user.uid}");

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'lifestyle': {
      'water': waterGlasses,
      'sleep': sleepHours,
      'mood': mood,
      'date': Timestamp.fromDate(DateTime.now()),
    }
  }, SetOptions(merge: true));

  print("Saved successfully");
}


  //calculate cycle day
  int getCycleDay(List<DateTime> dates, int cycleLength) {
    if (dates.isEmpty) return 0;

    // Sort dates
    dates.sort();

    // Find latest date selected
    DateTime latestDate = dates.last;

    // Find first day of that period block
    DateTime periodStart = latestDate;

    for (int i = dates.length - 1; i >= 0; i--) {
      if (latestDate.difference(dates[i]).inDays <= 5) {
        periodStart = dates[i];
      } else {
        break;
      }
    }

    int day = DateTime.now().difference(periodStart).inDays + 1;

    // Keep within cycle length
    day = ((day - 1) % cycleLength) + 1;

    return day;
  }

  //get cycle length dynamically
  int getCycleLength(List<DateTime> dates) {
    if (dates.length < 2) return 28; // default if not enough data

    dates.sort();

    DateTime last = dates[dates.length - 1];
    DateTime previous = dates[dates.length - 2];

    int length = last.difference(previous).inDays;

    // Safety limits (avoid wrong data)
    if (length < 20 || length > 60) return 28;

    return length;
  }

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchPeriodDates();
    fetchLifestyleData();
  }

  /// Fetch name from Firestore
  Future<void> fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          userName = doc['name'] ?? "";
        });
      }
    }
  }

  /// Time-based greeting
  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Fixed Background
          Positioned.fill(
            child: Image.asset(
              "assets/images/background.png",
              fit: BoxFit.cover,
            ),
          ),

          /// Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Navbar
                  _header(context),

                  const SizedBox(height: 20),

                  /// Phase Section
                  _phaseSection(),

                  const SizedBox(height: 20),

                  /// Lifestyle
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
                          await _showWaterPopup();
                          fetchLifestyleData(); // refresh UI from Firebase
                        },
                        child: _lifestyleCard("assets/images/water.png"),
                      ),
                      _lifestyleCard("assets/images/sleep.png"),
                      _lifestyleCard("assets/images/meditation.png"),
                    ],
                  ),

                  const SizedBox(height: 25),

                  /// Discipline
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

  /// Navbar
  Widget _header(BuildContext context) {
    return Row(
      children: [
        /// Profile (Logout)
        GestureDetector(
          onTap: () async {
            bool? confirm = await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
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
                );
              },
            );

            if (confirm == true) {
              await FirebaseAuth.instance.signOut();
            }
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

        /// Center - Day & Date
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

        /// Calendar
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PeriodCalendarScreen(),
              ),
            );

            // Refresh data when coming back
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

  /// Phase Section
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
                currentPhase.split(" ")[0] + "\nPhase",
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
                _lifestyleItem("💧", "$waterGlasses / 8 glass"),
                _divider(),
                _lifestyleItem("🌙", "$sleepHours hrs"),
                _divider(),
                _lifestyleItem("😊", mood),
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

  Widget _divider() {
    return Container(height: 30, width: 1, color: const Color(0xFF95B289));
  }

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

  Widget _disciplineSection() {
    return Row(
      children: [
        Expanded(
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF95B289), width: 2),
                  image: const DecorationImage(
                    image: AssetImage("assets/images/analytics.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 95,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF95B289), width: 2),
                  image: const DecorationImage(
                    image: AssetImage("assets/images/food.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
          _navItem("assets/images/home_nav.png", -1),
          _navItem("assets/images/workout_nav.png", 0),
          _navItem("assets/images/diet_nav.png", 1),
          _navItem("assets/images/analytics_na.png", 2),
        ],
      ),
    );
  }

  Widget _navItem(String image, int index) {
    bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) return;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => pages[index]),
        );
      },
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
}
