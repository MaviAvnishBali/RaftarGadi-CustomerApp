import 'dart:async';

import 'package:customer_app/app/router/routes.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:customer_app/session/session_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';

/// Provider to fetch active vehicle types directly from PostgreSQL database.
final dynamicVehicleTypesProvider = FutureProvider<List<DynamicVehicleType>>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  final result = await repo.getActiveVehicleTypes();
  return result.fold((err) => <DynamicVehicleType>[], (types) => types);
});

/// Provider for available vehicles in customer's area using Redis progressive geofencing (10km -> 15km -> 25km).
final availableVehiclesNearbyProvider = FutureProvider.autoDispose<AvailableVehiclesResult>((ref) async {
  final repo = ref.read(vehicleRepositoryProvider);
  double lat = 28.6315;
  double lng = 77.2167;

  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
      lat = pos.latitude;
      lng = pos.longitude;
    }
  } catch (_) {
    // Graceful fallback to default coordinates
  }

  final result = await repo.getAvailableVehiclesNearby(latitude: lat, longitude: lng);
  return result.fold(
    (err) => AvailableVehiclesResult(
      searchLat: lat,
      searchLng: lng,
      searchRadiusKm: 50,
      totalAvailableDrivers: 0,
      vehicleTypes: [],
      nearbyVehicles: [],
    ),
    (data) => data,
  );
});

/// The customer home tab. Dynamically renders real vehicle types from DB.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedVehicleId;
  Timer? _fleetRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh fleet availability every 8 seconds while on home screen
    _fleetRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        ref.invalidate(availableVehiclesNearbyProvider);
      }
    });
  }

  @override
  void dispose() {
    _fleetRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionControllerProvider).user;
    final firstName = user?.fullName.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: RaftarColors.surfaceMuted,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: RaftarColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $firstName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              'Where are we moving today?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RaftarColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dynamicVehicleTypesProvider);
          ref.invalidate(availableVehiclesNearbyProvider);
          await ref.read(availableVehiclesNearbyProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(RaftarSpacing.lg),
        children: [
          // Modern Pickup & Drop search card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              side: const BorderSide(color: RaftarColors.border),
            ),
            color: RaftarColors.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(RaftarRadii.xl),
              onTap: () => context.push(Routes.bookingAddress),
              child: Padding(
                padding: const EdgeInsets.all(RaftarSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: RaftarColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: RaftarColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: RaftarSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter pickup & drop',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Doorstep pickup & on-time delivery',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: RaftarColors.textSecondary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: RaftarColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: RaftarColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: RaftarSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Available in your area',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final availAsync = ref.watch(availableVehiclesNearbyProvider);
                  return availAsync.when(
                    data: (res) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: res.totalAvailableDrivers > 0
                            ? Colors.green.shade50
                            : RaftarColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: res.totalAvailableDrivers > 0
                              ? Colors.green.shade300
                              : RaftarColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 13,
                            color: res.totalAvailableDrivers > 0
                                ? Colors.green.shade700
                                : RaftarColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            res.totalAvailableDrivers > 0
                                ? '${res.totalAvailableDrivers} nearby (≤ ${res.searchRadiusKm} km)'
                                : 'Radius: 10–50 km',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: res.totalAvailableDrivers > 0
                                  ? Colors.green.shade800
                                  : RaftarColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const Text('Scanning fleet…', style: TextStyle(fontSize: 11, color: RaftarColors.textSecondary)),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: RaftarSpacing.md),
          // Dynamic Vertical List of Vehicles from Database with live Redis availability
          Consumer(
            builder: (context, ref, _) {
              final vAsync = ref.watch(dynamicVehicleTypesProvider);
              final availAsync = ref.watch(availableVehiclesNearbyProvider);
              final availMap = <String, AvailableVehicleType>{};
              availAsync.whenData((res) {
                for (final vt in res.vehicleTypes) {
                  availMap[vt.id] = vt;
                }
              });

              return vAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(RaftarSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(RaftarSpacing.md),
                    child: Text('Unable to load vehicle types: $err'),
                  ),
                ),
                data: (types) {
                  if (types.isEmpty) {
                    return const Center(child: Text('No active vehicles available'));
                  }
                  final currentSelected = _selectedVehicleId ?? types.first.id;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: types.length,
                    separatorBuilder: (_, _) => const SizedBox(height: RaftarSpacing.md),
                    itemBuilder: (context, index) {
                      final vehicle = types[index];
                      return _ModernVehicleTile(
                        vehicle: vehicle,
                        availability: availMap[vehicle.id],
                        isSelected: currentSelected == vehicle.id,
                        onTap: () => setState(() => _selectedVehicleId = vehicle.id),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: RaftarSpacing.xl),
          RaftarButton(
            label: 'Book now',
            icon: Icons.local_shipping_rounded,
            onPressed: () {
              final types = ref.read(dynamicVehicleTypesProvider).value;
              if (types != null && types.isNotEmpty) {
                final currentSelected = _selectedVehicleId ?? types.first.id;
                final vehicle = types.firstWhere((v) => v.id == currentSelected, orElse: () => types.first);
                final base = _getVehicleBaseFare(vehicle);
                ref.read(bookingDraftControllerProvider.notifier).chooseVehicle(
                  vehicle,
                  FareEstimate(
                    baseFare: base,
                    distanceFare: 0,
                    timeFare: 0,
                    distanceKm: 0,
                    durationMinutes: 0,
                  ),
                );
              }
              context.push(Routes.bookingAddress);
            },
          ),
          const SizedBox(height: RaftarSpacing.xxl),
        ],
      ),
    ),
  );
}
}

