import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyra_final/repository/screens/home/analytics.dart';
import 'package:zyra_final/repository/screens/home/diet.dart';
import 'package:zyra_final/repository/screens/home/workout.dart';

class ZyraHomePage extends StatefulWidget {
  const ZyraHomePage({super.key});

  @override
  State<ZyraHomePage> createState() => _ZyraHomePageState();
  
}

class _ZyraHomePageState extends State<ZyraHomePage> {
  String userName = "";
  int selectedIndex = 0;

final List<Widget> pages = [
  const ZyraHomePage(),      // Home
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


  @override
  void initState() {
    super.initState();
    fetchUserName();
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
                      _lifestyleCard("assets/images/water.png"),
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
                  backgroundColor:
                      const Color.fromARGB(255, 237, 250, 209),
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
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
        ],
      ),

      const Spacer(),

        /// Calendar
        Container(
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
              const Text(
                "Follicular\nPhase",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 110,
                    width: 110,
                    child: CircularProgressIndicator(
                      value: 0.65,
                      strokeWidth: 12,
                      backgroundColor:
                          const Color(0xFF95B289).withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF95B289),
                      ),
                    ),
                  ),
                  const Column(
                    children: [
                      Text("Period in"),
                      Text(
                        "5",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("days"),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Color(0xFF95B289)),
              color: Colors.white.withOpacity(0.7),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("water"),
                VerticalDivider(width: 1),
                Text("sleep"),
                VerticalDivider(width: 1),
                Text("mood"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifestyleCard(String image) {
    return Container(
      height: 100,
      width: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF95B289), width: 2),
        image: DecorationImage(
          image: AssetImage(image),
          fit: BoxFit.cover,
        ),
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
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 10,
        )
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
    onTap: () {
      if (index == 0) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => pages[index],
        ),
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
            color: isSelected
                ? const Color(0xFF95B289)
                : Colors.grey,
          ),
        ),
      ],
    ),
  );
}

}
