import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/models/user_data.dart';
import 'package:zyra_final/repository/screens/workout/energylevel.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  String? selectedLevel;

  String getMessage() {
  if (selectedLevel == "Beginner") {
    return "We’ll suggest light workouts including walking, stretching, yoga, and basic strength training using bodyweight exercises.";
  } else if (selectedLevel == "Intermediate") {
    return "You’ll get moderate workouts including strength training, core exercises, and regular cardio routines.";
  } else if (selectedLevel == "Advanced") {
    return "We’ll provide high-intensity workouts, advanced strength training, and challenging fitness programs.";
  }
  return "";
}

  Widget optionCard(String title, String value) {
    bool isSelected = selectedLevel == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLevel = value;
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void onSave() {
    if (selectedLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your activity level")),
      );
      return;
    }

    // Save this later to Firebase / local storage
    UserData.activityLevel=selectedLevel;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnergyImpactScreen(),
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
                "What is your activity level?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D6D57),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "How physically active you are in your daily life and workouts.",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),


              optionCard("Beginner", "Beginner"),
              optionCard("Intermediate", "Intermediate"),
              optionCard("Advanced", "Advanced"),

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
