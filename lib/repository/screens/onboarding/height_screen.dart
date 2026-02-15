import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/onboarding/age.dart';
import 'package:zyra_final/domain/models/user_data.dart';



class HeightScreen extends StatefulWidget {
  const HeightScreen({super.key});
  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  int selectedCm = 165;
  int selectedDecimal = 0;

  final FixedExtentScrollController cmController =
      FixedExtentScrollController(initialItem: 65);

  final FixedExtentScrollController decimalController =
      FixedExtentScrollController(initialItem: 0);

  @override
  Widget build(BuildContext context) {
    double height = selectedCm + (selectedDecimal / 10);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),

            const Spacer(),

            /// Title
            const Text(
              "How tall are you?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            /// Selected Height Display (Age-style elevation)
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
                "${height.toStringAsFixed(1)} cm",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff2F4F2F),
                ),
              ),
            ),

            const Spacer(),

            /// Bottom Card (Elevated instead of border)
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
                  /// Height Wheel
                  SizedBox(
                    height: 180,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        /// CM Wheel
                        SizedBox(
                          width: 120,
                          child: ListWheelScrollView.useDelegate(
                            controller: cmController,
                            itemExtent: 50,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedCm = 100 + index;
                              });
                            },
                            childDelegate:
                                ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                int value = 100 + index;
                                bool isSelected =
                                    value == selectedCm;

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
                            physics: const FixedExtentScrollPhysics(),
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
                          "cm",
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
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        double finalHeight =
                            selectedCm + (selectedDecimal / 10);
                        UserData.height=finalHeight;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AgeScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Next",
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.buttonText,
                        ),
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
