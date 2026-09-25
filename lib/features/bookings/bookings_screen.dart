import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// The signed-in customer's bookings, newest first.
final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final customerId = ref.watch(sessionControllerProvider).user?.id ?? 'usr_1';
  final result = await ref
      .watch(bookingRepositoryProvider)
      .getBookings(customerId: customerId);
  return result.fold(
    (failure) => throw failure,
    (page) => page.items.reversed.toList(),
  );
});

/// Bookings tab: lists the customer's trips, or the empty state.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookingsProvider),
        child: AsyncValueView<List<Booking>>(
          value: ref.watch(bookingsProvider),
          onRetry: () => ref.invalidate(bookingsProvider),
          data: (bookings) {
            if (bookings.isEmpty) {
              return const RaftarEmptyView(
                title: 'No bookings yet',
                message: 'Your trips will show up here once you book a move.',
                icon: Icons.local_shipping_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(RaftarSpacing.lg),
              itemCount: bookings.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: RaftarSpacing.md),
              itemBuilder: (context, index) =>
                  _BookingTile(booking: bookings[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  static const _statusText = {
    BookingStatus.draft: 'Draft',
    BookingStatus.searching: 'Finding driver',
    BookingStatus.driverAssigned: 'Driver assigned',
    BookingStatus.arrivingPickup: 'Arriving',
    BookingStatus.inTransit: 'In transit',
    BookingStatus.completed: 'Completed',
    BookingStatus.cancelled: 'Cancelled',
  };

  RaftarStatus get _badgeStatus => switch (booking.status) {
    BookingStatus.completed => RaftarStatus.success,
    BookingStatus.cancelled => RaftarStatus.error,
    _ => RaftarStatus.info,
  };

  @override
  Widget build(BuildContext context) {
    return RaftarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.vehicleType.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              RaftarBadge(
                label: _statusText[booking.status]!,
                status: _badgeStatus,
              ),
            ],
          ),
          const SizedBox(height: RaftarSpacing.sm),
          Text(
            '${booking.pickup.title} → ${booking.drop.title}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: RaftarSpacing.xs),
          Text(
            '₹${booking.fare.total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: RaftarColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
