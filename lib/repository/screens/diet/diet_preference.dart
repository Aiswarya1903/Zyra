import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';

class DietPreferenceScreen extends StatefulWidget {
  const DietPreferenceScreen({super.key});

  @override
  State<DietPreferenceScreen> createState() => _DietPreferenceScreenState();
}

class _DietPreferenceScreenState extends State<DietPreferenceScreen> {
  String? selectedOption;

  String getMessage() {
    if (selectedOption == "Veg") {
      return "We’ll suggest balanced vegetarian meal plans to support your hormones and overall health.";
    } else if (selectedOption == "NonVeg") {
      return "You’ll receive personalized meal suggestions including protein-rich non-vegetarian options.";
    } else if (selectedOption == "Eggetarian") {
      return "We’ll recommend vegetarian meals along with egg-based protein options.";
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
        const SnackBar(content: Text("Please select your diet preference")),
      );
      return;
    }

    print("Diet Preference: $selectedOption");

    // Navigate to next screen
    // Example:
    // Navigator.push(context, MaterialPageRoute(builder: (_) => NextScreen()));
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
                "What is your diet preference?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D6D57),
                  fontFamily: 'Outfit',
                ),
              ),

              const SizedBox(height: 40),

              optionCard("Vegetarian", "Veg"),
              optionCard("Eggetarian", "Eggetarian"),
              optionCard("Non-Vegetarian", "NonVeg"),

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
                    "Save",
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
