import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';

// Registration form for new users.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum Role { farmer, ministry }

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  Role role = Role.farmer;
  bool loading = false;

  Future<void> _submit() async {
    if (pass.text != pass2.text) {
      await ApiService.showAlert(
        context,
        context.tr('Passwords do not match.'),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await ApiService.register(
        name: name.text.trim(),
        email: email.text.trim(),
        password: pass.text,
        role: role == Role.farmer ? 'farmer' : 'ministry',
      );
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Registration successful.'),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Register error: {message}', params: {'message': '$e'}),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Sign Up')),
        actions: const [LanguageSelector()],
      ),
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration:
                      InputDecoration(labelText: context.tr('Name')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration:
                      InputDecoration(labelText: context.tr('Mail')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration:
                      InputDecoration(labelText: context.tr('Password')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass2,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('Please enter password again'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Radio<Role>(
                      value: Role.farmer,
                      groupValue: role,
                      onChanged: (v) => setState(() => role = v!),
                    ),
                    Text(context.tr('Farmer or livestock breeder')),
                  ],
                ),
                Row(
                  children: [
                    Radio<Role>(
                      value: Role.ministry,
                      groupValue: role,
                      onChanged: (v) => setState(() => role = v!),
                    ),
                    Text(context.tr('Ministry Employee')),
                  ],
                ),
                const SizedBox(height: 18),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(context.tr('Sign Up')),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
