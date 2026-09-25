import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/auth/auth_page.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';

/// Account creation screen. A successful registration sends the customer into
/// the same OTP verification flow used for returning customers.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('91') && digits.length == 12
        ? '+$digits'
        : '+91$digits';
  }

  Future<void> _register() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final phone = _normalizedPhone;
    final result = await ref
        .read(authRepositoryProvider)
        .register(
          fullName: _name.text.trim(),
          phone: phone,
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.match(
      (failure) => setState(() => _error = failure.message),
      (_) => context.go('${Routes.otp}?phone=${Uri.encodeComponent(phone)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      eyebrow: 'Create account',
      title: 'Let’s get moving.',
      subtitle: 'A few details now, then verify your phone to get started.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftarTextField(
            label: 'Full name',
            controller: _name,
            hint: 'Aarav Sharma',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: RaftarSpacing.lg),
          RaftarTextField(
            label: 'Phone number',
            controller: _phone,
            hint: '98765 43210',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: RaftarSpacing.lg),
          RaftarTextField(
            label: 'Email address (optional)',
            controller: _email,
            hint: 'you@example.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            errorText: _error,
            onChanged: (_) => _clearError(),
          ),
          const SizedBox(height: RaftarSpacing.xl),
          RaftarButton(
            label: 'Create account',
            isLoading: _busy,
            onPressed: _register,
          ),
          const SizedBox(height: RaftarSpacing.xl),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () => context.go(Routes.login),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }
}
