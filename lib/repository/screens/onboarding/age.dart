import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/onboarding/onboarding_top_bar.dart';
import 'package:zyra_final/repository/screens/onboarding/start_journey.dart';


class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key});

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  int selectedYear = 2000;

  final int startYear = 1970;
  final int endYear = DateTime.now().year;

  late FixedExtentScrollController yearController;

  @override
  void initState() {
    super.initState();
    yearController = FixedExtentScrollController(
      initialItem: selectedYear - startYear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            /// Back Button
            
             const OnboardingTopBar(currentStep: 4),


            const SizedBox(height: 10),

            /// Title
            const Text(
              "When were you born?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            /// Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Your cycle can change with age. Knowing it helps us make better predictions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// Year Picker
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ListWheelScrollView.useDelegate(
                    controller: yearController,
                    itemExtent: 60,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedYear = startYear + index;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      builder: (context, index) {
                        int year = startYear + index;

                        bool isSelected = year == selectedYear;

                        return Center(
                          child: Text(
                            year.toString(),
                            style: TextStyle(
                              fontSize: isSelected ? 30 : 22,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xff2F4F2F)
                                  : Colors.grey,
                            ),
                          ),
                        );
                      },
                      childCount: endYear - startYear + 1,
                    ),
                  ),

                  /// Center Highlight Box
                  Positioned(
                    child: Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xff6B8165).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  /// Top Fade
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.scaffoldBackground,
                            AppColors.scaffoldBackground.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  /// Bottom Fade
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.scaffoldBackground,
                            AppColors.scaffoldBackground.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// Continue Button
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: SizedBox(
                width: 280,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StartJourney(),
                          ),
                        );
                    print("Selected Year: $selectedYear");

                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 18, color: AppColors.buttonText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
