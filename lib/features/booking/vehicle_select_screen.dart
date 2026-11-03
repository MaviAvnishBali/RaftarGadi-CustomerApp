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


/// A priced option for one dynamic vehicle type loaded from PostgreSQL with live availability.
typedef VehicleQuote = ({
  DynamicVehicleType vehicle,
  FareEstimate fare,
  AvailableVehicleType? availability,
});

/// Resolves an appropriate icon for any dynamic vehicle name.
IconData getVehicleIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('bike') || lower.contains('2-wheeler') || lower.contains('scooter')) {
    return Icons.two_wheeler_rounded;
  }
  if (lower.contains('auto') || lower.contains('3-wheeler') || lower.contains('rickshaw')) {
    return Icons.electric_rickshaw_rounded;
  }
  if (lower.contains('tata ace') || lower.contains('chota') || lower.contains('mini')) {
    return Icons.local_shipping_rounded;
  }
  if (lower.contains('bolero') || lower.contains('pickup')) {
    return Icons.airport_shuttle_rounded;
  }
  if (lower.contains('407') || lower.contains('truck') || lower.contains('heavy')) {
    return Icons.fire_truck_rounded;
  }
  return Icons.local_shipping_rounded;
}

/// Computes the route once, queries progressive Redis geofence (10km -> 15km -> 25km)
/// near the pickup location, then calculates a fare quote per vehicle type in parallel.
final vehicleQuotesProvider = FutureProvider.autoDispose<List<VehicleQuote>>((
  ref,
) async {
  final draft = ref.watch(bookingDraftControllerProvider);
  final pickupLoc = draft.pickup!.location;
  final route = await ref
      .read(routeServiceProvider)
      .route(
        from: pickupLoc,
        to: draft.drop!.location,
      );
  final vehicleRepo = ref.read(vehicleRepositoryProvider);
  final bookingRepo = ref.read(bookingRepositoryProvider);

  // 1. Fetch available vehicles nearby based on pickup location using Redis geofence
  final nearbyResult = await vehicleRepo.getAvailableVehiclesNearby(
    latitude: pickupLoc.latitude,
    longitude: pickupLoc.longitude,
  );
  final nearbyData = nearbyResult.fold((_) => null, (res) => res);
  final availabilityMap = <String, AvailableVehicleType>{};
  if (nearbyData != null) {
    for (final vt in nearbyData.vehicleTypes) {
      availabilityMap[vt.id] = vt;
    }
  }

  // 2. Dynamically fetch all active vehicle types from PostgreSQL database
  final typesResult = await vehicleRepo.getActiveVehicleTypes();
  final vehicleTypes = typesResult.fold(
    (failure) => throw failure,
    (types) => types,
  );

  final quotes = await Future.wait(
    vehicleTypes.map((vehicle) async {
      final result = await bookingRepo.estimateFare(
        vehicleTypeId: vehicle.id,
        vehicleTypeName: vehicle.name,
        vehicleType: vehicle.legacyType,
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMinutes,
      );
      final fare = result.fold((failure) => throw failure, (fare) => fare);
      final availability = availabilityMap[vehicle.id];
      return (vehicle: vehicle, fare: fare, availability: availability);
    }),
  );

  // Sort available vehicles first, then by nearest distance
  quotes.sort((a, b) {
    final aAvail = a.availability?.isAvailable ?? false;
    final bAvail = b.availability?.isAvailable ?? false;
    if (aAvail && !bAvail) return -1;
    if (!aAvail && bAvail) return 1;
    final aDist = a.availability?.nearestDistanceKm ?? 999;
    final bDist = b.availability?.nearestDistanceKm ?? 999;
    return aDist.compareTo(bDist);
  });

  return quotes;
});

/// Booking step 2: pick a vehicle from the computed dynamic quotes.
class VehicleSelectScreen extends ConsumerWidget {
  const VehicleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingDraftControllerProvider);
    final selectedId = draft.selectedVehicle?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a vehicle')),
      body: AsyncValueView<List<VehicleQuote>>(
        value: ref.watch(vehicleQuotesProvider),
        loadingMessage: 'Scanning geofence (10–25 km) & calculating fares…',
        onRetry: () => ref.invalidate(vehicleQuotesProvider),
        data: (quotes) => Column(
          children: [
            // Progressive geofence search banner
            Container(
              margin: const EdgeInsets.fromLTRB(RaftarSpacing.lg, RaftarSpacing.md, RaftarSpacing.lg, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: RaftarColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(RaftarRadii.md),
                border: Border.all(color: RaftarColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radar_rounded, size: 20, color: RaftarColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup: ${draft.pickup?.title ?? 'Pickup Location'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: RaftarColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Geofence Search: 10 km → 25 km → 50 km',
                          style: TextStyle(
                            fontSize: 11,
                            color: RaftarColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(RaftarSpacing.lg),
                itemCount: quotes.length,
                separatorBuilder: (_, _) => const SizedBox(height: RaftarSpacing.md),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  final isSelected = quote.vehicle.id == selectedId ||
                      (selectedId == null && quote.vehicle.legacyType == draft.vehicleType);
                  return _VehicleTile(
                    quote: quote,
                    icon: getVehicleIcon(quote.vehicle.name),
                    isSelected: isSelected,
                    onTap: () => ref
                        .read(bookingDraftControllerProvider.notifier)
                        .chooseVehicle(quote.vehicle, quote.fare),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RaftarSpacing.lg),
          child: RaftarButton(
            label: 'Review booking',
            onPressed: (draft.selectedVehicle == null && draft.vehicleType == null)
                ? null
                : () => context.push(Routes.bookingReview),
          ),
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
        horizontal: RaftarSpacing.md,
        vertical: RaftarSpacing.xs,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? RaftarColors.primary.withValues(alpha: 0.12) : RaftarColors.surfaceMuted,
          borderRadius: BorderRadius.circular(RaftarRadii.md),
        ),
        child: Icon(icon, color: RaftarColors.primary, size: 28),
      ),
      title: Text(
        quote.vehicle.name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: RaftarColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Max ${quote.vehicle.maxWeightKg.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: RaftarColors.primary,
                  ),
                ),
              ),
              if (quote.vehicle.dimensions != null && quote.vehicle.dimensions!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '◱ ${quote.vehicle.dimensions!}',
                    style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          // Live Redis Geofenced Availability (10km -> 15km -> 25km)
          if (quote.availability != null && quote.availability!.isAvailable) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade300, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 7),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${quote.availability!.availableCount} nearby • ~${quote.availability!.estimatedEtaMinutes ?? 4} min',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: RaftarColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '≤ ${quote.availability!.matchedRadiusKm} km',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: RaftarColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 7),
                      SizedBox(width: 4),
                      Text(
                        'No drivers within 50 km',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: RaftarColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${quote.fare.total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RaftarColors.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (quote.fare.surgeMultiplier > 1.0)
            Text(
              '⚡ ${quote.fare.surgeMultiplier}x surge',
              style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
