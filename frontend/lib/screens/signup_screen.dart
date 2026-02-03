// Legacy signup screen (currently disabled).
/*import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String selectedRole = 'farmer';
  String message = '';
  bool isLoading = false;

  void handleSignup() async {
    setState(() {
      isLoading = true;
      message = '';
    });

    try {
      await ApiService.signup(
        nameController.text,
        emailController.text,
        passwordController.text,
        selectedRole,
      );

      if (!mounted) return; // Guard against using a disposed context.

      setState(() {
        message = 'Kayıt başarılı!';
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => message = 'Hata: $e');
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'İsim')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Şifre'),
              obscureText: true,
            ),
            DropdownButton<String>(
              value: selectedRole,
              onChanged: (value) => setState(() => selectedRole = value!),
              items: const [
                DropdownMenuItem(value: 'farmer', child: Text('Çiftçi')),
                DropdownMenuItem(value: 'supporter', child: Text('Destekçi')),
              ],
            ),
            const SizedBox(height: 16),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: handleSignup, child: const Text('Kayıt Ol')),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}*/
