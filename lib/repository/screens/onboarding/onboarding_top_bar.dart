import 'package:flutter/material.dart';

class OnboardingTopBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const OnboardingTopBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    double progress = currentStep / totalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          /// Back button (disabled for first screen)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentStep == 1
                ? null
                : () => Navigator.pop(context),
          ),

          /// Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation(
                  Color(0xff6B8165),
                ),
              ),
            ),
          ),

          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
