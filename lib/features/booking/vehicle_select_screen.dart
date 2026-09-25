import 'package:core/core.dart';
import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// A priced option for one vehicle type.
typedef VehicleQuote = ({VehicleType type, FareEstimate fare});

/// Computes the route once, then a fare quote per vehicle type in parallel.
/// Exercises `RouteService` (distance) + `BookingRepository.estimateFare`.
final vehicleQuotesProvider = FutureProvider.autoDispose<List<VehicleQuote>>((
  ref,
) async {
  final draft = ref.watch(bookingDraftControllerProvider);
  final route = await ref
      .read(routeServiceProvider)
      .route(
        from: draft.pickup!.location,
        to: draft.drop!.location,
      );
  final repo = ref.read(bookingRepositoryProvider);

  return Future.wait(
    VehicleType.values.map((type) async {
      final result = await repo.estimateFare(
        vehicleType: type,
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMinutes,
      );
      final fare = result.fold((failure) => throw failure, (fare) => fare);
      return (type: type, fare: fare);
    }),
  );
});

/// Booking step 2: pick a vehicle from the computed quotes.
class VehicleSelectScreen extends ConsumerWidget {
  const VehicleSelectScreen({super.key});

  static const _icons = {
    VehicleType.bike: Icons.two_wheeler_rounded,
    VehicleType.auto: Icons.electric_rickshaw_rounded,
    VehicleType.miniTruck: Icons.local_shipping_rounded,
    VehicleType.truck: Icons.fire_truck_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(bookingDraftControllerProvider).vehicleType;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a vehicle')),
      body: AsyncValueView<List<VehicleQuote>>(
        value: ref.watch(vehicleQuotesProvider),
        loadingMessage: 'Estimating fares…',
        onRetry: () => ref.invalidate(vehicleQuotesProvider),
        data: (quotes) => ListView.separated(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          itemCount: quotes.length,
          separatorBuilder: (_, _) => const SizedBox(height: RaftarSpacing.md),
          itemBuilder: (context, index) {
            final quote = quotes[index];
            return _VehicleTile(
              quote: quote,
              icon: _icons[quote.type]!,
              isSelected: quote.type == selected,
              onTap: () => ref
                  .read(bookingDraftControllerProvider.notifier)
                  .chooseVehicle(quote.type, quote.fare),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(RaftarSpacing.lg),
        child: RaftarButton(
          label: 'Review booking',
          onPressed: selected == null
              ? null
              : () => context.push(Routes.bookingReview),
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.quote,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final VehicleQuote quote;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: isSelected
          ? RaftarColors.primaryContainer
          : RaftarColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaftarRadii.lg),
        side: BorderSide(
          color: isSelected ? RaftarColors.primary : RaftarColors.border,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RaftarSpacing.lg,
        vertical: RaftarSpacing.xs,
      ),
      leading: Icon(icon, color: RaftarColors.primary, size: 32),
      title: Text(
        quote.type.label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text('Up to ${quote.type.capacityKg} kg'),
      trailing: Text(
        '₹${quote.fare.total.toStringAsFixed(0)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: RaftarColors.primary,
        ),
      ),
    );
  }
}
