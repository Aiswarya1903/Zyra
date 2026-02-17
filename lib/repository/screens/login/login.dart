import 'package:flutter/material.dart';
import 'package:zyra_final/domain/constant/appcolors.dart';
import 'package:zyra_final/domain/services/auth_services.dart';
import 'package:zyra_final/repository/screens/home/homescreen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> loginUser() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email and password")),
      );
      return;
    }

    try {
      await AuthService.login(email, password);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ZyraHomePage()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 80,
                child: Center(
                  child: Image.asset(
                    "assets/images/support.png",
                    width: 200,
                    height: 120,
                  ),
                ),
              ),

              const Positioned(
                top: 280,
                left: 0,
                right: 0,
                child: Center(child: Text('Hey there!!')),
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

              // Email
              Positioned(
                top: 400,
                left: 40,
                right: 40,
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              // Password
              Positioned(
                top: 470,
                left: 40,
                right: 40,
                child: TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(
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
                    onPressed: loginUser,
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
