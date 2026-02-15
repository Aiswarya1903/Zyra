import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/services/user_services.dart';
import 'package:zyra_final/repository/screens/periods/regular.dart';

class StartJourney extends StatelessWidget {
  const StartJourney({super.key});

  @override
  Widget build(BuildContext context) {
    return const KnowYourBodyBetter();
  }
}

class KnowYourBodyBetter extends StatelessWidget {
  const KnowYourBodyBetter({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: screenHeight,
          child: Stack(
            children: [
              /// Title
              const Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Text(
                  'KNOW YOUR BODY BETTER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5D6D57),
                    fontSize: 24,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              /// Subtitle
              const Positioned(
                left: 0,
                right: 0,
                top: 120,
                child: Text(
                  'unlock your inner wisdom and thrive',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7A8776),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),

              /// Image
              Positioned(
                left: 0,
                right: 0,
                top: screenHeight * 0.28,
                child: SizedBox(
                  height: screenHeight * 0.38,
                  child: Image.asset(
                    "assets/images/start_jouney.png",
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              /// Start Journey Button
              Positioned(
                left: 30,
                right: 30,
                bottom: 40,
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF95B289),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () async {
                      await UserService.updateStep(1);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegularScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Start Journey',
                      style: TextStyle(
                        color: Color(0xFF3A4336),
                        fontSize: 18,
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
