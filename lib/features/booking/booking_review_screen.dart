import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:customer_app/features/bookings/bookings_screen.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Booking step 3: review pickup/drop, the fare breakdown, and confirm — which
/// creates the booking through `BookingRepository`.
class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key});

  @override
  ConsumerState<BookingReviewScreen> createState() =>
      _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final customerId = ref.read(sessionControllerProvider).user?.id ?? 'usr_1';
    final result = await ref
        .read(bookingDraftControllerProvider.notifier)
        .confirm(
          customerId,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.match(
      (failure) => RaftarFeedback.showSnackbar(
        context,
        message: failure.message,
        status: RaftarStatus.error,
      ),
      (booking) {
        ref.read(bookingDraftControllerProvider.notifier).reset();
        ref.invalidate(bookingsProvider);
        context.go('${Routes.bookingConfirmed}?id=${booking.id}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftControllerProvider);
    final fare = draft.fare;

    return Scaffold(
      appBar: AppBar(title: const Text('Review booking')),
      body: ListView(
        padding: const EdgeInsets.all(RaftarSpacing.lg),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RaftarRadii.lg),
            child: MapPlaceholder(
              height: 180,
              pickupLabel: draft.pickup?.title,
              dropLabel: draft.drop?.title,
            ),
          ),
          const SizedBox(height: RaftarSpacing.xl),
          RaftarCard(
            child: Column(
              children: [
                _RouteRow(
                  icon: Icons.trip_origin_rounded,
                  title: draft.pickup?.title ?? '',
                  subtitle: draft.pickup?.formattedAddress ?? '',
                ),
                const Divider(height: RaftarSpacing.xl),
                _RouteRow(
                  icon: Icons.location_on_rounded,
                  title: draft.drop?.title ?? '',
                  subtitle: draft.drop?.formattedAddress ?? '',
                ),
              ],
            ),
          ),
          const SizedBox(height: RaftarSpacing.xl),
          Text(
            'Fare breakdown',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: RaftarSpacing.md),
          if (fare != null) _FareBreakdown(fare: fare),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          child: RaftarButton(
            label: fare == null
                ? 'Confirm booking'
                : 'Confirm • ₹${fare.total.toStringAsFixed(0)}',
            icon: Icons.check_rounded,
            isLoading: _busy,
            onPressed: _confirm,
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: RaftarColors.primary, size: 20),
        const SizedBox(width: RaftarSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _FareBreakdown extends StatelessWidget {
  const _FareBreakdown({required this.fare});

  final FareEstimate fare;

  @override
  Widget build(BuildContext context) {
    return RaftarCard(
      child: Column(
        children: [
          _row(context, 'Base fare', fare.baseFare),
          _row(context, 'Distance (${fare.distanceKm} km)', fare.distanceFare),
          _row(context, 'Time (${fare.durationMinutes} min)', fare.timeFare),
          if (fare.discount > 0) _row(context, 'Discount', -fare.discount),
          const Divider(height: RaftarSpacing.xl),
          _row(context, 'Total', fare.total, emphasize: true),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double amount, {
    bool emphasize = false,
  }) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RaftarSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
