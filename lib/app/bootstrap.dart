import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage/storage.dart';

/// Initialises platform services, then runs [app] inside a configured
/// [ProviderScope]. This is the composition root: the one place the mock API is
/// seeded and storage is opened. Swapping to a real backend means changing the
/// `apiClientProvider` override here — nothing else.
Future<void> bootstrapAndRun(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.development();
  final storage = await StorageService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        // By NOT overriding apiClientProvider here, it falls back to the real
        // DioApiClient defined in packages/core/lib/src/di/providers.dart!
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: app,
    ),
  );
}
