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
              Stack(
                alignment: Alignment.center,
                children: [
                  // Decorative confetti dots
                  Positioned(
                    top: 0,
                    left: 20,
                    child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  ),
                  Positioned(
                    top: 15,
                    right: 30,
                    child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 30,
                    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 25,
                    child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: RaftarColors.green, shape: BoxShape.circle)),
                  ),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: RaftarColors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaftarSpacing.xxl),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: RaftarColors.navy,
                ),
              ),
              const SizedBox(height: RaftarSpacing.sm),
              Text(
                'Your booking ID is ${bookingId.length > 7 ? 'RG-1002' : bookingId}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: RaftarColors.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RaftarColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.near_me_rounded, size: 20),
                  label: const Text(
                    'Track Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => context.push('${Routes.tripTracking}?id=$bookingId'),
                ),
              ),
              const SizedBox(height: RaftarSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: RaftarColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => context.go(Routes.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
