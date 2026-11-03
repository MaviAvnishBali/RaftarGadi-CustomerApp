import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Bookings tab: lists the customer's trips with interactive status filtering.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _selectedFilter = 'ALL';

  bool _isActiveStatus(BookingStatus status) =>
      status == BookingStatus.searching ||
      status == BookingStatus.driverAssigned ||
      status == BookingStatus.arrivingPickup ||
      status == BookingStatus.inTransit ||
      status == BookingStatus.draft;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsProvider);

    return Scaffold(
      backgroundColor: RaftarColors.surfaceMuted,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: RaftarColors.surface,
        title: const Text(
          'Your Trips',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Trips',
            onPressed: () => ref.invalidate(bookingsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bookingsProvider),
        child: Column(
          children: [
            // Filter Segments Bar
            Container(
              color: RaftarColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: RaftarSpacing.lg,
                vertical: RaftarSpacing.sm,
              ),
              child: bookingsAsync.maybeWhen(
                data: (allBookings) {
                  final activeCount =
                      allBookings.where((b) => _isActiveStatus(b.status)).length;
                  final completedCount = allBookings
                      .where((b) => b.status == BookingStatus.completed)
                      .length;
                  final cancelledCount = allBookings
                      .where((b) => b.status == BookingStatus.cancelled)
                      .length;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${allBookings.length})',
                          isSelected: _selectedFilter == 'ALL',
                          onTap: () => setState(() => _selectedFilter = 'ALL'),
                        ),
                        const SizedBox(width: RaftarSpacing.xs),
                        _FilterChip(
                          label: 'Active ($activeCount)',
                          isSelected: _selectedFilter == 'ACTIVE',
                          countBadgeColor: activeCount > 0 ? Colors.green : null,
                          onTap: () => setState(() => _selectedFilter = 'ACTIVE'),
                        ),
                        const SizedBox(width: RaftarSpacing.xs),
                        _FilterChip(
                          label: 'Completed ($completedCount)',
                          isSelected: _selectedFilter == 'COMPLETED',
                          onTap: () =>
                              setState(() => _selectedFilter = 'COMPLETED'),
                        ),
                        const SizedBox(width: RaftarSpacing.xs),
                        _FilterChip(
                          label: 'Cancelled ($cancelledCount)',
                          isSelected: _selectedFilter == 'CANCELLED',
                          countBadgeColor: cancelledCount > 0 ? Colors.red.shade400 : null,
                          onTap: () =>
                              setState(() => _selectedFilter = 'CANCELLED'),
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            const Divider(height: 1, color: RaftarColors.border),

            // Content List
            Expanded(
              child: AsyncValueView<List<Booking>>(
                value: bookingsAsync,
                onRetry: () => ref.invalidate(bookingsProvider),
                data: (allBookings) {
                  final filtered = allBookings.where((b) {
                    if (_selectedFilter == 'ACTIVE') {
                      return _isActiveStatus(b.status);
                    }
                    if (_selectedFilter == 'COMPLETED') {
                      return b.status == BookingStatus.completed;
                    }
                    if (_selectedFilter == 'CANCELLED') {
                      return b.status == BookingStatus.cancelled;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(RaftarSpacing.xxl),
                      children: [
                        const SizedBox(height: 60),
                        Icon(
                          _selectedFilter == 'ACTIVE'
                              ? Icons.local_shipping_outlined
                              : Icons.receipt_long_outlined,
                          size: 64,
                          color: RaftarColors.textTertiary,
                        ),
                        const SizedBox(height: RaftarSpacing.lg),
                        Center(
                          child: Text(
                            _selectedFilter == 'ACTIVE'
                                ? 'No active trips in progress'
                                : _selectedFilter == 'COMPLETED'
                                    ? 'No completed trips yet'
                                    : 'No trips match this filter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: RaftarColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(height: RaftarSpacing.xs),
                        Center(
                          child: Text(
                            _selectedFilter == 'ACTIVE'
                                ? 'Need to move goods? Book a delivery now.'
                                : 'Your trip history will appear here.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: RaftarColors.textSecondary,
                            ),
                          ),
                        ),
                        if (_selectedFilter == 'ACTIVE' || allBookings.isEmpty) ...[
                          const SizedBox(height: RaftarSpacing.xl),
                          Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_road_rounded),
                              label: const Text('Book a Delivery'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RaftarColors.primary,
                                foregroundColor: RaftarColors.navy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  context.push(Routes.bookingAddress),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      RaftarSpacing.lg,
                      RaftarSpacing.lg,
                      RaftarSpacing.lg,
                      RaftarSpacing.huge,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: RaftarSpacing.md),
                    itemBuilder: (context, index) =>
                        _BookingCard(booking: filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.countBadgeColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? countBadgeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? RaftarColors.navy : RaftarColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? RaftarColors.navy : RaftarColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : RaftarColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  static const _statusText = {
    BookingStatus.draft: 'Draft',
    BookingStatus.searching: 'Finding driver',
    BookingStatus.driverAssigned: 'Driver assigned',
    BookingStatus.arrivingPickup: 'Driver Arriving',
    BookingStatus.inTransit: 'In Transit',
    BookingStatus.completed: 'Completed',
    BookingStatus.cancelled: 'Cancelled',
  };

  bool get _isActive =>
      booking.status == BookingStatus.searching ||
      booking.status == BookingStatus.driverAssigned ||
      booking.status == BookingStatus.arrivingPickup ||
      booking.status == BookingStatus.inTransit ||
      booking.status == BookingStatus.draft;

  RaftarStatus get _badgeStatus => switch (booking.status) {
    BookingStatus.completed => RaftarStatus.success,
    BookingStatus.cancelled => RaftarStatus.error,
    BookingStatus.inTransit => RaftarStatus.warning,
    _ => RaftarStatus.info,
  };

  @override
  Widget build(BuildContext context) {
    final shortId = booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaftarRadii.xl),
        side: BorderSide(
          color: _isActive
              ? RaftarColors.primary.withValues(alpha: 0.6)
              : RaftarColors.border,
          width: _isActive ? 1.5 : 1.0,
        ),
      ),
      color: RaftarColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(RaftarRadii.xl),
        onTap: () => context.push('${Routes.tripTracking}?id=${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Vehicle Icon + Title + Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? RaftarColors.primary.withValues(alpha: 0.12)
                          : RaftarColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: _isActive ? RaftarColors.primary : RaftarColors.navy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: RaftarSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.vehicleType.label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'ID: #$shortId',
                          style: const TextStyle(
                            fontSize: 11,
                            color: RaftarColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RaftarBadge(
                    label: _statusText[booking.status] ?? 'Booking',
                    status: _badgeStatus,
                  ),
                ],
              ),
              const SizedBox(height: RaftarSpacing.md),
              const Divider(height: 1, color: RaftarColors.border),
              const SizedBox(height: RaftarSpacing.md),

              // Route: Pickup & Drop Points
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.circle, color: Colors.blue, size: 10),
                      Container(
                        width: 1.5,
                        height: 28,
                        color: Colors.grey.shade300,
                      ),
                      const Icon(Icons.location_on, color: Colors.red, size: 14),
                    ],
                  ),
                  const SizedBox(width: RaftarSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.pickup.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RaftarColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          booking.pickup.formattedAddress,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RaftarColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          booking.drop.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: RaftarColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          booking.drop.formattedAddress,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RaftarColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RaftarSpacing.md),
              const Divider(height: 1, color: RaftarColors.border),
              const SizedBox(height: RaftarSpacing.sm),

              // Footer: Fare & Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Fare',
                        style: TextStyle(
                          fontSize: 10,
                          color: RaftarColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${booking.fare.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: RaftarColors.navy,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.support_agent_rounded, size: 20, color: RaftarColors.primary),
                        tooltip: 'Chat with Support for this booking',
                        onPressed: () => context.push(
                          '${Routes.supportChat}?bookingId=${booking.id}',
                        ),
                      ),
                      if (_isActive)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.radar_rounded, size: 16),
                          label: const Text(
                            'Track Live',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RaftarColors.primary,
                            foregroundColor: RaftarColors.navy,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => context.push(
                            '${Routes.tripTracking}?id=${booking.id}',
                          ),
                        )
                      else
                        TextButton.icon(
                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                          label: const Text(
                            'Summary',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => context.push(
                            '${Routes.tripTracking}?id=${booking.id}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
