import 'package:core/core.dart';
import 'package:customer_app/features/booking/booking_draft_controller.dart';
import 'package:customer_app/features/booking/vehicle_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repositories/repositories.dart';
import 'package:shared_models/shared_models.dart';

class _FakeVehicleRepo implements VehicleRepository {
  @override
  Future<Result<List<DynamicVehicleType>>> getActiveVehicleTypes() async {
    return success([
      const DynamicVehicleType(
        id: 'vt-bike',
        name: '2-Wheeler (Bike / Scooter)',
        description: 'Parcels up to 20 kg',
        maxWeightKg: 20,
        dimensions: 'Delivery Bag',
        isActive: true,
      ),
      const DynamicVehicleType(
        id: 'vt-ace',
        name: 'Tata Ace (Chota Hathi)',
        description: 'Up to 850 kg',
        maxWeightKg: 850,
        dimensions: '7ft x 5ft x 5ft',
        isActive: true,
      ),
      const DynamicVehicleType(
        id: 'vt-truck',
        name: 'Tata 407 (14ft)',
        description: 'Up to 2500 kg',
        maxWeightKg: 2500,
        dimensions: '14ft x 6ft x 6ft',
        isActive: true,
      ),
    ]);
  }

  @override
  Future<Result<AvailableVehiclesResult>> getAvailableVehiclesNearby({
    required double latitude,
    required double longitude,
  }) async {
    return success(
      AvailableVehiclesResult(
        searchLat: latitude,
        searchLng: longitude,
        searchRadiusKm: 10,
        totalAvailableDrivers: 3,
        vehicleTypes: [
          const AvailableVehicleType(
            id: 'vt-bike',
            name: '2-Wheeler (Bike / Scooter)',
            maxWeightKg: 20,
            isAvailable: true,
            availableCount: 2,
            nearestDistanceKm: 0.8,
            estimatedEtaMinutes: 4,
            matchedRadiusKm: 10,
          ),
          const AvailableVehicleType(
            id: 'vt-ace',
            name: 'Tata Ace (Chota Hathi)',
            maxWeightKg: 850,
            isAvailable: true,
            availableCount: 1,
            nearestDistanceKm: 12.5,
            estimatedEtaMinutes: 14,
            matchedRadiusKm: 15,
          ),
          const AvailableVehicleType(
            id: 'vt-truck',
            name: 'Tata 407 (14ft)',
            maxWeightKg: 2500,
            isAvailable: false,
            availableCount: 0,
            nearestDistanceKm: null,
            estimatedEtaMinutes: null,
            matchedRadiusKm: null,
          ),
        ],
        nearbyVehicles: [
          const NearbyVehicleMarker(
            driverId: 'd-1',
            vehicleId: 'v-1',
            vehicleTypeId: 'vt-bike',
            vehicleTypeName: '2-Wheeler',
            latitude: 28.632,
            longitude: 77.217,
            heading: 45,
            distanceKm: 0.8,
            radiusBucketKm: 10,
          ),
        ],
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBookingRepo implements BookingRepository {
  @override
  Future<Result<FareEstimate>> estimateFare({
    VehicleType? vehicleType,
    String? vehicleTypeId,
    String? vehicleTypeName,
    required double distanceKm,
    required int durationMinutes,
  }) async {
    return success(
      const FareEstimate(
        baseFare: 50,
        distanceFare: 30,
        timeFare: 10,
        distanceKm: 5.0,
        durationMinutes: 15,
        surgeMultiplier: 1.0,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRouteService implements RouteService {
  @override
  Future<RouteInfo> route({required GeoPoint from, required GeoPoint to}) async {
    return const RouteInfo(
      distanceKm: 5.0,
      durationMinutes: 15,
      polyline: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('VehicleSelectScreen shows progressive geofenced available vehicles (10km -> 15km -> 25km)', (tester) async {
    final container = ProviderContainer(
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(_FakeVehicleRepo()),
        bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
        routeServiceProvider.overrideWithValue(_FakeRouteService()),
      ],
    );

    // Seed draft with pickup and drop addresses
    container.read(bookingDraftControllerProvider.notifier).setPickup(
      const Address(
        id: 'p-1',
        label: AddressLabel.other,
        title: 'Connaught Place',
        formattedAddress: 'Connaught Place, New Delhi',
        location: GeoPoint(latitude: 28.6315, longitude: 77.2167),
      ),
    );
    container.read(bookingDraftControllerProvider.notifier).setDrop(
      const Address(
        id: 'd-1',
        label: AddressLabel.other,
        title: 'Karol Bagh',
        formattedAddress: 'Karol Bagh, New Delhi',
        location: GeoPoint(latitude: 28.6515, longitude: 77.1906),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VehicleSelectScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Geofence banner check
    expect(find.text('Geofence Search: 10 km → 15 km → 25 km'), findsOneWidget);
    expect(find.text('Pickup: Connaught Place'), findsOneWidget);

    // 2. 10 km match check (2-Wheeler)
    expect(find.text('2-Wheeler (Bike / Scooter)'), findsOneWidget);
    expect(find.text('2 nearby • ~4 min'), findsOneWidget);
    expect(find.text('≤ 10 km'), findsOneWidget);

    // 3. 15 km match check (Tata Ace)
    expect(find.text('Tata Ace (Chota Hathi)'), findsOneWidget);
    expect(find.text('1 nearby • ~14 min'), findsOneWidget);
    expect(find.text('≤ 15 km'), findsOneWidget);

    // 4. Unavailable check (Tata 407)
    expect(find.text('Tata 407 (14ft)'), findsOneWidget);
    expect(find.text('No drivers within 25 km'), findsOneWidget);

    // 5. Tap to select
    await tester.tap(find.text('2-Wheeler (Bike / Scooter)'));
    await tester.pumpAndSettle();

    expect(container.read(bookingDraftControllerProvider).selectedVehicle?.name, '2-Wheeler (Bike / Scooter)');
  });
}
