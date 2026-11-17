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
        eyebrow: 'Welcome',
        title: 'Welcome Back!',
        subtitle: 'Login to continue',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftarTextField(
              label: 'Phone number',
              controller: _phone,
              hint: '+91 Enter Mobile Number',
              prefixIcon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: RaftarSpacing.xl),
            // Green "Send OTP" Button matching Image 2
            Stack(
              alignment: Alignment.center,
              children: [
                RaftarButton(
                  label: 'Send OTP',
                  isLoading: _busy,
                  onPressed: _requestOtp,
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.0,
                    child: TextButton(
                      onPressed: _busy ? null : _requestOtp,
                      child: const Text('Continue with OTP'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RaftarSpacing.xl),
            // Divider "or"
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RaftarSpacing.md),
                  child: Text(
                    'or',
                    style: TextStyle(
                      fontSize: 13,
                      color: RaftarColors.textSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: RaftarSpacing.lg),
            // Social Login Buttons
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google Sign-In is supported for partner accounts')),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: RaftarColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RaftarRadii.md)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('G', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: RaftarColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.md),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apple Sign-In is supported on iOS devices')),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: RaftarColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RaftarRadii.md)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple, color: RaftarColors.navy, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Continue with Apple',
                    style: TextStyle(
                      color: RaftarColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RaftarSpacing.xl),
            // Don't have an account? Sign Up
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: RaftarColors.textSecondary, fontSize: 14),
                ),
                GestureDetector(
                  onTap: () => context.go(Routes.register),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: RaftarColors.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () => context.go(Routes.register),
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    color: RaftarColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
