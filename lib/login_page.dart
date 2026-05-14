import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'home_page.dart';
import 'signup_page.dart';
import 'opened_pdf_page.dart';
import 'pdf_model.dart';

// 🔹 IMPORTANT: Android-only import ko safe banaya
import 'pdf_intent_helper_web.dart'
if (dart.library.io) 'pdf_intent_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final store = AppStore.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool isAdmin = false;

  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    _listenForIncomingPdf();
  }

  // ✅ ANDROID ONLY (WEB SAFE)
  void _listenForIncomingPdf() async {
    if (kIsWeb) return;

    _intentSub = PdfIntentHelper.listen((files) {
      _openIncomingPdf(files);
    });

    final files = await PdfIntentHelper.getInitial();
    _openIncomingPdf(files);
  }

  void _openIncomingPdf(List files) {
    if (!mounted || files.isEmpty) return;

    final file = files.first;
    final path = file.path ?? "";

    if (path.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenedPdfPage(
          path: path,
          title: path.split('/').last,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter email & password")),
      );
      return;
    }

    setState(() => isLoading = true);

    await Future.delayed(const Duration(milliseconds: 300));

    final error = store.login(
      email: email,
      password: password,
      role: isAdmin ? UserRole.admin : UserRole.user,
    );

    setState(() => isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // 🔹 LEFT PANEL (Desktop Only)
            if (isDesktop)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo, Colors.blue],
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.picture_as_pdf,
                          size: 60, color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        "PDF Viewer",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Open PDF directly from your phone",
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),

            // 🔹 RIGHT LOGIN CARD
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: width > 600 ? 50 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.login,
                              size: 40,
                              color:
                              isAdmin ? Colors.deepPurple : Colors.indigo,
                            ),
                            const SizedBox(height: 10),

                            Text(
                              isAdmin ? "Admin Login" : "User Login",
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),

                            SwitchListTile(
                              title: const Text("Login as Admin"),
                              value: isAdmin,
                              onChanged: (v) =>
                                  setState(() => isAdmin = v),
                            ),

                            TextField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),

                            const SizedBox(height: 10),

                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () => setState(() =>
                                  obscurePassword = !obscurePassword),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : login,
                                child: isLoading
                                    ? const CircularProgressIndicator()
                                    : Text(isAdmin
                                    ? "Admin Login"
                                    : "Login"),
                              ),
                            ),

                            const SizedBox(height: 10),

                            if (!isAdmin)
                              TextButton(
                                onPressed: openSignup,
                                child: const Text("Create Account"),
                              ),

                            const SizedBox(height: 10),

                            const Text(
                              "User: user@gmail.com / 123456\nAdmin: admin@gmail.com / 123456",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
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