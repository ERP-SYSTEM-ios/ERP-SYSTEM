import 'package:erp_system/features/user_auth/firebase_auth_implementation/firebase_auth_services.dart';
import 'package:erp_system/features/presentation/pages/login_page.dart';
import 'package:erp_system/features/presentation/widgets/form_container_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hesap Oluştur"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Hesap Oluştur",
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                FormContainerWidget(
                  controller: _nameController,
                  hintText: "İsim",
                  isPasswordField: false,
                ),
                const SizedBox(height: 10),
                FormContainerWidget(
                  controller: _surnameController,
                  hintText: "Soyad",
                  isPasswordField: false,
                ),
                const SizedBox(height: 10),
                FormContainerWidget(
                  controller: _companyNameController,
                  hintText: "Şirketiniz Adı",
                  isPasswordField: false,
                ),
                const SizedBox(height: 10),
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
                  onTap: _signUp,
                  child: Container(
                    width: double.infinity,
                    height: 45.0,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Center(
                      child: Text(
                        "Hesap Oluştur",
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
                    const Text("Zaten bir hesabınız var mı?"),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        "Giriş Yap",
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
      ),
    );
  }

  void _signUp() async {
    String name = _nameController.text.trim();
    String surname = _surnameController.text.trim();
    String companyName = _companyNameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (name.isEmpty || surname.isEmpty || companyName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tüm alanların doldurulması zorunludur.")),
      );
      return;
    }

    try {
      User? user = await _auth.signUpWithEmailAndPassword(email, password);

      if (user != null) {
        // Normalize company name for consistent Firestore storage
        String normalizedCompanyName = companyName.toLowerCase().replaceAll(' ', '_');
        String companyId = normalizedCompanyName;

        // Check if the company already exists
        final existingCompany = await FirebaseFirestore.instance
            .collection("Companies")
            .doc(companyId)
            .get();

        if (existingCompany.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Şirket adı zaten mevcut. Lütfen farklı bir ad seçin.")),
          );
          return;
        }

        // Create the company in the Companies collection
        await FirebaseFirestore.instance.collection("Companies").doc(companyId).set({
          "companyName": companyName.toLowerCase(), // Store in lowercase
          "createdAt": FieldValue.serverTimestamp(),
          "userId": user.uid,
        });

        // Save user information along with the companyId
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "name": name,
          "surname": surname,
          "companyName": companyName.toLowerCase(), // Store in lowercase
          "companyId": companyId, // Save the generated company ID
          "email": email,
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print("User registered and company created with companyId: $companyId.");
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, "/", arguments: user.email);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}
