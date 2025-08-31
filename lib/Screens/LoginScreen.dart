import 'package:expenseapp/Components/AuthForm.dart';
import 'package:expenseapp/Constants/Colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AuthForm(
          onSubmit: (email, password) async {
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              Navigator.pushReplacementNamed(context, '/home');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Login failed: $e')),
              );
            }
          },
          buttonText: 'Login',
          alternateActionText: 'Need an account? Sign up',
          alternateAction: () {
            Navigator.pushNamed(context, '/signup');
          },
        ),
      ),
    );
  }
}