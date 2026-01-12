import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Sign Up (${_currentStep + 1}/5)'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep++);
          } else {
            // TODO: Complete signup
            context.go('/home');
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            context.pop();
          }
        },
        steps: [
          Step(
            title: const Text('Account Info'),
            content: const Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Personal Info'),
            content: const Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Phone (India only)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Role Selection'),
            content: const Column(
              children: [
                Text('Select your role:'),
                SizedBox(height: 16),
                // TODO: Add role selection buttons
              ],
            ),
          ),
          Step(
            title: const Text('Body Metrics'),
            content: const Column(
              children: [
                Text('Height, Weight, DOB, Gender'),
                SizedBox(height: 16),
                // TODO: Add wheel selectors and pickers
              ],
            ),
          ),
          Step(
            title: const Text('Categories'),
            content: const Column(
              children: [
                Text('Select categories (for trainers/nutritionists)'),
                SizedBox(height: 16),
                // TODO: Add category selection
              ],
            ),
          ),
        ],
      ),
    );
  }
}

