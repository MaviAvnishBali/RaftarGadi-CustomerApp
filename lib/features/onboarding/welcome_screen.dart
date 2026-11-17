import 'package:customer_app/app/router/routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Customer Welcome / Onboarding Screen matching Image 2.
class CustomerWelcomeScreen extends StatelessWidget {
  const CustomerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RaftarColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RaftarSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: RaftarSpacing.md),
              // Top Logo mark
              const Align(
                alignment: Alignment.centerLeft,
                child: RaftarLogo(
                  height: 38,
                  onNavyPanel: false,
                ),
              ),
              const Spacer(),
              // Hero City & Truck Artwork
              const RaftarCustomerWelcomeArt(),
              const Spacer(),
              // Title & Subtitle
              Text(
                'Move Anything\nAnywhere',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: RaftarColors.navy,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: RaftarSpacing.md),
              Text(
                'Book reliable transport\nfor your goods with ease.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: RaftarColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: RaftarSpacing.xl),
              // Pagination Dots (active green indicator)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 8,
                    decoration: BoxDecoration(
                      color: RaftarColors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: RaftarColors.borderStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: RaftarColors.borderStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Green Action Button: Get Started
              RaftarButton(
                label: 'Get Started',
                onPressed: () => context.go(Routes.login),
              ),
              const SizedBox(height: RaftarSpacing.sm),
              // Skip Text Button
              TextButton(
                onPressed: () => context.go(Routes.login),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: RaftarColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: RaftarSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
