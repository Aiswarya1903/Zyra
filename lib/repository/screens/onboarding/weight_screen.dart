import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/onboarding/height_screen.dart';
import 'package:zyra_final/repository/screens/onboarding/onboarding_top_bar.dart';


class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  int selectedKg = 60;
  int selectedDecimal = 0;

  final FixedExtentScrollController kgController =
      FixedExtentScrollController(initialItem: 30);

  final FixedExtentScrollController decimalController =
      FixedExtentScrollController(initialItem: 0);

  @override
  Widget build(BuildContext context) {
    double weight = selectedKg + (selectedDecimal / 10);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
           
            const OnboardingTopBar(currentStep: 2),

            const SizedBox(height: 60),

            const Spacer(),

            /// Title
            const Text(
              "How much do you weigh?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            /// Selected Weight Display (Age-style elevation)
            Container(
              width: 280,
              height: 65,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffEFF3E0),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                "${weight.toStringAsFixed(1)} kg",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff2F4F2F),
                ),
              ),
            ),

            const Spacer(),

            /// Bottom Card (Elevated)
            Container(
              padding: const EdgeInsets.only(top: 25, bottom: 30),
              decoration: BoxDecoration(
                color: const Color(0xffEFF3E0),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Wheel Picker
                  SizedBox(
                    height: 180,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        /// KG Wheel
                        SizedBox(
                          width: 110,
                          child: ListWheelScrollView.useDelegate(
                            controller: kgController,
                            itemExtent: 50,
                            physics:
                                const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedKg = 30 + index;
                              });
                            },
                            childDelegate:
                                ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                int value = 30 + index;
                                bool isSelected =
                                    value == selectedKg;

                                return Center(
                                  child: Text(
                                    value.toString(),
                                    style: TextStyle(
                                      fontSize:
                                          isSelected ? 26 : 22,
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
                              childCount: 121,
                            ),
                          ),
                        ),

                        const Text(
                          ".",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        /// Decimal Wheel
                        SizedBox(
                          width: 60,
                          child: ListWheelScrollView.useDelegate(
                            controller: decimalController,
                            itemExtent: 50,
                            physics:
                                const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedDecimal = index;
                              });
                            },
                            childDelegate:
                                ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                bool isSelected =
                                    index == selectedDecimal;

                                return Center(
                                  child: Text(
                                    index.toString(),
                                    style: TextStyle(
                                      fontSize:
                                          isSelected ? 26 : 22,
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
                              childCount: 10,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        const Text(
                          "kg",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff2F4F2F),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// Next Button
                  SizedBox(
                    width: 260,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        double finalWeight =
                            selectedKg + (selectedDecimal / 10);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                HeightScreen(weight: finalWeight),
                          ),
                        );
                      },
                      child: const Text(
                        "Next",
                        style: TextStyle(
                            fontSize: 18, color: AppColors.buttonText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
