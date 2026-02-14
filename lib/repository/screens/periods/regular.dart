import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/repository/screens/periods/periodsdate.dart';

class RegularScreen extends StatefulWidget {
  const RegularScreen({super.key});

  @override
  State<RegularScreen> createState() => _RegularScreenState();
}

class _RegularScreenState extends State<RegularScreen> {
  String? selectedOption;

  String getMessage() {
    if (selectedOption == "Yes") {
      return "Great! We’ll help track your ovulation and give insights on your periods and lifestyle tips.";
    } else if (selectedOption == "No") {
      return "That’s okay. Even if your periods aren’t regular, we’ll help you understand body signals to watch.";
    } else if (selectedOption == "DontKnow") {
      return "No worries! We’ll help you track your cycle and understand your pattern over time.";
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
                fontFamily: 'Outfit',
                color: Color(0xFF5D6D57),
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  getMessage(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    color: Color(0xFF3A4336),
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

    print("Cycle Regular: $selectedOption");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Lastdate(),
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
                "Is your period regular?",
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D6D57),
                ),
              ),

              const SizedBox(height: 40),

              optionCard("Yes", "Yes"),
              optionCard("No", "No"),
              optionCard("Don’t Know", "DontKnow"),

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
                      fontFamily: 'Outfit',
                      color: AppColors.buttonText,
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
