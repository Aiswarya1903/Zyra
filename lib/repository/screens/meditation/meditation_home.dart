import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'meditation_popup.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  String? selectedMood;
  String? selectedDuration;

  Map<String, List<Map<String, String>>> moodSessions = {
    "Anxiety": [
      {
        "duration": "5 min",
        "title": "Breathing Calm",
        "subtitle": "Slow your breath",
      },
      {
        "duration": "10 min",
        "title": "Mind Relax",
        "subtitle": "Ease anxious thoughts",
      },
      {
        "duration": "15 min",
        "title": "Deep Grounding",
        "subtitle": "Feel stable & calm",
      },
    ],
    "Stress": [
      {
        "duration": "5 min",
        "title": "Quick Relax",
        "subtitle": "Release tension",
      },
      {
        "duration": "10 min",
        "title": "Stress Relief",
        "subtitle": "Recommended session",
      },
      {
        "duration": "15 min",
        "title": "Deep Relax",
        "subtitle": "Full body calm",
      },
    ],
    "Sad": [
      {
        "duration": "5 min",
        "title": "Mood Lift",
        "subtitle": "Gentle positivity",
      },
      {
        "duration": "10 min",
        "title": "Emotional Balance",
        "subtitle": "Stabilize feelings",
      },
      {
        "duration": "15 min",
        "title": "Self Compassion",
        "subtitle": "Be kind to yourself",
      },
    ],
    "Lonely": [
      {
        "duration": "5 min",
        "title": "Self Connection",
        "subtitle": "Feel present",
      },
      {
        "duration": "10 min",
        "title": "Heart Calm",
        "subtitle": "Warm inner peace",
      },
      {
        "duration": "15 min",
        "title": "Deep Comfort",
        "subtitle": "Emotional support",
      },
    ],
    "Overthinking": [
      {
        "duration": "5 min",
        "title": "Mind Pause",
        "subtitle": "Stop racing thoughts",
      },
      {
        "duration": "10 min",
        "title": "Thought Release",
        "subtitle": "Let go gently",
      },
      {
        "duration": "15 min",
        "title": "Mental Silence",
        "subtitle": "Deep clarity",
      },
    ],
    "Angry": [
      {"duration": "5 min", "title": "Cool Down", "subtitle": "Slow breathing"},
      {
        "duration": "10 min",
        "title": "Emotional Reset",
        "subtitle": "Release anger",
      },
      {
        "duration": "15 min",
        "title": "Deep Calm",
        "subtitle": "Restore balance",
      },
    ],
    "Low Energy": [
      {
        "duration": "5 min",
        "title": "Quick Refresh",
        "subtitle": "Boost energy",
      },
      {
        "duration": "10 min",
        "title": "Focus Boost",
        "subtitle": "Improve clarity",
      },
      {
        "duration": "15 min",
        "title": "Full Recharge",
        "subtitle": "Restore energy",
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Image Section
            Container(
              width: double.infinity,
              height: 300,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                image: DecorationImage(
                  image: AssetImage("assets/images/meditation_image.png"),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Mood Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "How are you feeling today?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D6D57),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Mood Chips
            SizedBox(
              height: 55,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  moodChip("Anxiety"),
                  moodChip("Stress"),
                  moodChip("Sad"),
                  moodChip("Lonely"),
                  moodChip("Overthinking"),
                  moodChip("Angry"),
                  moodChip("Low Energy"),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Bottom Green Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 25),
              decoration: const BoxDecoration(
                color: Color(0xFFA1BE94),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Meditation Sessions",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F3E2F),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  Column(
                    children: selectedMood == null
                        ? []
                        : moodSessions[selectedMood]!
                              .map(
                                (session) => Padding(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  child: sessionCard(
                                    session["duration"]!,
                                    session["title"]!,
                                    session["subtitle"]!,
                                  ),
                                ),
                              )
                              .toList(),
                  ),

                  const SizedBox(height: 30),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedMood == null || selectedDuration == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select mood and session"),
                            ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => PopupMeditation(
                            mood: selectedMood,
                            duration: selectedDuration!, // <-- fix
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        "Start Session",
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.buttonColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Tip: Daily meditation helps reduce stress and balance hormones in PCOD.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF2F3E2F)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mood Chip
  Widget moodChip(String title) {
    bool isSelected = selectedMood == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMood = title;
          selectedDuration = moodSessions[title]![0]["duration"]!;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF95B289) : const Color(0xE8ECF1D8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF95B289)),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF5D6D57),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // Session Card (Border only selection)
  Widget sessionCard(String duration, String title, String subtitle) {
    bool isSelected = selectedDuration == duration;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDuration = duration;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xE8EDF4D3),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? const Color.fromARGB(255, 110, 141, 99)
                : const Color.fromARGB(0, 89, 131, 100),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF95B289),
              child: Text(
                duration,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F3E2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D6D57),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
