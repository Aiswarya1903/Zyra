import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [

              // Top Image
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Center(
                  child: Image.asset(
                    "assets/images/support.png",
                    width: 200,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Texts
              const Positioned(
                top: 280,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Hey there!!',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),

              const Positioned(
                top: 310,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Color(0xFF5D6D57),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Email Field
              Positioned(
                top: 400,
                left: 40,
                right: 40,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF95B289)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Password Field
              Positioned(
                top: 470,
                left: 40,
                right: 40,
                child: TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF95B289)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Login Button
              Positioned(
                bottom: 120,
                left: 40,
                right: 40,
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF95B289),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xFF3A4336),
                        fontSize: 20,
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