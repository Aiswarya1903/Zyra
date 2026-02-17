import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/models/user_data.dart';
import 'package:zyra_final/domain/services/auth_services.dart';
import 'package:zyra_final/repository/screens/onboarding/weight_screen.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0xFF95B289),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

void _onNext() async {
  if (!_formKey.currentState!.validate()) return;

  UserData.email = emailController.text.trim();
  UserData.name = nameController.text.trim();
  UserData.password = passwordController.text.trim();

  try {
    await AuthService.signUp(
      UserData.email,
      UserData.password,
    );

    // Check login success
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception("Signup failed");
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeightScreen()),
    );

  } on FirebaseAuthException catch (e) {
    String message = "Signup failed";

    if (e.code == 'email-already-in-use') {
      message = "Email already registered. Please login";
    } else if (e.code == 'weak-password') {
      message = "Password is too weak";
    } else if (e.code == 'invalid-email') {
      message = "Invalid email";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            /// Top Image
            const SizedBox(height: 40),
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Image.asset(
                "assets/images/Onboarding.png",
                fit: BoxFit.cover,
              ),
            ),

            /// Form Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      /// Email
                      TextFormField(
                        controller: emailController,
                        decoration: _inputDecoration("Enter email"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Email is required";
                          }
                          if (!_isValidEmail(value)) {
                            return "Enter valid email";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      /// Name
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration("Enter name"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Name is required";
                          }
                          if (value.length < 2) {
                            return "Enter valid name";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      /// Password
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: _inputDecoration("Password"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Password is required";
                          }
                          if (value.length < 6) {
                            return "Password must be at least 6 characters";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      /// Confirm Password
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration:
                            _inputDecoration("Re-enter password"),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please confirm password";
                          }
                          if (value != passwordController.text) {
                            return "Passwords do not match";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),

                      /// Next Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _onNext,
                          child: const Text(
                            "Next",
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.buttonText),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
