import 'package:core/core.dart';
import 'package:customer_app/features/tracking/trip_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repositories/repositories.dart';

class _FakeBookingRepo implements BookingRepository {
  _FakeBookingRepo({required this.status});
  final String status;

  @override
  Future<Result<Map<String, dynamic>>> getBookingTracking(String bookingId) async {
    return success({
      'bookingId': bookingId,
      'bookingNumber': 'BK-TEST99',
      'status': status,
      'pickup': {
        'address': '221B Baker Street, Delhi',
        'lat': 28.6139,
        'lng': 77.2090,
      },
      'drop': {
        'address': 'Connaught Place, Delhi',
        'lat': 28.6315,
        'lng': 77.2167,
      },
      'packageType': 'Commercial Goods',
      'packageWeightKg': 150,
      'estimatedFare': 250,
      'finalFare': 250,
      'driver': {
        'id': 'driver-1',
        'name': 'Ramesh Kumar',
        'phone': '+91 98765 43210',
        'vehicle': {
          'registrationNumber': 'DL1AB1234',
          'model': 'Tata Ace',
          'type': 'Mini Truck',
        },
      },
      'liveLocation': {
        'latitude': 28.6200,
        'longitude': 28.2120,
      },
    });
  }

  @override
  Future<Result<Map<String, dynamic>?>> getBookingRating(String bookingId) async {
    return success(null);
  }

  @override
  Future<Result<void>> rateBooking({
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    return success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocketService extends Fake implements SocketService {
  @override
  bool get isConnected => true;

  @override
  void connect({String? token}) {}

  @override
  void joinBooking(String bookingId) {}

  @override
  void leaveBooking(String bookingId) {}

  @override
  Stream<Map<String, dynamic>> watchDriverLocation([String? bookingId]) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> watchBookingStatus([String? bookingId]) => const Stream.empty();

  @override
  void dispose() {}
}

void main() {
  testWidgets('Completed ride NEVER renders FlutterMap and displays Delivery Summary', (tester) async {
    final fakeRepo = _FakeBookingRepo(status: 'TRIP_COMPLETED');
    final fakeSocket = _FakeSocketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          socketServiceProvider.overrideWithValue(fakeSocket),
        ],
        child: const MaterialApp(
          home: TripTrackingScreen(bookingId: 'test-completed-booking'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Strict Map Suppression Check: FlutterMap MUST NOT BE RENDERED
    expect(find.byType(FlutterMap), findsNothing);

    // 2. Completed Delivery Summary MUST BE RENDERED
    expect(find.text('Delivered Successfully! 🎉'), findsOneWidget);
    expect(find.text('Payment Receipt'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('Book Another Delivery'), findsOneWidget);
    expect(find.text('Rate your delivery experience'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Active in-transit ride renders live interactive FlutterMap', (tester) async {
    final fakeRepo = _FakeBookingRepo(status: 'TRIP_STARTED');
    final fakeSocket = _FakeSocketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          socketServiceProvider.overrideWithValue(fakeSocket),
        ],
        child: const MaterialApp(
          home: TripTrackingScreen(bookingId: 'test-active-booking'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Active trip MUST render FlutterMap
    expect(find.byType(FlutterMap), findsOneWidget);

    // Must NOT show completed hero banner
    expect(find.text('Delivered Successfully! 🎉'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
