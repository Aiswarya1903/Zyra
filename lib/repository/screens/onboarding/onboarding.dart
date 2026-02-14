import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/onboarding/weight_screen.dart';
import 'package:zyra_final/repository/screens/onboarding/onboarding_top_bar.dart';


class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF95B289),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            /// Progress Line (Step 1)
            const OnboardingTopBar(currentStep: 1),

            /// Top Image
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Image.asset(
                "assets/images/Onboarding.png",
                fit: BoxFit.cover,
              ),
            ),

            /// Form Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    TextField(
                      decoration: _inputDecoration("Enter email"),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      decoration: _inputDecoration("Enter name"),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      obscureText: true,
                      decoration: _inputDecoration("Password"),
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      obscureText: true,
                      decoration: _inputDecoration("Re-enter password"),
                    ),
                    const SizedBox(height: 30),

                    /// Next Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const WeightScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Next",
                          style: TextStyle(
                              fontSize: 16, color:AppColors.buttonText),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
