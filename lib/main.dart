  import 'package:flutter/material.dart';
  import 'registration_page.dart';
  import 'home_page.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'firebase_options.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  }


  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Automated Aquarium System',
        theme: ThemeData(
          primarySwatch: Colors.teal,
        ),
        home: const LoginPage(),
      );
    }
  }

  class LoginPage extends StatefulWidget {
    const LoginPage({super.key});

    @override
    State<LoginPage> createState() => _LoginPageState();
  }

  class _LoginPageState extends State<LoginPage> {
    bool rememberMe = false;
    bool passwordVisible = false;
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    Future<void> _login() async {
      String email = emailController.text.trim();
      String password = passwordController.text.trim();

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        User? user = userCredential.user;
        if (user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            String fullName = userDoc['fullName'] ?? "User";

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    fullName: fullName,
                    email: email,
                    password: password,  // Ensure password is included
                  ),
                ),
              );
            }
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = "Login failed. Please try again.";
        if (e.code == 'user-not-found') {
          errorMessage = "No user found with this email.";
        } else if (e.code == 'wrong-password') {
          errorMessage = "Incorrect password.";
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Login Failed"),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFD4F1E8),
        body: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                // ✅ Background Bubbles
                Positioned(top: 50, left: -30, child: _buildBubble(120)),
                Positioned(top: 250, right: -40, child: _buildBubble(180)),
                Positioned(bottom: 100, left: -50, child: _buildBubble(200)),
                Positioned(bottom: 30, right: -60, child: _buildBubble(150)),

                // ✅ Logo
                Positioned(
                  top: 80,
                  left: MediaQuery.of(context).size.width / 4.5 - 60,
                  child: Image.asset(
                    'assets/images/AAS-logo.png',
                    width: 350,
                    height: 350,
                  ),
                ),

                // ✅ Title
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: const Text(
                    "Automated Aquarium System",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900, // This will use 'Poppins-Black'
                      color: Colors.black87,
                      fontFamily: 'Poppins', // Keep this as 'Poppins' since it's the family name
                    ),

                  ),
                ),

                // ✅ Email Field
                Positioned(
                  top: 450,
                  left: 40,
                  right: 40,
                  child: _buildTextField(
                    controller: emailController,
                    hintText: "Enter Email",
                    icon: Icons.email,
                  ),
                ),

                // ✅ Password Field
                Positioned(
                  top: 520,
                  left: 40,
                  right: 40,
                  child: _buildTextField(
                    controller: passwordController,
                    hintText: "Enter Password",
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                ),

                // ✅ Remember Me Checkbox
                Positioned(
                  top: 580,
                  left: 110,
                  child: Row(
                    children: [
                      Checkbox(
                        value: rememberMe,
                        onChanged: (bool? value) {
                          setState(() {
                            rememberMe = value ?? false;
                          });
                        },
                        activeColor: Colors.teal[700],
                      ),
                      const Text(
                        "Remember Me",
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),

                // ✅ Login Button
                Positioned(
                  top: 700,
                  left: MediaQuery.of(context).size.width / 3.5 - 75,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

                // ✅ Sign-Up Text
                Positioned(
                  top: 760,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegistrationPage()),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Bubble Widget
    Widget _buildBubble(double size) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withAlpha(76),
        ),
      );
    }

    // ✅ Text Field Widget
    Widget _buildTextField({
      required TextEditingController controller,
      required String hintText,
      required IconData icon,
      bool isPassword = false,
    }) {
      return TextField(
        controller: controller,
        obscureText: isPassword ? !passwordVisible : false,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                passwordVisible = !passwordVisible;
              });
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      );
    }
  }



