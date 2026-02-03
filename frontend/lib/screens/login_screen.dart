// Login screen with email/password authentication.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/language_selector.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      // ApiService.login returns a JWT string and stores the session.
      final token = await ApiService.login(
        email.text.trim(),
        password.text.trim(),
      );
    // DEBUG: check if session really filled
    debugPrint('SESSION email=${ApiService.session?.email}, role=${ApiService.session?.role}');

      if (!mounted) return;

      // Keep the existing flow and navigate to the dashboard.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userId: token,            // current code uses this field as token
            password: password.text,  // keep existing parameter
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await ApiService.showAlert(
        context,
        context.tr('Login error: {message}', params: {'message': '$e'}),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: const LanguageSelector(),
                ),
                const SizedBox(height: 12),
                // Logo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 16,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', width: 120, height: 120),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('ALSApp'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 28),

                // Form
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.tr('Mail'),
                    hintText: context.tr('you@example.com'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration:
                      InputDecoration(labelText: context.tr('Password')),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),

                // Actions
                loading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          child: Text(context.tr('Log In')),
                        ),
                      ),

                const SizedBox(height: 12),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.tr("Don't have an account? ")),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(context.tr('Sign Up')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