double _getVehicleBaseFare(DynamicVehicleType v) {
  if (v.maxWeightKg <= 30) return 25;
  if (v.maxWeightKg <= 500) return 40;
  if (v.maxWeightKg <= 1000) return 160;
  if (v.maxWeightKg <= 1500) return 250;
  return 500;
}

IconData _resolveVehicleIcon(String name) {
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

class _ModernVehicleTile extends StatelessWidget {
  const _ModernVehicleTile({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
    this.availability,
  });

  final DynamicVehicleType vehicle;
  final bool isSelected;
  final VoidCallback onTap;
  final AvailableVehicleType? availability;

  @override
  Widget build(BuildContext context) {
    final baseFare = _getVehicleBaseFare(vehicle);
    final icon = _resolveVehicleIcon(vehicle.name);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RaftarRadii.lg),
        side: BorderSide(
          color: isSelected ? RaftarColors.primary : RaftarColors.border,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      color: isSelected
          ? RaftarColors.primary.withValues(alpha: 0.05)
          : RaftarColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vehicle Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? RaftarColors.primary.withValues(alpha: 0.12)
                      : RaftarColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? RaftarColors.primary : RaftarColors.navy,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Name, Capacity, Dimensions and Live Availability Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? RaftarColors.primary.withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Up to ${vehicle.maxWeightKg.toStringAsFixed(0)} kg',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? RaftarColors.primary
                                  : RaftarColors.textSecondary,
                            ),
                          ),
                        ),
                        if (vehicle.dimensions != null && vehicle.dimensions!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '◱ ${vehicle.dimensions!}',
                              style: const TextStyle(fontSize: 11, color: RaftarColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Live Redis Geofenced Availability (10km -> 15km -> 25km)
                    if (availability != null && availability!.isAvailable) ...[
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
                                    '${availability!.availableCount} nearby • ~${availability!.estimatedEtaMinutes ?? 4} min',
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
                              '≤ ${availability!.matchedRadiusKm} km',
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
              ),
              const SizedBox(width: 10),
              // Price & Radio Indicator
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'from ₹${baseFare.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: RaftarColors.primary,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? RaftarColors.primary : RaftarColors.border,
                    size: 20,
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
