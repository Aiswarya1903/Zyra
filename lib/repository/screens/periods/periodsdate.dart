import 'package:flutter/material.dart';
import 'package:zyra_final/repository/screens/periods/edit_calendar.dart';
import 'package:zyra_final/repository/screens/periods/onboarding_calendar.dart';
import 'package:zyra_final/repository/screens/workout/level.dart';

class Lastdate extends StatelessWidget {
  const Lastdate({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xE8EDF4D3),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(height: height * 0.1),

                // Title
                const Text(
                  'Dont remember exactly \nwhen your last periods started?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5D6D57),
                    fontSize: 20,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: height * 0.05),

                // Image
                SizedBox(
                  height: height * 0.35,
                  width: width,
                  child: Image.asset(
                    "assets/images/date.png",
                    fit: BoxFit.contain,
                  ),
                ),

                SizedBox(height: height * 0.08),

                // Next Button
                SizedBox(
                  width: width * 0.65,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF95B289),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(31.5),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const OnboardingCalendar(),
                        ),
                      );
                    },
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        color: Color(0xFF3A4336),
                        fontSize: 20,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip (go back)
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, 
                    MaterialPageRoute(builder: 
                    (context)=>ActivityLevelScreen(),
                    ),
                  );
                  },
                  child: const Text(
                    'Skip anyway',
                    style: TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 16,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(height: height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
