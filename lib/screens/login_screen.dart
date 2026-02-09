import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  Future<void> login() async {
    final url = Uri.parse("https://hackdefenders.com/Minahil/Habit/login.php");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text,
        }),
      );

      print("Login response status: ${response.statusCode}");
      print("Login response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Parsed data: $data");
        print("Status: ${data['status']}");

        if (data['status'] == 'success') {
          // Handle different possible formats - API returns user.id not user_id
          int? tempUserId;

          // Check if user_id exists (old format)
          if (data['user_id'] != null) {
            if (data['user_id'] is int) {
              tempUserId = data['user_id'];
            } else if (data['user_id'] is String) {
              tempUserId = int.tryParse(data['user_id']);
            }
          }
          // Check if user.id exists (new format from Postman response)
          else if (data['user'] != null && data['user']['id'] != null) {
            if (data['user']['id'] is int) {
              tempUserId = data['user']['id'];
            } else if (data['user']['id'] is String) {
              tempUserId = int.tryParse(data['user']['id'].toString());
            }
          }

          print("User ID: $tempUserId");

          if (tempUserId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: Invalid user ID received")));
            return;
          }

          // Now we have a non-nullable userId
          final int userId = tempUserId;
          print("Final User ID: $userId");

          // Get user name from email or API response
          String userName = data['user']?['name'] ?? 
                           data['name'] ?? 
                           emailController.text.split('@')[0] ?? 
                           'User';

          // Save user data to SharedPreferences for persistent login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', userId);
          await prefs.setString('userEmail', emailController.text.trim());
          await prefs.setString('userName', userName);

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(data['message'] ?? 'Login successful')));

          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(userId: userId, userName: userName, userEmail: emailController.text.trim())));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Login failed')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server error: ${response.statusCode}")));
      }
    } catch (e) {
      print("Login error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Network error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.track_changes,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Habit Tracker",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Build better habits, one day at a time",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 48),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        value!.isEmpty ? "Please enter email" : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (value) =>
                        value!.isEmpty ? "Please enter password" : null,
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) login();
                        },
                        child: Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => SignupScreen()));
                      },
                      child: Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(color: Colors.deepPurple),
                      ))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
