import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_brand.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'signup_screen.dart';

/// Firebase-backed sign-in screen.
///
/// Navigation after authentication is owned by [AuthWrapper] through the
/// Firebase auth-state stream. This screen never creates a local/demo user.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          AppBrand.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Sign in to your inventory',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXL),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !email.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(auth),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: auth.isLoading ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (auth.error != null) ...[
                          Text(
                            auth.error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                        ],
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : () => _submit(auth),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?"),
                            TextButton(
                              onPressed: auth.isLoading
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      ),
                              child: const Text('Create one'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthViewModel auth) async {
    if (!_formKey.currentState!.validate()) return;
    await auth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }

    final auth = context.read<AuthViewModel>();
    final sent = await auth.sendPasswordResetEmail(email);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'If an account exists for that email, a reset link will be sent. Check your inbox and spam folder.'
              : (auth.error ?? 'Could not request a password reset.'),
        ),
      ),
    );
  }
}
