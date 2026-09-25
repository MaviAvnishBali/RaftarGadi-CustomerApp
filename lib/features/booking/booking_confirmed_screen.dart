import 'package:customer_app/app/router/routes.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Booking step 4: success. The created booking now lives in the mock DB and
/// shows up in the Bookings tab. Live tracking arrives in Phase 4d.
class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaftarSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(RaftarSpacing.xl),
                decoration: const BoxDecoration(
                  color: RaftarColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 56,
                  color: RaftarColors.primary,
                ),
              ),
              const SizedBox(height: RaftarSpacing.xxl),
              Text(
                'Booking confirmed!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: RaftarSpacing.sm),
              Text(
                'We are finding you a driver.\nBooking ID: $bookingId',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              RaftarButton(
                label: 'View my bookings',
                onPressed: () => context.go(Routes.bookings),
              ),
              const SizedBox(height: RaftarSpacing.md),
              RaftarButton(
                label: 'Back to home',
                variant: RaftarButtonVariant.text,
                onPressed: () => context.go(Routes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
