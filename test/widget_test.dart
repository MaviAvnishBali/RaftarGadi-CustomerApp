import 'package:core/core.dart';
import 'package:customer_app/app/customer_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_data/mock_data.dart';
import 'package:storage/storage.dart';

/// In-memory [KeyValueStore] so the app boots without Hive/path_provider.
class _InMemoryStore implements KeyValueStore {
  final Map<String, Object?> _data = {};

  @override
  T? read<T>(String key) => _data[key] as T?;
  @override
  Future<void> write<T>(String key, T value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> clear() async => _data.clear();
  @override
  bool containsKey(String key) => _data.containsKey(key);
  @override
  List<String> get keys => _data.keys.toList();
}

const _env = AppEnvironment(
  flavor: AppFlavor.development,
  apiBaseUrl: 'x',
  simulatedLatency: Duration.zero,
);

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final client = FakeApiClient(environment: _env);
  registerMockRoutes(client);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(_env),
        apiClientProvider.overrideWithValue(client),
        cacheStoreProvider.overrideWithValue(_InMemoryStore()),
      ],
      child: const RaftarCustomerApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _signInToHome(WidgetTester tester) async {
  await _pumpApp(tester);
  await tester.enterText(find.byType(TextField), '9812345678');
  await tester.tap(find.text('Continue with OTP'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), kDemoOtp);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('boots to the customer sign-in screen', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Continue with OTP'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('phone -> OTP -> home reaches the tab shell', (tester) async {
    await _signInToHome(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Choose a vehicle'), findsOneWidget);
  });

  testWidgets('a wrong OTP shows the invalid-code error', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextField), '9812345678');
    await tester.tap(find.text('Continue with OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(find.text('Invalid verification code'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('registration leads to OTP verification', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Meera Iyer');
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.enterText(
      find.byType(TextField).at(2),
      'meera@example.com',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your number'), findsOneWidget);
  });

  testWidgets('full booking flow creates a booking', (tester) async {
    await _signInToHome(tester);

    // Start the flow from home.
    await tester.tap(find.text('Book now'));
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);

    // Pick pickup, then drop, via the address subtitles (unique text).
    await tester.tap(find.text('Select pickup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('221B, Koramangala, Bengaluru'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select drop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WeWork, Indiranagar, Bengaluru'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Vehicle selection: pick the first option, then review.
    expect(find.text('Estimating fares…'), findsNothing);
    await tester.tap(find.text('Bike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review booking'));
    await tester.pumpAndSettle();

    // Review -> confirm.
    expect(find.text('Fare breakdown'), findsOneWidget);
    await tester.tap(find.textContaining('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Booking confirmed!'), findsOneWidget);
  });
}
