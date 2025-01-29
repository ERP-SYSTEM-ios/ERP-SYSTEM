import 'package:erp_system/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:erp_system/features/presentation/pages/sign_up_page.dart';
import 'package:erp_system/features/presentation/widgets/form_container_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage; // To hold error messages

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giriş"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Giriş ----- DELETE IMPLEMENTATION",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red), 
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              FormContainerWidget(
                controller: _emailController,
                hintText: "Email",
                isPasswordField: false,
              ),
              const SizedBox(height: 10),
              FormContainerWidget(
                controller: _passwordController,
                hintText: "Parola",
                isPasswordField: true,
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: _signIn,
                child: Container(
                  width: double.infinity,
                  height: 45.0,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Center(
                    child: Text(
                      "Giriş",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Hesabınız yok mu?"),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const SignUpPage()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      "Hesap Oluştur",
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _signIn() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      User? user = await _auth.signInWithEmailAndPassword(email, password);

      if (user != null) {
        // Login successful
        if (mounted) {
          Navigator.pushReplacementNamed(context, "/home");
        }
      } else {
        // User not found in database
        setState(() {
          _errorMessage = "Yanliş bilgiler girdiniz yada Kullanıcı bulunamadı.";
        });
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase exceptions
      setState(() {
        if (e.code == 'wrong-password') {
          _errorMessage = "Yanlış parola girdiniz.";
        } else if (e.code == 'user-not-found') {
          _errorMessage = "Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.";
        } else if (e.code == 'invalid-email') {
          _errorMessage = "Geçersiz e-posta adresi.";
        } else {
          _errorMessage = "Giriş sırasında bir hata oluştu. Lütfen tekrar deneyin.";
        }
      });
    } catch (e) {
      // Handle other exceptions
      if (kDebugMode) {
        print("Hata oluştu: $e");
      }
      setState(() {
        _errorMessage = "Bir hata oluştu. Lütfen tekrar deneyin.";
      });
    }
  }
}
