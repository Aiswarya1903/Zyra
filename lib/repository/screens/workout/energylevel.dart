import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/sleep/sleep.dart';

class EnergyImpactScreen extends StatefulWidget {
  const EnergyImpactScreen({super.key});

  @override
  State<EnergyImpactScreen> createState() => _EnergyImpactScreenState();
}

class _EnergyImpactScreenState extends State<EnergyImpactScreen> {
  String? selectedOption;

  String getMessage() {
    if (selectedOption == "Yes") {
      return "We’ll adjust workout intensity and daily recommendations based on your energy changes during the cycle.";
    } else if (selectedOption == "No") {
      return "Great! We’ll keep your activity plans consistent while tracking your overall wellness.";
    } else if (selectedOption == "NotSure") {
      return "No worries! We’ll help you track energy patterns and understand changes over time.";
    }
    return "";
  }

  Widget optionCard(String title, String value) {
    bool isSelected = selectedOption == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = value;
        });
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 124, 149, 113)
              : const Color(0xE8EDF4D3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D6D57),
                fontFamily: 'Outfit',
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  getMessage(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF3A4336),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void onSave() {
    if (selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an option")),
      );
      return;
    }

    print("Energy Impact: $selectedOption");

    Navigator.push(context,
    MaterialPageRoute(
      builder: (context)=>SleepImpactScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              const Text(
                "Does your cycle impact your energy or activity levels?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D6D57),
                  fontFamily: 'Outfit',
                ),
              ),

              const SizedBox(height: 40),

              optionCard("Yes", "Yes"),
              optionCard("No", "No"),
              optionCard("I’m not sure", "NotSure"),

              const Spacer(),

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
                  onPressed: onSave,
                  child: const Text(
                    "Next",
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.buttonText,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
