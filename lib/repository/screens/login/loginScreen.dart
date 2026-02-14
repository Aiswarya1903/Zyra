import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/login/login.dart';
import 'package:zyra_final/repository/screens/onboarding/onboarding.dart';


class Loginscreen extends StatelessWidget {
  const Loginscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [

            // Top Image Section
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(200),
                ),
                child: Image.asset(
                  "assets/images/splash.png",
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Middle Logo / Support Image
            const SizedBox(height: 20),
            Image.asset(
              "assets/images/support.png",
              width: 140,
            ),

            const Spacer(),

            // Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF95B289),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Navigate to Onboarding page
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (context) => const Onboarding(),
                    ),
                    );

                  },
                  child: const Text(
                    "Get Started",
                    style: TextStyle(
                      color: Color(0xFF3A4336),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Already user
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already a user? ",
                  style: TextStyle(fontSize: 14),
                ),
                GestureDetector(
                  onTap: () {
                    // Navigate to Login
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                      builder: (context) => const Login(),
                      ),
                    );
                  },
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
          const Spacer(),

          ],
        ),
      ),
    );
  }
}
