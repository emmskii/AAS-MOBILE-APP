import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  RegistrationPageState createState() => RegistrationPageState();
}

class RegistrationPageState extends State<RegistrationPage> {

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  void _registerUser() async {
    String fullName = _fullNameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage("Please fill all fields");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match");
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'createdAt': DateTime.now(),
      });

      _showSuccessDialog();
    } catch (e) {
      _showMessage("Error: ${e.toString()}");
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Success!"),
          content: const Text("Your account has been created successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool success = false}) {
    Future.delayed(Duration.zero, () { // Ensures execution in the next frame
      if (mounted) { // Prevents errors if widget is disposed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFD4F1E8),
      body: Stack(
        children: [
          Positioned(top: 50, left: -30, child: _buildBubble(120)),
          Positioned(top: 250, right: -40, child: _buildBubble(180)),
          Positioned(bottom: 100, left: -50, child: _buildBubble(200)),
          Positioned(bottom: 30, right: -60, child: _buildBubble(150)),

          Positioned(
            top: 50,
            left: 40,
            right: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Create an\nAccount",
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'NotoSerif',
                        color: Colors.black87,
                      ),
                    ),
                    _buildCurvedBox(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                _buildInputField("Full Name", "Enter your full name", false, null, _fullNameController),
                const SizedBox(height: 15),
                _buildInputField("Email", "Enter your email", false, null, _emailController),
                const SizedBox(height: 15),
                _buildInputField("Password", "Enter your password", true, true, _passwordController),
                const SizedBox(height: 15),
                _buildInputField("Confirm Password", "Re-enter your password", true, false, _confirmPasswordController),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Proceed",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, String hint, bool isPassword, bool? toggle, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label:",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: isPassword ? (toggle == true ? !passwordVisible : !confirmPasswordVisible) : false,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(
              isPassword ? Icons.lock : Icons.person,
              color: Colors.grey,
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                (toggle == true ? passwordVisible : confirmPasswordVisible)
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  if (toggle == true) {
                    passwordVisible = !passwordVisible;
                  } else {
                    confirmPasswordVisible = !confirmPasswordVisible;
                  }
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
        ),
      ],
    );
  }

  Widget _buildBubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromRGBO(33, 150, 243, 0.3), // 33,150,243 is the RGB of Colors.blue

      ),
    );
  }



  Widget _buildCurvedBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1), // Black color with 10% opacity
            blurRadius: 5,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
