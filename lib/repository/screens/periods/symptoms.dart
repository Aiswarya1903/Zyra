import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/models/user_data.dart';

class CycleSymptomsScreen extends StatefulWidget {
  const CycleSymptomsScreen({super.key});

  @override
  State<CycleSymptomsScreen> createState() => _CycleSymptomsScreenState();
}

class _CycleSymptomsScreenState extends State<CycleSymptomsScreen> {
  final List<String> symptoms = [
    "Cramps",
    "Spotting",
    "Bloating",
    "Mood swings",
    "Headaches",
    "Fatigue",
    "Tender breasts",
    "None",
  ];

  Set<String> selectedSymptoms = {};

  void toggleSelection(String symptom) {
    setState(() {
      // If None selected → clear everything else
      if (symptom == "None") {
        if (selectedSymptoms.contains("None")) {
          selectedSymptoms.remove("None");
        } else {
          selectedSymptoms.clear();
          selectedSymptoms.add("None");
        }
      } else {
        // Remove None if other symptom selected
        selectedSymptoms.remove("None");

        if (selectedSymptoms.contains(symptom)) {
          selectedSymptoms.remove(symptom);
        } else {
          selectedSymptoms.add(symptom);
        }
      }
    });
  }

 Widget symptomCard(String symptom) {
  bool isSelected = selectedSymptoms.contains(symptom);

  return GestureDetector(
    onTap: () => toggleSelection(symptom),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
          color: isSelected
          ? AppColors.buttonColor        // highlight selected
          : const Color(0xE8EDF4D3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
          color: isSelected
          ? AppColors.buttonColor
          : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            symptom,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
              color: Color(0xFF3A4336),
            ),
          ),

          // Circle with tick
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xE8EDF4D3), // same background
              border: Border.all(
                color: isSelected
                    ? AppColors.buttonColor
                    : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: AppColors.buttonColor,
                  )
                : null,
          ),
        ],
      ),
    ),
  );
}


  void onSave() {
    if (selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one option")),
      );
      return;
    }

    UserData.symptoms = selectedSymptoms.toList();

    // Navigate next
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
              const SizedBox(height: 50),

              const Text(
                "Do you experience any\ncycle-related symptoms?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: Color(0xFF5D6D57),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Select all that apply",
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Outfit',
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children:
                      symptoms.map((s) => symptomCard(s)).toList(),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: 260,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
