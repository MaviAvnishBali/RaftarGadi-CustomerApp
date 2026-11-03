import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/auth/auth_page.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// The customer sign-in screen. Existing customers verify their phone via OTP.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _normalizedPhone {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('91') && digits.length == 12
        ? '+$digits'
        : '+91$digits';
  }

  Future<void> _requestOtp() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final phone = _normalizedPhone;
    final result = await ref.read(authRepositoryProvider).requestOtp(phone);
    if (!mounted) return;
    setState(() => _busy = false);

    result.match(
      (failure) => setState(() => _error = failure.message),
      (_) => context.go('${Routes.otp}?phone=${Uri.encodeComponent(phone)}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackExitScope(
      child: AuthPage(
        eyebrow: 'Welcome back',
        title: 'Sign in to move more.',
        subtitle: 'Enter the phone number linked to your Raftar Gaddi account.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftarTextField(
              label: 'Phone number',
              controller: _phone,
              hint: '98765 43210',
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: RaftarSpacing.xl),
            RaftarButton(
              label: 'Continue with OTP',
              isLoading: _busy,
              onPressed: _requestOtp,
            ),
            const SizedBox(height: RaftarSpacing.xxl),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RaftarSpacing.md,
                  ),
                  child: Text(
                    'NEW TO RAFTAR?',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: RaftarSpacing.lg),
            RaftarButton(
              label: 'Create an account',
              variant: RaftarButtonVariant.secondary,
              onPressed: () => context.go(Routes.register),
            ),
            const SizedBox(height: RaftarSpacing.xl),
            Text(
              'By continuing, you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
